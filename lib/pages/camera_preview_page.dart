import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';

import '../services/face_detector.dart';

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
  bool _isDetecting = false;
  int _frameCount = 0;

  bool _faceDetected = false; // condition to enter main pipeline

  @override
  void initState() {
    super.initState();

    // Force landscape + immersive UI
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    widget.initializeFuture.then((_) async {
      if (!mounted) return;
      await _faceDetector.loadModel();
      _startImageStream();
    });
  }

  void _startImageStream() {
    if (widget.controller.value.isStreamingImages) return;
    debugPrint('Starting image stream');

    widget.controller.startImageStream((CameraImage image) async {
      // Throttle: every 3rd frame
      _frameCount++;
      if (_frameCount % 3 != 0) return;

      // Debug: confirm frames are arriving
      debugPrint('Image frame received #$_frameCount');

      if (_isDetecting) return;
      _isDetecting = true;

      try {
        final hasFace = await _faceDetector.hasFace(image);

        if (!mounted) return;

        setState(() {
          _faceDetected = hasFace;
        });

        // This is your gate: only run main pipeline if face is present
        if (hasFace) {
          _runMainPipeline();
        } else {
          // You can decide: either pause pipeline or run only pose/cry here
        }
      } catch (e) {
        debugPrint('Face detection error: $e');
      } finally {
        _isDetecting = false;
      }
    });
  }

  void _runMainPipeline() {
    // TODO:
    // Call your:
    // - facial expression classification
    // - pose classification
    // - cry classification (after cry condition check)
    //
    // The face detector here is just the first gate:
    // if (!_faceDetected) return;
  }

  Future<void> _restorePortrait() async {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  @override
  void dispose() {
    if (widget.controller.value.isStreamingImages) {
      widget.controller.stopImageStream();
    }

    _faceDetector.dispose();

    // IMPORTANT: do NOT dispose the controller here.
    // We only restore orientation & system UI.
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

             // Simple indicator of face presence (for debugging)
            Positioned(
              bottom: 20,
              left: 20,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _faceDetected ? 'Face detected' : 'No face',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),

            // Floating back button
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
