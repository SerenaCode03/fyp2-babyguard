import 'dart:math';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/foundation.dart';

class FaceDetector {
  static const String modelPath =
      'assets/models/face_detection_short_range.tflite';

  Interpreter? _interpreter;
  bool get isLoaded => _interpreter != null;

  Future<void> loadModel() async {
    if (_interpreter != null) return;
    _interpreter = await Interpreter.fromAsset(
      modelPath,
      options: InterpreterOptions()..threads = 2,
    );
    debugPrint('FaceDetector: Model loaded successfully.');
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }

  /// Main API: returns true if at least one face is detected.
  Future<bool> hasFace(CameraImage image) async {
    if (_interpreter == null) {
      throw StateError('FaceDetector: call loadModel() before hasFace().');
    }

    // 1. Convert YUV420 -> RGB
    final rgbImage = _yuv420ToRgb(image);

    // 2. Resize to 128x128 (MediaPipe face detector input size)
    final resized = img.copyResize(
      rgbImage,
      width: 128,
      height: 128,
      interpolation: img.Interpolation.linear,
    );

    // 3. Build input tensor [1,128,128,3], float32 [0,1]
    final input = List.generate(
      1,
      (_) => List.generate(
        128,
        (_) => List.generate(
          128,
          (_) => List.filled(3, 0.0),
        ),
      ),
    );

    // Normalize pixel values to [0, 1]
    for (int y = 0; y < 128; y++) {
      for (int x = 0; x < 128; x++) {
        final pixel = resized.getPixel(x, y);
        input[0][y][x][0] = pixel.r / 255.0;
        input[0][y][x][1] = pixel.g / 255.0;
        input[0][y][x][2] = pixel.b / 255.0;
      }
    }

    // 4. Prepare Output Buffers
    // The model returns TWO tensors. We must allocate space for both to avoid mismatch errors.
    
    // Output 0: Regressors (Box coords + Keypoints) -> Shape [1, 896, 16]
    final outputRegressors = List.generate(
      1,
      (_) => List.generate(
        896,
        (_) => List.filled(16, 0.0),
      ),
    );

    // Output 1: Scores (Confidence) -> Shape [1, 896, 1]
    final outputScores = List.generate(
      1,
      (_) => List.generate(
        896,
        (_) => List.filled(1, 0.0),
      ),
    );

    // Map outputs: {0: Regressors, 1: Scores}
    final Map<int, Object> outputs = {
      0: outputRegressors,
      1: outputScores,
    };

    // 5. Run Inference
    // 'input' must be wrapped in a list because runForMultipleInputs expects [input1, input2, ...]
    _interpreter!.runForMultipleInputs([input], outputs);

    // 6. Process Scores (Index 1)
    double maxScore = 0.0;
    for (int i = 0; i < 896; i++) {
      // Extract raw score from the second output tensor
      final double rawScore = outputScores[0][i][0];
      final double score = _sigmoid(rawScore);
      if (score > maxScore) {
        maxScore = score;
      }
    }

    const double threshold = 0.5; // Threshold for detection
    final bool faceDetected = maxScore >= threshold;

    debugPrint('FaceDetector: maxScore=${maxScore.toStringAsFixed(4)}, hasFace=$faceDetected');

    return faceDetected;
  }

  // Simple sigmoid for converting logits to [0,1]
  double _sigmoid(double x) {
    return 1.0 / (1.0 + exp(-x));
  }

  /// Convert YUV420 from CameraImage to RGB img.Image
  img.Image _yuv420ToRgb(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    final img.Image rgbImage =
        img.Image(width: width, height: height); // no alpha

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

        // YUV420 to RGB conversion
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
}