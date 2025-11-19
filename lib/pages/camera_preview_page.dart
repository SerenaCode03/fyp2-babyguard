import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';

import '../services/face_detector.dart';
import '../services/pose_classifier.dart';

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
  final FaceDetector _faceDetector = FaceDetector();
  final PoseClassifier _poseClassifier = PoseClassifier();

  bool _pipelineRunning = false;       // STRICT FACE GATE
  bool _isPoseProcessing = false;

  CameraImage? _latestImage;
  Timer? _poseTimer;

  PoseResult? _lastPoseResult;
  bool _faceDetectedOnce = false;      // For UI only

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

      await _faceDetector.loadModel();
      await _poseClassifier.loadModel();

      _startImageStream();
      _startFaceGateLoop();    // 🧠 Detect face UNTIL pipeline starts
    });
  }

  //----------------------------------------------------------------------
  // 1. FACE GATE LOOP — run until face detected ONCE
  //----------------------------------------------------------------------
  void _startFaceGateLoop() {
    Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // If pipeline already running → stop this loop
      if (_pipelineRunning) {
        timer.cancel();
        _startPoseTimer();        // Start pose loop after gate
        return;
      }

      if (_latestImage == null) return;

      try {
        final hasFace = await _faceDetector.hasFace(_latestImage!);

        if (hasFace) {
          debugPrint("FACE DETECTED — STARTING PIPELINE");
          setState(() {
            _pipelineRunning = true;
            _faceDetectedOnce = true;
          });
        }
      } catch (e) {
        debugPrint("Face gate error: $e");
      }
    });
  }

  //----------------------------------------------------------------------
  // 2. IMAGE STREAM — keep saving latest frame
  //----------------------------------------------------------------------
  void _startImageStream() {
    if (widget.controller.value.isStreamingImages) return;

    widget.controller.startImageStream((CameraImage image) {
      _latestImage = image;
    });
  }

  //----------------------------------------------------------------------
  // 3. POSE TIMER — runs every 5 seconds after pipeline starts
  //----------------------------------------------------------------------
  void _startPoseTimer() {
    _poseTimer?.cancel();
    _poseTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_pipelineRunning) {
        _runPoseCheck();
      }
    });
  }

  Future<void> _runPoseCheck() async {
    if (_isPoseProcessing) return;
    if (_latestImage == null) return;

    _isPoseProcessing = true;

    try {
      final poseResult = await _poseClassifier.classifyFromCameraImage(
        _latestImage!,
      );

      if (!mounted) return;

      setState(() {
        _lastPoseResult = poseResult;
      });

      // TODO later: save cropped frame for explainable AI
      // _savePoseFrameForExplainableAI(_latestImage!, poseResult);

    } catch (e) {
      debugPrint("Pose classification error: $e");
    } finally {
      _isPoseProcessing = false;
    }
  }

  //----------------------------------------------------------------------
  //   UI + Cleanup
  //----------------------------------------------------------------------
  @override
  void dispose() {
    _poseTimer?.cancel();

    if (widget.controller.value.isStreamingImages) {
      widget.controller.stopImageStream();
    }

    _faceDetector.dispose();
    _poseClassifier.dispose();

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
    await _restorePortrait();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _restorePortrait() async {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _restorePortrait();
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

            //---------------------------------------
            //   DEBUG OVERLAY
            //---------------------------------------
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
                  ],
                ),
              ),
            ),

            //---------------------------------------
            //   BACK BUTTON
            //---------------------------------------
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
