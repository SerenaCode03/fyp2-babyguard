import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path_provider/path_provider.dart';

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
  static const String modelPath = 'assets/models/mobilenetv3_fp16.tflite';
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
      options: InterpreterOptions()..threads = 2
      // options: InterpreterOptions()..threads = 2 ..useNnApiForAndroid = false,
    );
    debugPrint('ExpressionClassifier: model loaded');
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }

  Future<ExpressionResult?> classifyFromCameraImage(
    CameraImage image, {
    required Rect faceRect, 
  }) async {
    if (_interpreter == null) {
      throw StateError('ExpressionClassifier: loadModel() first.');
    }

    final rgbImage = _yuv420ToRgb(image);
    final paddedRect = _expandRect(faceRect, rgbImage.width, rgbImage.height, paddingRatio: 0.45);
    final faceCrop = _cropRect(rgbImage, paddedRect);
    final squareFace = _centerCropSquare(faceCrop);

    saveDebugFace(squareFace);
    const inputSize = 224;
    final resized = img.copyResize(
      squareFace,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.linear,
    );

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

    final output = List.generate(1, (_) => List.filled(labels.length, 0.0));
    _interpreter!.run(input, output);
    final probs = _softmax(output[0]);
    final double distressedProb = probs[0];
    final double normalProb = probs[1];

    final label = distressedProb >= 0.50 ? 'Distressed' : 'Normal';
    final confidence = label == 'Distressed' ? distressedProb : normalProb;

    return ExpressionResult(
      label: label,
      confidence: confidence,
      rawProbs: probs,
    );
  }

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

  Future<void> saveDebugFace(img.Image faceCrop) async {
    final directory = await getExternalStorageDirectory();

    if (directory == null) {
      debugPrint("Error: External storage directory not available");
      return;
    }

    final folder = Directory('${directory.path}/face_debug');

    if (!(await folder.exists())) {
      await folder.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${folder.path}/face_$timestamp.png';

    final file = File(filePath);

    await file.writeAsBytes(img.encodePng(faceCrop));

    debugPrint('Saved debug face: $filePath');
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

  Rect _expandRect(Rect rect, int imgWidth, int imgHeight,
    {double paddingRatio = 0.25}) {

    final double padW = rect.width * paddingRatio;
    final double padH = rect.height * paddingRatio;

    double newLeft = (rect.left - padW).clamp(0, imgWidth - 1).toDouble();
    double newTop = (rect.top - padH).clamp(0, imgHeight - 1).toDouble();
    double newRight = (rect.right + padW).clamp(newLeft + 1, imgWidth).toDouble();
    double newBottom = (rect.bottom + padH).clamp(newTop + 1, imgHeight).toDouble();

    return Rect.fromLTRB(newLeft, newTop, newRight, newBottom);
  }

  List<double> _softmax(List<double> logits) {
    final maxLogit = logits.reduce(max);
    final exps = logits.map((v) => exp(v - maxLogit)).toList();
    final sumExp = exps.fold<double>(0.0, (s, v) => s + v);
    return exps.map((v) => v / sumExp).toList();
  }
}
