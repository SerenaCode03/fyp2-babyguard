// services/cry_classifier.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Top-level minimal WAV container for PCM16 mono.
class _WavData {
  final int sampleRate;
  final int channels;
  final int bitsPerSample;
  final Int16List? pcm16;

  _WavData({
    required this.sampleRate,
    required this.channels,
    required this.bitsPerSample,
    required this.pcm16,
  });
}

/// Result of a single-window cry classification.
class CryResult {
  final String label;
  final double confidence; // probability of the predicted label (after softmax)
  final List<double> rawProbs; // per-class probabilities in label order

  const CryResult(this.label, this.confidence, this.rawProbs);
}

/// On-device cry classifier using a two-stage pipeline:
/// 1) pcmtorgb.tflite    : PCM(1s) -> RGB spectrogram (e.g., 224x224x3)
/// 2) resnet18_cry.tflite: RGB spectrogram -> class logits/probabilities
///
/// Expects WAV: 16kHz, mono, 16-bit PCM, ≥ 1 second of audio.
class CryClassifier {
  // Adjust to your asset paths.
  static const String defaultPcm2RgbPath = 'assets/models/pcm_to_rgb224_fp16.tflite';
  static const String defaultCryModelPath = 'assets/models/resnet18_fp16.tflite';

  /// Label order MUST match training order.
  static const List<String> defaultLabels = <String>[
    'Asphyxia',
    'Hungry',
    'Normal',
    'Pain',
  ];

  // Audio assumptions (must match training).
  static const int sampleRate = 16000;
  static const int windowSec = 1;
  static const int numSamples = sampleRate * windowSec;

  /// Silence threshold for RMS (tune on device).
  static const double defaultRmsSilence = 0.010;

  final String pcm2rgbModelPath;
  final String cryModelPath;
  final List<String> labels;
  final double rmsSilence;

  Interpreter? _pcm2rgb;
  Interpreter? _cryNet;

  CryClassifier({
    this.pcm2rgbModelPath = defaultPcm2RgbPath,
    this.cryModelPath = defaultCryModelPath,
    this.labels = defaultLabels,
    this.rmsSilence = defaultRmsSilence,
  });

  bool get isLoaded => _pcm2rgb != null && _cryNet != null;

