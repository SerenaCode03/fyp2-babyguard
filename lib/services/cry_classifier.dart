import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

/// Top-level minimal WAV container
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

class CryResult {
  final String label;
  final double confidence;
  final List<double> rawProbs;

  const CryResult(this.label, this.confidence, this.rawProbs);
}

class CryClassifier {
  static const String defaultPcm2RgbPath = 'assets/models/pcm_to_rgb224_fp16.tflite';
  static const String defaultCryModelPath = 'assets/models/resnet18_fp16.tflite';

  static const List<String> defaultLabels = <String>[
    'Asphyxia',
    'Hungry',
    'Normal',
    'Pain',
  ];

  static const int sampleRate = 16000; // Target rate for Model
  static const int windowSec = 1;
  static const int numSamples = sampleRate * windowSec;
  
  // INCREASED THRESHOLD: Ignore quiet room noise (0.01 is too sensitive)
  static const double defaultRmsSilence = 0.05; 

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

  Future<void> load() async {
    try {
      _pcm2rgb = await Interpreter.fromAsset(pcm2rgbModelPath);
      _cryNet = await Interpreter.fromAsset(cryModelPath);
      debugPrint("[CryClassifier] Models loaded successfully.");
    } catch (e) {
      debugPrint("[CryClassifier] Error loading models: $e");
    }
  }

  void dispose() {
    _pcm2rgb?.close();
    _cryNet?.close();
  }

  // ===========================================================================
  // MAIN PIPELINE
  // ===========================================================================
  
  // Future<CryResult?> classifyFromWavFile(String wavPath) async {
  //   if (!isLoaded) await load();

  //   // 1. Read WAV
  //   final bytes = await File(wavPath).readAsBytes();
  //   if (bytes.length < 44) return null;

  //   final wav = _parseWav(bytes);
  //   if (wav == null || wav.pcm16 == null) {
  //     debugPrint("[CryClassifier] Invalid WAV");
  //     return null;
  //   }

  //   // 2. Convert Int16 -> Float32 (Full Buffer)
  //   // We convert the whole thing first, before cropping
  //   Float32List rawFloat = Float32List(wav.pcm16!.length);
  //   for(int i=0; i<wav.pcm16!.length; i++) {
  //     rawFloat[i] = wav.pcm16![i] / 32768.0;
  //   }

  //   // 3. RESAMPLING (The Fix for "Demon Voice")
  //   // If phone recorded at 44100, we must convert to 16000
  //   Float32List resampledFloat;
  //   if (wav.sampleRate != sampleRate) {
  //     debugPrint("[CryClassifier] ⚠️ Resampling ${wav.sampleRate}Hz -> ${sampleRate}Hz");
  //     resampledFloat = _resample(rawFloat, wav.sampleRate, sampleRate);
  //   } else {
  //     resampledFloat = rawFloat;
  //   }

  //   // 4. Fit to 1 Second (16000 samples)
  //   Float32List floatPcm = _fit1D(resampledFloat, numSamples);

  //   // 5. SILENCE CHECK
  //   final rms = _computeRms(floatPcm);
  //   debugPrint("[CryClassifier] Audio RMS: ${rms.toStringAsFixed(5)}");

  //   if (rms < rmsSilence) {
  //     debugPrint("[CryClassifier] Silence detected. Skipping.");
  //     return CryResult('Silent', 1.0, List.filled(labels.length, 0.0));
  //   }

  //   // 6. PEAK NORMALIZATION
  //   debugPrint("[CryClassifier] Applying Peak Normalization...");
  //   floatPcm = _peakNormalize(floatPcm);
    
  //   // Save Playable WAV for debugging
  //   await saveDebugAudio(floatPcm);

  //   // 7. PCM -> RGB
  //   debugPrint("[CryClassifier] Running pcm2rgb...");
  //   final rgbFlat = _runPcm2RgbSafe(floatPcm); 
  //   if (rgbFlat == null) return null;

  //   // Check Max Value
  //   double maxVal = 0.0;
  //   for (var v in rgbFlat) if (v > maxVal) maxVal = v;
    
  //   // Normalize RGB if needed (0..255 -> 0..1)
  //   if (maxVal > 1.05) {
  //     debugPrint("[CryClassifier] Normalizing RGB...");
  //     for (int i = 0; i < rgbFlat.length; i++) rgbFlat[i] /= 255.0;
  //   }

  //   await _saveDebugImage(rgbFlat, 224, 224, "1_spectrogram_raw");

  //   // 8. RGB -> GRAYSCALE
  //   final gray3Flat = _rgbToGray3NHWC(rgbFlat, 224, 224);

  //   await _saveDebugImage(gray3Flat, 224, 224, "2_resnet_input");

