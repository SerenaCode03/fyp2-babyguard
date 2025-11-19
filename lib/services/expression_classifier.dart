import 'dart:math';
import 'dart:ui' show Rect;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class ExpressionResult {
  final String label;
  final double confidence;
  final List<double> rawProbs;

  ExpressionResult({
    required this.label,
    required this.confidence,
    required this.rawProbs,
  });

  @override
  String toString() =>
      'ExpressionResult(label: $label, confidence: ${confidence.toStringAsFixed(3)})';
}

class ExpressionClassifier {
  static const String modelPath =
      'assets/models/mobilenetv3_fp16.tflite';

  // Change to match your model's class order
  static const List<String> labels = [
    'Distressed',
    'Normal'
  ];

  Interpreter? _interpreter;
  bool get isLoaded => _interpreter != null;

  Future<void> loadModel() async {
    if (_interpreter != null) return;
    _interpreter = await Interpreter.fromAsset(
      modelPath,
      options: InterpreterOptions()..threads = 2,
    );
    debugPrint('ExpressionClassifier: model loaded');
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }

  /// If [faceRect] is provided: crop that region and send to model.
  /// If null: fallback to center-square crop.
  Future<ExpressionResult> classifyFromCameraImage(
    CameraImage image, {
    Rect? faceRect,
  }) async {
    if (_interpreter == null) {
      throw StateError('ExpressionClassifier: call loadModel() before classify.');
    }

    // 1) YUV -> RGB
    final rgbImage = _yuv420ToRgb(image);

    // 2) Crop face region if available, otherwise center crop
    img.Image crop;
    if (faceRect != null) {
      crop = _cropRect(rgbImage, faceRect);
    } else {
      crop = _centerCropSquare(rgbImage);
    }

    // 3) Resize to model input size
    const inputSize = 224;
    final resized = img.copyResize(
      crop,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.linear,
    );

    // Placeholder: save for XAI later if you want
    // _saveFaceCropForExplainableAI(resized);

    // 4) Build input tensor [1, 224, 224, 3]
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

    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = resized.getPixel(x, y);
        input[0][y][x][0] = pixel.r/ 255.0;
        input[0][y][x][1] = pixel.g / 255.0;
        input[0][y][x][2] = pixel.b / 255.0;
      }
    }

    // 5) Output buffer [1, numClasses]
    final output = List.generate(
      1,
      (_) => List.filled(labels.length, 0.0),
    );

    _interpreter!.run(input, output);

    // 6) Softmax + argmax
    final probs = _softmax(output[0]);
    int bestIdx = 0;
    double bestProb = probs[0];
    for (int i = 1; i < probs.length; i++) {
      if (probs[i] > bestProb) {
        bestProb = probs[i];
        bestIdx = i;
      }
    }

    final result = ExpressionResult(
      label: labels[bestIdx],
      confidence: bestProb,
      rawProbs: probs,
    );

    debugPrint('ExpressionClassifier: $result');
    return result;
  }

  // ---- Helpers ----

  img.Image _centerCropSquare(img.Image src) {
    final w = src.width;
    final h = src.height;
    final size = min(w, h);
    final left = (w - size) ~/ 2;
    final top = (h - size) ~/ 2;
    return img.copyCrop(src, x: left, y: top, width: size, height: size);
  }

  img.Image _cropRect(img.Image src, Rect rect) {
    int left = rect.left.round();
    int top = rect.top.round();
    int right = rect.right.round();
    int bottom = rect.bottom.round();

    left = left.clamp(0, src.width - 1);
    top = top.clamp(0, src.height - 1);
    right = right.clamp(left + 1, src.width);
    bottom = bottom.clamp(top + 1, src.height);

    final width = right - left;
    final height = bottom - top;

    return img.copyCrop(
      src,
      x: left,
      y: top,
      width: width,
      height: height,
    );
  }

  void _saveFaceCropForExplainableAI(img.Image faceCrop) {
    // TODO: implement saving later
  }

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