  Future<List<int>> _assetBytes(String assetPath) async {
    final bd = await rootBundle.load(assetPath);
    return bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes);
  }

  String _md5(List<int> bytes) => md5.convert(bytes).toString();

  Future<void> load() async {
    // 1) Inspect the asset we’re about to load
    final pcmBytes = await _assetBytes(pcm2rgbModelPath);
    debugPrint("[asset] pcm2rgb size=${pcmBytes.length} md5=${_md5(pcmBytes)}");

    final cryBytes = await _assetBytes(cryModelPath);
    debugPrint("[asset] cry size=${cryBytes.length} md5=${_md5(cryBytes)}");

    // 2) Now create the interpreters
    _pcm2rgb ??= await Interpreter.fromAsset(pcm2rgbModelPath);
    _cryNet  ??= await Interpreter.fromAsset(cryModelPath);

    // 3) Log I/O shapes
    final pIn = _pcm2rgb!.getInputTensor(0);
    final pOut = _pcm2rgb!.getOutputTensor(0);
    final cIn = _cryNet!.getInputTensor(0);
    final cOut = _cryNet!.getOutputTensor(0);

    debugPrint("[pcm2rgb] in=${pIn.shape} ${pIn.type} | out=${pOut.shape} ${pOut.type}");
    debugPrint("[cry]     in=${cIn.shape} ${cIn.type} | out=${cOut.shape} ${cOut.type}");
  }

  void dispose() {
    _pcm2rgb?.close();
    _cryNet?.close();
    _pcm2rgb = null;
    _cryNet = null;
  }

  /// Classify a single WAV file (1s window recommended).
  /// Returns:
  /// - CryResult('Silent', 1.0, [0,0,0,0]) if RMS < silence threshold
  /// - CryResult with predicted label and probabilities
  /// - null if the WAV is invalid or models not loaded
  Future<CryResult?> classifyFromWavFile(String wavPath) async {
    if (!isLoaded) await load();

    // 1. Read and Parse WAV
    final bytes = await File(wavPath).readAsBytes();
    if (bytes.length < 44) return null; // Too short

    final wav = _parseWav(bytes);
    if (wav == null || wav.pcm16 == null) {
      debugPrint("Invalid WAV or no PCM data");
      return null;
    }

    // 2. Prepare float array [1, 16000]
    // This gives us the RAW audio (-1.0 to 1.0) at original volume
    Float32List floatPcm = _int16ToFloat32AndFit(wav.pcm16!, numSamples);

    // --- CRITICAL FIX START ---
    
    // 3. Silence Gate (Check RMS on RAW audio)
    // We do this BEFORE normalization so we don't boost background hiss.
    final rms = _computeRms(floatPcm);
    debugPrint("Audio RMS: ${rms.toStringAsFixed(5)} (Threshold: $rmsSilence)");

    if (rms < rmsSilence) {
      debugPrint("Silent detected. Skipping classification.");
      return CryResult('Silent', 1.0, List.filled(labels.length, 0.0));
    }

    // 4. Peak Normalization (ONLY for non-silent audio)
    // Your training script uses: y = y / max(abs(y))
    // We must do this so the cry volume matches the training data.
    debugPrint("Audio is loud enough. Applying Peak Normalization...");
    floatPcm = _peakNormalize(floatPcm);

    // Save Audio Debug (Normalized)
    await saveDebugAudio(floatPcm);

    // 5. Run Frontend: PCM -> RGB
    debugPrint("Running pcm2rgb model...");
    final rgb = _runPcm2Rgb(floatPcm);
    if (rgb == null) return null;

    // --- DEBUG: Save Raw Spectrogram ---
    // This confirms if the first model is working
    await _saveDebugImage(rgb, 224, 224, "1_raw_spectrogram");

    // 6. Fix Output Range (0..255 -> 0..1)
    // If your TFLite model outputs 0-255, we must scale it back to 0-1
    double maxVal = 0.0;
    for (var v in rgb) if (v > maxVal) maxVal = v;
    debugPrint("[CryClassifier]: Max value = $maxVal");
    
    if (maxVal > 1.05) {
      debugPrint("Normalizing RGB (max=$maxVal) -> 0.0 to 1.0");
      for (int i = 0; i < rgb.length; i++) rgb[i] /= 255.0;
    }

    // 7. Convert to Grayscale (3-channel)
    // Matches Python: transforms.Grayscale(num_output_channels=3)
    final gray3 = _rgbToGray3NHWC(rgb, 224, 224);

    // --- DEBUG: Save Classifier Input ---
    // This confirms exactly what the ResNet sees
    await _saveDebugImage(gray3, 224, 224, "2_resnet_input");

    // 8. Run Classifier
    debugPrint("Running classifier...");
    final scores = _runCryClassifier(gray3);
    if (scores == null) return null;

    final probs = _softmax(scores);
    final idx = _argmax(probs);
    
    final result = CryResult(labels[idx], probs[idx], probs);
    debugPrint("Prediction: ${result.label} (${result.confidence})");
    return result;
  }

  // ---------------------------------------------------------------------------
  // Inference steps
  // ---------------------------------------------------------------------------

  /// Run the pcmtorgb model.
  /// Returns a float32 NHWC buffer ready for the cry model (shape must match).
  Float32List? _runPcm2Rgb(Float32List pcm) {
    final interp = _pcm2rgb!;
    final inT = interp.getInputTensor(0);
    final outT = interp.getOutputTensor(0);

    debugPrint("[_runPcm2Rgb] expect in=${inT.shape} ${inT.type} | out=${outT.shape} ${outT.type}");

    // Input must be [1,16000] float32 (per your Colab)
    if (inT.type != TensorType.float32 || inT.shape.length != 2 || inT.shape[0] != 1) {
      debugPrint("[_runPcm2Rgb] ERROR: unexpected input signature ${inT.shape} ${inT.type}");
      return null;
    }

    final int need = inT.shape[1]; // 16000
    final Float32List fitted = _fit1D(pcm, need);
    final List<List<double>> inputObj = [fitted.toList(growable: false)];

    // Prepare nested output container of shape [1,224,224,3]
    final outShape = outT.shape; // [1,224,224,3]
    if (outT.type != TensorType.float32 || outShape.length != 4) {
      debugPrint("[_runPcm2Rgb] ERROR: unsupported output signature ${outShape} ${outT.type}");
      return null;
    }
    final int H = outShape[1], W = outShape[2], C = outShape[3];
    final List<List<List<List<double>>>> outNested =
        List.generate(1, (_) =>
          List.generate(H, (_) =>
            List.generate(W, (_) =>
              List<double>.filled(C, 0.0, growable: false),
            growable: false),
          growable: false),
        growable: false);

    try {
      debugPrint("[_runPcm2Rgb] feeding $need samples");
      interp.run(inputObj, outNested); // outNested filled by TFLite

      // Flatten NHWC to a single Float32List (length = 1*H*W*C)
      final Float32List flat = Float32List(H * W * C);
      int k = 0;
      for (int h = 0; h < H; h++) {
        final row = outNested[0][h];
        for (int w = 0; w < W; w++) {
          final pix = row[w];
          for (int c = 0; c < C; c++) {
            flat[k++] = pix[c];
          }
        }
      }
      return flat;
    } catch (e, st) {
      debugPrint("[_runPcm2Rgb] RUN ERROR: $e");
      debugPrint(st.toString());
      return null;
    }
  }

  /// Converts RGB [0.0, 1.0] to Grayscale stacked 3 times [0.0, 1.0]
  /// Matches PyTorch: transforms.Grayscale(num_output_channels=3)
  Float32List _rgbToGray3NHWC(Float32List rgb, int H, int W) {
    const rW = 0.2989;
    const gW = 0.5870;
    const bW = 0.1140;
    
    final int plane = H * W;
    final out = Float32List(plane * 3);

    for (int i = 0; i < plane; i++) {
      final int base = i * 3;
      
      // Calculate luminance
      double g = rW * rgb[base] + gW * rgb[base + 1] + bW * rgb[base + 2];
      
      // Clamp strictly to [0.0, 1.0] just in case of float precision drift
      if (g < 0.0) g = 0.0;
      if (g > 1.0) g = 1.0; 

      // Replicate across 3 channels (R=G, G=G, B=G)
      final int o = i * 3;
      out[o] = g;
      out[o + 1] = g;
      out[o + 2] = g;
    }
    return out;
  }

  Future<void> _saveDebugImage(Float32List flatRgb, int height, int width, String stepName) async {
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) return;
      
      final folder = Directory('${dir.path}/cry_debug_images');
      if (!await folder.exists()) await folder.create(recursive: true);

      // Create an image buffer
      final image = img.Image(width: width, height: height);

      // Find min/max for visualization normalization (so we can see it even if values are low)
      double minV = double.infinity;
      double maxV = -double.infinity;
      for (var v in flatRgb) {
        if (v < minV) minV = v;
        if (v > maxV) maxV = v;
      }
      debugPrint("[$stepName] Stats: Min=$minV Max=$maxV");

      // Loop through pixels (Assuming NHWC layout: Pixel 1 [R,G,B], Pixel 2 [R,G,B]...)
      int ptr = 0;
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          if (ptr + 2 >= flatRgb.length) break;

          double r = flatRgb[ptr++];
          double g = flatRgb[ptr++];
          double b = flatRgb[ptr++];

          // Normalize to 0-255 for PNG
          // If the model output is 0.0-1.0, we multiply by 255.
          // If it's already 0-255, we leave it.
          // If it's messy, we use min-max scaling to force it to be visible.
          
          int rI, gI, bI;
          
          if (maxV <= 1.0) {
            // Assume 0.0-1.0 range
            rI = (r * 255).toInt();
            gI = (g * 255).toInt();
            bI = (b * 255).toInt();
          } else {
             // Assume 0-255 range (or higher)
             rI = r.toInt();
             gI = g.toInt();
             bI = b.toInt();
          }

          // Clamp to valid byte range
          rI = rI.clamp(0, 255);
          gI = gI.clamp(0, 255);
          bI = bI.clamp(0, 255);

          // Set pixel (img package uses order: r, g, b)
          image.setPixelRgb(x, y, rI, gI, bI);
        }
      }

      final pngBytes = img.encodePng(image);
      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File('${folder.path}/${stepName}_$ts.png');
      await file.writeAsBytes(pngBytes);
      debugPrint("[$stepName] Saved debug image to: ${file.path}");
      
    } catch (e) {
      debugPrint("Error saving debug image: $e");
    }
  }
  /// Run the cry classifier (ResNet-18).
  /// Accepts an NHWC float32 buffer and returns raw scores (logits/probs).
  List<double>? _runCryClassifier(Float32List nhwcFlat) {
    final cls = _cryNet!;
    final inT = cls.getInputTensor(0);
    final outT = cls.getOutputTensor(0);

    final inShape = inT.shape;   // [1,224,224,3]
    final outShape = outT.shape; // e.g. [1,4]

    if (inT.type != TensorType.float32 || inShape.length != 4) {
      debugPrint("[runCry] ERROR: unexpected in signature ${inShape} ${inT.type}");
      return null;
    }
    final int H = inShape[1], W = inShape[2], C = inShape[3];
    if (nhwcFlat.length != H * W * C) {
      debugPrint("[runCry] ERROR: flat length mismatch got=${nhwcFlat.length} expect=${H*W*C}");
      return null;
    }

    // Build nested NHWC input
    final List<List<List<List<double>>>> inNested =
        List.generate(1, (_) =>
          List.generate(H, (h) =>
            List.generate(W, (w) {
              final base = (h * W + w) * C;
              return <double>[
                nhwcFlat[base + 0],
                nhwcFlat[base + 1],
                nhwcFlat[base + 2],
              ];
            }, growable: false),
          growable: false),
        growable: false);

    // Prepare nested output
    if (outT.type != TensorType.float32 || outShape.length != 2 || outShape[0] != 1) {
      debugPrint("[runCry] ERROR: unexpected out signature ${outShape} ${outT.type}");
      return null;
    }
    final int K = outShape[1]; // num classes
    final List<List<double>> outNested =
        List.generate(1, (_) => List<double>.filled(K, 0.0, growable: false),
          growable: false);

    try {
      cls.run(inNested, outNested);
      return outNested[0]; // logits/probs length K
    } catch (e, st) {
      debugPrint("[runCry] RUN ERROR: $e");
      debugPrint(st.toString());
      return null;
    }
  }


  // ---------------------------------------------------------------------------
  // WAV parsing and utilities
  // ---------------------------------------------------------------------------

  _WavData? _parseWav(Uint8List bytes) {
    // Strict RIFF/WAVE PCM parser for 16-bit mono files.
    if (bytes.length < 44) return null;

    final bd = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);

    // RIFF header
    if (String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF') return null;
    if (String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') return null;

    int offset = 12;
    int? audioFormat;
    int? numChannels;
    int? sRate;
    int? bitsPerSample;
    int? dataOffset;
    int? dataSize;

    while (offset + 8 <= bytes.length) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = bd.getUint32(offset + 4, Endian.little);
      final chunkDataStart = offset + 8;

      if (chunkId == 'fmt ') {
        if (chunkSize < 16) return null;
        audioFormat = bd.getUint16(chunkDataStart + 0, Endian.little);
        numChannels = bd.getUint16(chunkDataStart + 2, Endian.little);
        sRate = bd.getUint32(chunkDataStart + 4, Endian.little);
        bitsPerSample = bd.getUint16(chunkDataStart + 14, Endian.little);
      } else if (chunkId == 'data') {
        dataOffset = chunkDataStart;
        dataSize = chunkSize;
      }

      offset = chunkDataStart + chunkSize;
      if (offset >= bytes.length) break;
    }

    if (audioFormat != 1 /* PCM */ ||
        numChannels == null ||
        sRate == null ||
        bitsPerSample == null ||
        dataOffset == null ||
        dataSize == null) {
      return null;
    }

    if (bitsPerSample != 16) return null; // only PCM16 supported

    final int sampleCount = (dataSize ~/ 2);
    if (dataOffset + dataSize > bytes.length) return null;
    final dataView = ByteData.view(bytes.buffer, bytes.offsetInBytes + dataOffset, dataSize);

    final Int16List pcm = Int16List(sampleCount);
    for (int i = 0; i < sampleCount; i++) {
      pcm[i] = dataView.getInt16(i * 2, Endian.little);
    }

    return _WavData(
      sampleRate: sRate,
      channels: numChannels,
      bitsPerSample: bitsPerSample,
      pcm16: pcm,
    );
  }

   Future<void> saveDebugAudio(Float32List pcm) async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) return;
      
      final folder = Directory('${directory.path}/cry_debug');
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }

      // Create a filename with timestamp
      final ts = DateTime.now().millisecondsSinceEpoch;
      // We save as .bin or .pcm because these are raw float values, not a playable WAV yet.
      // You can import this into Audacity as "Raw Data" (32-bit float, 16kHz, mono).
      final filePath = '${folder.path}/debug_normalized_$ts.pcm';
      final file = File(filePath);

      // CONVERSION: Float32List -> Uint8List (Bytes)
      final bytes = pcm.buffer.asUint8List();
      
      await file.writeAsBytes(bytes);
      debugPrint("[CryClassifier] Saved normalized audio: $filePath");
    } catch (e) {
      debugPrint("Error saving debug audio: $e");
    }
  }

  Float32List _int16ToFloat32AndFit(Int16List s, int targetLen) {
    final Float32List f = Float32List(s.length);
    for (int i = 0; i < s.length; i++) {
      f[i] = s[i] / 32768.0;
    }
    return _fit1D(f, targetLen);
  }

  Float32List _peakNormalize(Float32List input) {
    // 1. Find the maximum absolute value in the entire buffer
    double maxAbs = 1e-10; // Start with a tiny epsilon to prevent division by zero
    
    for (int i = 0; i < input.length; i++) {
      final double absVal = input[i].abs();
      if (absVal > maxAbs) {
        maxAbs = absVal;
      }
    }

    // 2. Divide every sample by that maximum value
    // This scales the loudest part of the audio to exactly 1.0 or -1.0
    final Float32List out = Float32List(input.length);
    for (int i = 0; i < input.length; i++) {
      out[i] = input[i] / maxAbs;
    }
    
    return out;
  }

  Float32List _fit1D(Float32List src, int targetLen) {
    if (src.length == targetLen) return src;

    final Float32List out = Float32List(targetLen);
    if (src.length > targetLen) {
      // Center crop
      final int start = ((src.length - targetLen) / 2).floor();
      out.setAll(0, src.sublist(start, start + targetLen));
    } else {
      // Zero-pad at the end
      out.setAll(0, src);
      // trailing values remain zero
    }
    return out;
  }

  double _computeRms(Float32List x) {
    double s = 0;
    for (int i = 0; i < x.length; i++) {
      final v = x[i];
      s += v * v;
    }
    return math.sqrt(s / x.length);
  }

  int _numElements(List<int> shape) {
    int n = 1;
    for (final d in shape) {
      n *= d;
    }
    return n;
  }

  int _argmax(List<double> x) {
    int mi = 0;
    double mv = -double.infinity;
    for (int i = 0; i < x.length; i++) {
      final v = x[i];
      if (v > mv) {
        mv = v;
        mi = i;
      }
    }
    return mi;
  }

  List<double> _softmax(List<double> logits) {
    double maxLogit = -double.infinity;
    for (final v in logits) {
      if (v > maxLogit) maxLogit = v;
    }
    double sum = 0.0;
    final List<double> exps = List<double>.filled(logits.length, 0.0);
    for (int i = 0; i < logits.length; i++) {
      final e = math.exp(logits[i] - maxLogit);
      exps[i] = e;
      sum += e;
    }
    if (sum <= 0) {
      final u = 1.0 / logits.length;
      return List<double>.filled(logits.length, u);
    }
    for (int i = 0; i < exps.length; i++) {
      exps[i] = exps[i] / sum;
    }
    return exps;
  }
}
