import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart'
    as mlkit;

import '../services/pose_classifier.dart';
import '../services/expression_classifier.dart';

class CameraPreviewPage extends StatefulWidget {
  final CameraController controller;
  final Future<void> initializeFuture;

  const CameraPreviewPage({
    super.key,
    required this.controller,
    required this.initializeFuture,
  });

  @override
  State<CameraPreviewPage> createState() => _CameraPreviewPageState();
}

class _CameraPreviewPageState extends State<CameraPreviewPage> {
  final PoseClassifier _poseClassifier = PoseClassifier();
  final ExpressionClassifier _expressionClassifier = ExpressionClassifier();

  late final mlkit.FaceDetector _mlkitFaceDetector;

  bool _pipelineRunning = false;    // set to true after first face is seen
  bool _isProcessing = false;

  CameraImage? _latestImage;
  Timer? _poseTimer;

  PoseResult? _lastPoseResult;
  ExpressionResult? _lastExpressionResult;

  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    widget.initializeFuture.then((_) async {
      if (!mounted) return;

      await _poseClassifier.loadModel();
      await _expressionClassifier.loadModel();

      _mlkitFaceDetector = mlkit.FaceDetector(
        options: mlkit.FaceDetectorOptions(
          performanceMode: mlkit.FaceDetectorMode.accurate,
          enableLandmarks: false,
          enableContours: false,
        ),
      );

      _startImageStream();
      _startFaceGateLoop();   // wait for first face to start pipeline
    });
  }

  // ---- Face gate loop: runs until we see a face once ----
  void _startFaceGateLoop() {
    Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_pipelineRunning) {
        timer.cancel();
        _startPoseTimer(); // start periodic pipeline
        return;
      }

      if (_latestImage == null) return;

      try {
        final inputImage = _inputImageFromCameraImage(_latestImage!);
        final faces = await _mlkitFaceDetector.processImage(inputImage);

        if (faces.isNotEmpty) {
          debugPrint('MLKit gate: face detected, starting pipeline');
          setState(() {
            _pipelineRunning = true;
          });
        }
      } catch (e) {
        debugPrint('MLKit gate error: $e');
      }
    });
  }

  // ---- Stream camera frames, keep the latest ----
  void _startImageStream() {
    if (widget.controller.value.isStreamingImages) return;

    widget.controller.startImageStream((CameraImage image) {
      _latestImage = image;
    });
  }

  // ---- Run pose + expression every 5 seconds once pipelineRunning ----
  void _startPoseTimer() {
    _poseTimer?.cancel();
    _poseTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_pipelineRunning) {
        _runMainPipeline();
      }
    });
  }

  Future<void> _runMainPipeline() async {
    if (_isProcessing) return;
    if (_latestImage == null) return;

    _isProcessing = true;
    final image = _latestImage!;

    try {
      // 1) Pose classification (always)
      final poseResult = await _poseClassifier.classifyFromCameraImage(image);

      // 2) Facial expression classification ONLY if MLKit sees a face
      ExpressionResult? expressionResult;

      try {
        final inputImage = _inputImageFromCameraImage(image);
        final faces = await _mlkitFaceDetector.processImage(inputImage);

        if (faces.isNotEmpty) {
          final face = faces.first;
          final Rect faceRect = face.boundingBox;

          expressionResult =
              await _expressionClassifier.classifyFromCameraImage(
            image,
            faceRect: faceRect,
          );
        } else {
          debugPrint('MLKit: no face for this frame, skip expression');
        }
      } catch (e) {
        debugPrint('MLKit face detection (pipeline) error: $e');
      }

      if (!mounted) return;

      setState(() {
        _lastPoseResult = poseResult;
        _lastExpressionResult = expressionResult; // may be null if no face
      });
    } catch (e) {
      debugPrint('Main pipeline error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  // ---- MLKit helpers: CameraImage -> InputImage ----

  mlkit.InputImage _inputImageFromCameraImage(CameraImage image) {
    final bytes = _concatenatePlanes(image.planes);

    final Size imageSize =
        Size(image.width.toDouble(), image.height.toDouble());

    final camera = widget.controller.description;
    final deviceOrientation = widget.controller.value.deviceOrientation;
    
    final rotation = _getRotation(
      camera.sensorOrientation, 
      deviceOrientation, 
      camera.lensDirection
    );
    // Convert camera rotation to MLKit rotation
    // final rotation = _mapRotation(camera.sensorOrientation);

    // Convert camera format to MLKit format
    final format = _mapFormat(image.format.raw);

    // NEW: Use InputImageMetadata instead of InputImageData
    // We use the bytesPerRow from the first plane (Y-plane)
    final inputImageMetadata = mlkit.InputImageMetadata(
      size: imageSize,
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes[0].bytesPerRow, 
    );

    return mlkit.InputImage.fromBytes(
      bytes: bytes,
      metadata: inputImageMetadata,
    );
  }

  // Helper to map standard Camera integers to MLKit Rotation Enum
  mlkit.InputImageRotation _getRotation(
    int sensorOrientation,
    DeviceOrientation deviceOrientation,
    CameraLensDirection lensDirection,
  ) {
    int deviceRotation = 0;
    switch (deviceOrientation) {
      case DeviceOrientation.portraitUp:
        deviceRotation = 0;
        break;
      case DeviceOrientation.landscapeLeft:
        deviceRotation = 90;
        break;
      case DeviceOrientation.portraitDown:
        deviceRotation = 180;
        break;
      case DeviceOrientation.landscapeRight:
        deviceRotation = 270;
        break;
    }

    int rotationCompensation = 0;
    if (lensDirection == CameraLensDirection.front) {
      // Front camera logic
      rotationCompensation = (sensorOrientation + deviceRotation) % 360;
    } else {
      // Back camera logic (Standard for baby monitors)
      rotationCompensation = (sensorOrientation - deviceRotation + 360) % 360;
    }

    // Now map the calculated compensation to ML Kit enum
    switch (rotationCompensation) {
      case 0:
        return mlkit.InputImageRotation.rotation0deg;
      case 90:
        return mlkit.InputImageRotation.rotation90deg;
      case 180:
        return mlkit.InputImageRotation.rotation180deg;
      case 270:
        return mlkit.InputImageRotation.rotation270deg;
      default:
        return mlkit.InputImageRotation.rotation0deg;
    }
  }

  // Helper to map standard Camera formats to MLKit Format Enum
  mlkit.InputImageFormat _mapFormat(dynamic format) {
    // Most Android devices use NV21 (YUV_420_888 in Flutter usually maps to this)
    // iOS usually uses bgra8888
    switch (format) {
      case 35: // YUV_420_888 (Android)
      case 17: // NV21
        return mlkit.InputImageFormat.nv21;
      case 842094169: // YV12
        return mlkit.InputImageFormat.yv12; 
      case 32: // BGRA8888 (iOS)
        return mlkit.InputImageFormat.bgra8888;
      default:
        return mlkit.InputImageFormat.nv21; // Fallback
    }
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  // ---- UI + Lifecycle ----

  @override
  void dispose() {
    _poseTimer?.cancel();

    if (widget.controller.value.isStreamingImages) {
      widget.controller.stopImageStream();
    }

    _poseClassifier.dispose();
    _expressionClassifier.dispose();
    _mlkitFaceDetector.close();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    super.dispose();
  }

  Widget _buildFullLandscapePreview() {
    if (!widget.controller.value.isInitialized) {
      return const SizedBox();
    }

    final previewSize = widget.controller.value.previewSize!;

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize.width,
          height: previewSize.height,
          child: CameraPreview(widget.controller),
        ),
      ),
    );
  }

  Future<void> _handleBack() async {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _handleBack();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            FutureBuilder<void>(
              future: widget.initializeFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return _buildFullLandscapePreview();
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            ),

            // Debug overlay
            Positioned(
              bottom: 20,
              left: 20,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _pipelineRunning
                          ? 'Monitoring Active'
                          : 'Waiting for Baby Face...',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _lastPoseResult != null
                          ? 'Pose: ${_lastPoseResult!.label} '
                            '(${(_lastPoseResult!.confidence * 100).toStringAsFixed(1)}%)'
                          : 'Pose: --',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _lastExpressionResult != null
                          ? 'Expression: ${_lastExpressionResult!.label} '
                            '(${(_lastExpressionResult!.confidence * 100).toStringAsFixed(1)}%)'
                          : 'Expression: (no face)',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),

            // Back button
            Positioned(
              top: 20,
              left: 20,
              child: GestureDetector(
                onTap: _handleBack,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