  //   // 9. CLASSIFIER
  //   debugPrint("[CryClassifier] Running classifier...");
  //   final scores = _runCryClassifierSafe(gray3Flat);
  //   if (scores == null) return null;

  //   final probs = _softmax(scores);
  //   final idx = _argmax(probs);
    
  //   debugPrint("[CryClassifier] Prediction: ${labels[idx]} (${probs[idx].toStringAsFixed(2)})");
  //   return CryResult(labels[idx], probs[idx], probs);
  // }

  // ===========================================================================
  // 5-SECOND VOTING PIPELINE
  // ===========================================================================

  Future<CryResult?> classifyLongAudio(String wavPath) async {
    if (!isLoaded) await load();

    // 1. Load & Parse WAV
    final bytes = await File(wavPath).readAsBytes();
    final wav = _parseWav(bytes);
    if (wav == null || wav.pcm16 == null) return null;

    // 2. Convert to Float32 & Resample (Full 5 seconds)
    Float32List fullAudio = _int16ToFloat32(wav.pcm16!);
    if (wav.sampleRate != sampleRate) {
      debugPrint("Resampling full buffer...");
      fullAudio = _resample(fullAudio, wav.sampleRate, sampleRate);
    }

    // 3. Sliding Window Loop
    // We will extract 1-second chunks (16000 samples)
    int step = 16000; 
    int totalSamples = fullAudio.length;
    
    // Accumulators for voting
    Map<String, double> probabilitySum = {};
    for (var label in labels) probabilitySum[label] = 0.0;
    int validWindows = 0;

    debugPrint("--- Starting 5s Analysis (Total samples: $totalSamples) ---");

    // Loop until we run out of full seconds
    for (int i = 0; i <= totalSamples - step; i += step) {
      // Extract 1 second slice
      Float32List window = fullAudio.sublist(i, i + step);
      
      // Classify this specific second
      CryResult? res = await _classifySingleWindow(window, "win_${i ~/ step}");
      
      if (res != null && res.label != 'Silent') {
        validWindows++;
        // Add probabilities to total
        for (int k = 0; k < res.rawProbs.length; k++) {
          probabilitySum[labels[k]] = (probabilitySum[labels[k]] ?? 0) + res.rawProbs[k];
        }
        debugPrint(" Window ${i ~/ step}: ${res.label} (${res.confidence.toStringAsFixed(2)})");
      } else {
        debugPrint(" Window ${i ~/ step}: Silent/Ignored");
      }
    }

    // 4. Final Aggregation
    if (validWindows == 0) {
      return CryResult('Silent', 1.0, List.filled(labels.length, 0.0));
    }

    // Calculate average probabilities
    List<double> avgProbs = List.filled(labels.length, 0.0);
    double maxConf = -1.0;
    int maxIdx = 0;

    for (int k = 0; k < labels.length; k++) {
      String label = labels[k];
      double avg = probabilitySum[label]! / validWindows;
      avgProbs[k] = avg;
      
      if (avg > maxConf) {
        maxConf = avg;
        maxIdx = k;
      }
    }

    debugPrint("--- FINAL VERDICT: ${labels[maxIdx]} (Avg Conf: ${maxConf.toStringAsFixed(2)}) ---");
    return CryResult(labels[maxIdx], maxConf, avgProbs);
  }

  // --- PRIVATE HELPER: Classifies exactly 1 second of float data ---
  Future<CryResult?> _classifySingleWindow(Float32List pcm, String debugTag) async {
    // 1. Silence Check
    double rms = _computeRms(pcm);
    if (rms < rmsSilence) return null; // Too quiet

    // 2. Normalize
    Float32List normalized = _peakNormalize(pcm);
    
    // 3. Inference
    // (Optional: save debug image for this window)
    // await _saveDebugImage(_runPcm2RgbSafe(normalized)!, 224, 224, "debug_$debugTag");
    
    final rgb = _runPcm2RgbSafe(normalized);
    if (rgb == null) return null;
    
    // Normalize RGB 0-255 -> 0-1
    double maxVal = 0.0;
    for (var v in rgb) if (v > maxVal) maxVal = v;
    if (maxVal > 1.05) for (int i = 0; i < rgb.length; i++) rgb[i] /= 255.0;

    final gray = _rgbToGray3NHWC(rgb, 224, 224);
    final scores = _runCryClassifierSafe(gray);
    if (scores == null) return null;

    final probs = _softmax(scores);
    final idx = _argmax(probs);
    return CryResult(labels[idx], probs[idx], probs);
  }
  
  // Helper to convert whole buffer without fitting/cropping yet
  Float32List _int16ToFloat32(Int16List s) {
    final Float32List f = Float32List(s.length);
    for(int i=0; i<s.length; i++) f[i] = s[i] / 32768.0;
    return f;
  }

