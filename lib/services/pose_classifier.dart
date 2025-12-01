// lib/services/pose_classifier.dart
import 'dart:math';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path_provider/path_provider.dart';

class PoseResult {
  final String label;          // "Abnormal" or "Normal"
  final double confidence;     // softmax prob of the predicted class
  final List<double> rawProbs; // full [Abnormal, Normal] probabilities

  PoseResult({
    required this.label,
    required this.confidence,
    required this.rawProbs,
  });

  @override
  String toString() =>
      'PoseResult(label: $label, confidence: ${confidence.toStringAsFixed(3)})';
}

class PoseClassifier {
  static const String modelPath = 'assets/models/efficientnet_b0_fp16.tflite';

  static const List<String> labels = [
    'Abnormal',
    'Normal',
  ];

  Interpreter? _interpreter;
  bool get isLoaded => _interpreter != null;

  Future<void> loadModel() async {
    if (_interpreter != null) return;
    _interpreter = await Interpreter.fromAsset(
      modelPath,
      options: InterpreterOptions()..threads = 2,
    );
    debugPrint('PoseClassifier: model loaded');
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }

  /// Classify pose from a CameraImage frame (full frame, no cropping here).
  /// Later, for explainable AI, you can reuse the resized image inside this
  /// method for Grad-CAM or saving crops.
  Future<PoseResult> classifyFromCameraImage(CameraImage image) async {
    if (_interpreter == null) {
      throw StateError('PoseClassifier: call loadModel() before classify.');
    }

    // 1) Convert YUV420 -> RGB
    final rgbImage = _yuv420ToRgb(image);

    // 2) Resize to model input size (adjust if your model uses different size)
    const inputSize = 224;
    final resized = img.copyResize(
      rgbImage,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.linear,
    );
    
    _saveDebugPose(resized);

    // 3) Build input tensor [1, 224, 224, 3], float32 [0,1]
    final input = List.generate(
      1,
      (_) => List.generate(
        inputSize,
        (_) => List.generate(
          inputSize,
          (_) => List.filled(3, 0.0),
        ),
      ),
    );

    const meanR = 0.485;
    const meanG = 0.456;
    const meanB = 0.406;

    const stdR = 0.229;
    const stdG = 0.224;
    const stdB = 0.225;

    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = resized.getPixel(x, y);

        final r = pixel.r / 255.0;
        final g = pixel.g / 255.0;
        final b = pixel.b / 255.0;

        input[0][y][x][0] = (r - meanR) / stdR;
        input[0][y][x][1] = (g - meanG) / stdG;
        input[0][y][x][2] = (b - meanB) / stdB;
      }
    }

    // 4) Output buffer [1, 2] for [Abnormal, Normal]
    final output = List.generate(
      1,
      (_) => List.filled(labels.length, 0.0),
    );

    _interpreter!.run(input, output);

    // 5) Softmax probabilities
    final probs = _softmax(output[0]);

    // 6) Argmax
    int bestIdx = 0;
    double bestProb = probs[0];
    for (int i = 1; i < probs.length; i++) {
      if (probs[i] > bestProb) {
        bestProb = probs[i];
        bestIdx = i;
      }
    }

    final result = PoseResult(
      label: labels[bestIdx],
      confidence: bestProb,
      rawProbs: probs,
    );

    debugPrint('PoseClassifier: $result');
    return result;
  }

  Future<void> _saveDebugPose(img.Image resized) async {
    final directory = await getExternalStorageDirectory();
    if (directory == null) {
      debugPrint("PoseClassifier: External storage unavailable");
      return;
    }

    final folder = Directory('${directory.path}/pose_debug');

    if (!(await folder.exists())) {
      await folder.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${folder.path}/pose_$timestamp.png';

    final file = File(filePath);
    await file.writeAsBytes(img.encodePng(resized));

    debugPrint('PoseClassifier: Saved debug pose image → $filePath');
  }


  // Placeholder for later explainable AI integration.
  // You can implement saving the resized or cropped frame in here.
  void _saveCroppedForExplainableAI(img.Image resized) {
    // TODO: implement disk saving or buffer caching for Grad-CAM later.
  }

  // YUV420 to RGB conversion, same as in your FaceDetector.
  img.Image _yuv420ToRgb(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    final img.Image rgbImage = img.Image(width: width, height: height);

    final Plane yPlane = image.planes[0];
    final Plane uPlane = image.planes[1];
    final Plane vPlane = image.planes[2];

    final int yRowStride = yPlane.bytesPerRow;
    final int uvRowStride = uPlane.bytesPerRow;
    final int uvPixelStride = uPlane.bytesPerPixel!;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * yRowStride + x;
        final int uvIndex =
            (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;

        final int yp = yPlane.bytes[yIndex];
        final int up = uPlane.bytes[uvIndex];
        final int vp = vPlane.bytes[uvIndex];

        double r = yp + 1.402 * (vp - 128);
        double g = yp - 0.344136 * (up - 128) - 0.714136 * (vp - 128);
        double b = yp + 1.772 * (up - 128);

        final int ri = r.clamp(0, 255).toInt();
        final int gi = g.clamp(0, 255).toInt();
        final int bi = b.clamp(0, 255).toInt();

        rgbImage.setPixelRgba(x, y, ri, gi, bi, 255);
      }
    }

    return rgbImage;
  }

  List<double> _softmax(List<double> logits) {
    final maxLogit = logits.reduce(max);
    final exps = logits.map((v) => exp(v - maxLogit)).toList();
    final sumExp = exps.fold<double>(0.0, (s, v) => s + v);
    return exps.map((v) => v / sumExp).toList();
  }
}