  // ===========================================================================
  // HELPERS (Resample, Fit, Math)
  // ===========================================================================

  /// Linear Interpolation Resampler (Fixes sample rate mismatch)
  Float32List _resample(Float32List input, int oldRate, int newRate) {
    if (oldRate == newRate) return input;
    final double ratio = oldRate / newRate;
    final int newLength = (input.length / ratio).ceil();
    final Float32List output = Float32List(newLength);

    for (int i = 0; i < newLength; i++) {
      final double position = i * ratio;
      final int index = position.floor();
      final double fraction = position - index;

      if (index >= input.length - 1) {
        output[i] = input[input.length - 1];
      } else {
        final double val0 = input[index];
        final double val1 = input[index + 1];
        output[i] = val0 + (val1 - val0) * fraction;
      }
    }
    return output;
  }

  /// Fit data to exact length (Crop center or Pad)
  Float32List _fit1D(Float32List src, int targetLen) {
    if (src.length == targetLen) return src;
    final out = Float32List(targetLen);
    
    if (src.length > targetLen) {
      // Center crop
      int start = (src.length - targetLen) ~/ 2;
      for(int i=0; i<targetLen; i++) out[i] = src[start + i];
    } else {
      // Pad with zeros (or copy what we have)
      for(int i=0; i<src.length; i++) out[i] = src[i];
    }
    return out;
  }

  Float32List _peakNormalize(Float32List input) {
    double maxAbs = 1e-10;
    for (var v in input) {
      if (v.abs() > maxAbs) maxAbs = v.abs();
    }
    final out = Float32List(input.length);
    for (int i = 0; i < input.length; i++) {
      out[i] = input[i] / maxAbs;
    }
    return out;
  }

  // ===========================================================================
  // TFLITE SAFE METHODS
  // ===========================================================================

  Float32List? _runPcm2RgbSafe(Float32List pcm) {
    if (_pcm2rgb == null) return null;
    final inputObj = [pcm.toList()];
    final outDest = List.generate(1, (_) => 
      List.generate(224, (_) => 
        List.generate(224, (_) => 
          List.filled(3, 0.0), growable: false), growable: false), growable: false);

    try {
      _pcm2rgb!.run(inputObj, outDest);
    } catch (e) {
      debugPrint("[CryClassifier] Error pcm2rgb: $e");
      return null;
    }

    final flat = Float32List(224 * 224 * 3);
    int k = 0;
    for (int h = 0; h < 224; h++) {
      for (int w = 0; w < 224; w++) {
        for (int c = 0; c < 3; c++) {
          flat[k++] = outDest[0][h][w][c];
        }
      }
    }
    return flat;
  }

  List<double>? _runCryClassifierSafe(Float32List flatGray) {
    if (_cryNet == null) return null;
    final inputObj = List.generate(1, (_) => 
      List.generate(224, (h) => 
        List.generate(224, (w) {
          final int idx = (h * 224 + w) * 3;
          return [flatGray[idx], flatGray[idx+1], flatGray[idx+2]];
        }, growable: false), growable: false), growable: false);

    final outDest = List.generate(1, (_) => List.filled(4, 0.0));
    try {
      _cryNet!.run(inputObj, outDest);
    } catch (e) {
      debugPrint("[CryClassifier] Error classifier: $e");
      return null;
    }
    return outDest[0];
  }

  // ===========================================================================
  // IMAGE & AUDIO SAVING (Debug)
  // ===========================================================================

  /// Save processed audio as a PLAYABLE WAV file
  Future<void> saveDebugAudio(Float32List pcm) async {
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) return;
      final folder = Directory('${dir.path}/cry_debug');
      if (!await folder.exists()) await folder.create(recursive: true);

      final ts = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${folder.path}/debug_in_$ts.wav';
      final file = File(filePath);

      // Convert back to Int16
      final int16Data = Int16List(pcm.length);
      for (int i = 0; i < pcm.length; i++) {
        double val = pcm[i];
        if (val < -1.0) val = -1.0;
        if (val > 1.0) val = 1.0;
        int16Data[i] = (val * 32767).toInt();
      }

      // Create WAV Header (44 bytes)
      final int sampleRate = 16000;
      final int channels = 1;
      final int byteRate = sampleRate * channels * 2; 
      final int dataSize = int16Data.length * 2;
      final int totalSize = 36 + dataSize;
      
      final header = Uint8List(44);
      final view = ByteData.view(header.buffer);
      
      view.setUint32(0, 0x52494646, Endian.big); // RIFF
      view.setUint32(4, totalSize, Endian.little);
      view.setUint32(8, 0x57415645, Endian.big); // WAVE
      view.setUint32(12, 0x666D7420, Endian.big); // fmt 
      view.setUint32(16, 16, Endian.little); 
      view.setUint16(20, 1, Endian.little); // PCM
      view.setUint16(22, channels, Endian.little);
      view.setUint32(24, sampleRate, Endian.little);
      view.setUint32(28, byteRate, Endian.little);
      view.setUint16(32, 2, Endian.little); 
      view.setUint16(34, 16, Endian.little); 
      view.setUint32(36, 0x64617461, Endian.big); // data
      view.setUint32(40, dataSize, Endian.little);

      final sink = file.openWrite();
      sink.add(header);
      sink.add(int16Data.buffer.asUint8List());
      await sink.close();
      
      debugPrint("[CryClassifier] Saved WAV: $filePath");
    } catch (_) {}
  }

  Future<void> _saveDebugImage(Float32List flatData, int w, int h, String tag) async {
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) return;
      final folder = Directory('${dir.path}/cry_debug');
      if (!await folder.exists()) await folder.create(recursive: true);

      final image = img.Image(width: w, height: h);
      double maxVal = 0.0;
      for(var v in flatData) if(v > maxVal) maxVal = v;
      bool needsScale = maxVal <= 1.5; 

      int ptr = 0;
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          double r = flatData[ptr++];
          double g = flatData[ptr++];
          double b = flatData[ptr++];
          int ri = needsScale ? (r * 255).toInt() : r.toInt();
          int gi = needsScale ? (g * 255).toInt() : g.toInt();
          int bi = needsScale ? (b * 255).toInt() : b.toInt();
          image.setPixelRgb(x, y, ri.clamp(0, 255), gi.clamp(0, 255), bi.clamp(0, 255));
        }
      }
      final path = '${folder.path}/${tag}_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(path).writeAsBytes(img.encodePng(image));
    } catch (e) { debugPrint("Img save err: $e"); }
  }

  // ===========================================================================
  // MATH & PARSING
  // ===========================================================================

  Float32List _rgbToGray3NHWC(Float32List rgb, int H, int W) {
    const rW = 0.2989;
    const gW = 0.5870;
    const bW = 0.1140;
    final int pixels = H * W;
    final out = Float32List(pixels * 3);
    int ptr = 0;
    for (int i = 0; i < pixels; i++) {
      double r = rgb[ptr++];
      double g = rgb[ptr++];
      double b = rgb[ptr++];
      double lum = (r * rW) + (g * gW) + (b * bW);
      if (lum < 0.0) lum = 0.0;
      if (lum > 1.0) lum = 1.0;
      final int o = i * 3;
      out[o] = lum;
      out[o+1] = lum;
      out[o+2] = lum;
    }
    return out;
  }

  double _computeRms(Float32List x) {
    double s = 0;
    for (var v in x) s += v * v;
    return math.sqrt(s / x.length);
  }

  int _argmax(List<double> x) {
    int mi = 0;
    double mv = -double.infinity;
    for (int i = 0; i < x.length; i++) {
      if (x[i] > mv) { mv = x[i]; mi = i; }
    }
    return mi;
  }

  List<double> _softmax(List<double> logits) {
    double maxLogit = -double.infinity;
    for (final v in logits) if (v > maxLogit) maxLogit = v;
    double sum = 0.0;
    final exps = List<double>.filled(logits.length, 0.0);
    for (int i = 0; i < logits.length; i++) {
      final e = math.exp(logits[i] - maxLogit);
      exps[i] = e;
      sum += e;
    }
    for (int i = 0; i < exps.length; i++) exps[i] /= sum;
    return exps;
  }

  _WavData? _parseWav(Uint8List bytes) {
    if (bytes.length < 44) return null;
    final bd = ByteData.view(bytes.buffer);
    if (String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF') return null;
    final channels = bd.getUint16(22, Endian.little);
    final sRate = bd.getUint32(24, Endian.little);
    final bits = bd.getUint16(34, Endian.little);
    
    int offset = 12;
    int dataSize = 0;
    int dataOffset = 0;
    while (offset < bytes.length - 8) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset+4));
      final size = bd.getUint32(offset+4, Endian.little);
      if (chunkId == 'data') {
        dataOffset = offset + 8;
        dataSize = size;
        break;
      }
      offset += 8 + size;
    }
    if (dataOffset == 0) return null;
    final sampleCount = dataSize ~/ 2;
    final pcm = Int16List(sampleCount);
    final view = ByteData.view(bytes.buffer, bytes.offsetInBytes + dataOffset, dataSize);
    for(int i=0; i<sampleCount; i++) pcm[i] = view.getInt16(i*2, Endian.little);
    return _WavData(sampleRate: sRate, channels: channels, bitsPerSample: bits, pcm16: pcm);
  }
}