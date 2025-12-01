// pages/camera_preview_page.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:record/record.dart';    
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart' as mlkit;

import '../services/pose_classifier.dart';
import '../services/expression_classifier.dart';
import '../services/cry_classifier.dart';
import '../services/risk_scoring.dart';   
import '../services/xai_backend_service.dart';

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
  final CryClassifier _cryClassifier = CryClassifier();
  final AudioRecorder _recorder = AudioRecorder();
  final XaiBackendService _xaiService = XaiBackendService();

  late final mlkit.FaceDetector _mlkitFaceDetector;

  bool _pipelineRunning = false;    // set to true after first face is seen
  bool _isProcessing = false;

  CameraImage? _latestImage;
  Timer? _poseTimer;
  Timer? _cryTimer;

  PoseResult? _lastPoseResult;
  ExpressionResult? _lastExpressionResult;
  CryResult? _lastCryResult;

  RiskResult? _lastRiskResult;

  DateTime? _poseTimestamp;
  DateTime? _exprTimestamp;
  DateTime? _cryTimestamp;
  File? _lastFrameFile;
  Rect? _lastExprFaceRect;

  XaiResult? _lastPoseXai;
  XaiResult? _lastExpressionXai;
  XaiResult? _lastCryXai;

  static const Duration _riskWindow = Duration(seconds: 10);
  final List<bool> _asphyxiaRing = [];
  static const int _M = 5;              // window size
  static const int _N = 3;              // votes needed
  DateTime _nextAllowedAlert = DateTime.fromMillisecondsSinceEpoch(0);

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
      await _debugCheckInputDevices();
      await _poseClassifier.loadModel();
      await _expressionClassifier.loadModel();
      await _cryClassifier.load();

      _mlkitFaceDetector = mlkit.FaceDetector(
        options: mlkit.FaceDetectorOptions(
          performanceMode: mlkit.FaceDetectorMode.accurate,
          enableLandmarks: false,
          enableContours: false,
        ),
      );

      _startImageStream();
      _startFaceGateLoop();   // wait for first face to start pipeline
      // _startCryLoop();
    });
  }

  void _startCryLoop() {
    _cryTimer?.cancel();
    _cryTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final wavPath = await _recordOneSecondWav();
      if (wavPath == null) return;

      // final res = await _cryClassifier.classifyFromWavFile(wavPath);
      final res = await _cryClassifier.classifyLongAudio(wavPath);
      try { await File(wavPath).delete(); } catch (_) {}

      if (!mounted || res == null) return;

      setState(() {
        _lastCryResult = res;
        _cryTimestamp = DateTime.now();
      });

      _updateAsphyxiaVotes(res);
      _evaluateAndMaybeSendXAI();
    });
  }

  Future<String?> _recordOneSecondWav() async {
    try {
      // 1. Check permissions
      if (!await _recorder.hasPermission()) return null;
      final devices = await _recorder.listInputDevices();
      InputDevice? targetMic;
      
      try {
        // Try to find the specific back mic you saw in the logs
        targetMic = devices.firstWhere((d) => d.id == '6'); 
        debugPrint("Selected Mic: ${targetMic.label} (ID: ${targetMic.id})");
      } catch (e) {
        // Safety fallback: If ID 6 isn't found, just use the first available one
        if (devices.isNotEmpty) {
           targetMic = devices.first;
           debugPrint("Back mic (ID 6) not found, using default: ${targetMic.label}");
        }
      }

      // 3. Create a temporary file path
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/cry_${DateTime.now().millisecondsSinceEpoch}.wav';

      // 4. Start Recording
      await _recorder.start(
        RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 44100,
          numChannels: 1,
          device: targetMic,      // <--- USES THE MIC WE FOUND ABOVE
          noiseSuppress: false,   // Disable noise cancellation (hears the baby better)
          echoCancel: false,      // Disable echo cancellation
          autoGain: true,         // Auto-boost volume if it's quiet
          // --------------------
        ),
        path: path,
      );

      // 5. Record for 1 second
      await Future.delayed(const Duration(milliseconds: 5500));

      // 6. Stop
      await _recorder.stop();

      // 7. Verify file exists and is valid
      final f = File(path);
      if (await f.exists() && (await f.length()) > 44) {
        return path;
      }
    } catch (e) {
      debugPrint("Audio record error: $e");
    }
    return null;
  }

  // Paste this helper method inside your class
  Future<void> _debugCheckInputDevices() async {
    // We need to ensure we have permission before listing devices
    if (!await _recorder.hasPermission()) return;

    final devices = await _recorder.listInputDevices();
    debugPrint("--- AVAILABLE MICROPHONES ---");
    for (var device in devices) {
      debugPrint("ID: ${device.id} | Label: ${device.label}");
    }
    debugPrint("-----------------------------");
  }

  void _updateAsphyxiaVotes(CryResult res) {
    if (res.label == 'Silent') return;

    // Favor recall for asphyxia; tune threshold after field logs
    final probs = res.rawProbs;
    final asphyxiaConf = (probs.isNotEmpty) ? probs[0] : (res.label == 'Asphyxia' ? res.confidence : 0.0);
    final bool voteAsphyxia = asphyxiaConf >= 0.40;

    _asphyxiaRing.add(voteAsphyxia);
    if (_asphyxiaRing.length > _M) _asphyxiaRing.removeAt(0);

    final votes = _asphyxiaRing.where((v) => v).length;
    final now = DateTime.now();
    if (votes >= _N && now.isAfter(_nextAllowedAlert)) {
      _nextAllowedAlert = now.add(const Duration(seconds: 30));
      _asphyxiaRing.clear();
    }
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
      Rect? faceRectForExpr; 

      try {
        final inputImage = _inputImageFromCameraImage(image);
        final faces = await _mlkitFaceDetector.processImage(inputImage);

        if (faces.isNotEmpty) {
          final face = faces.first;
          final Rect faceRect = face.boundingBox;
          faceRectForExpr = faceRect;

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

      // 3) Cache this frame (and face rect) for possible XAI use
      final frameFile = await _saveCameraImageToJpeg(image);
      if (frameFile != null) {
        _lastFrameFile = frameFile;
        _lastExprFaceRect = faceRectForExpr;  // can be null if no face
      }

      if (!mounted) return;

      setState(() {
        _lastPoseResult = poseResult;
        _poseTimestamp = DateTime.now();

        // Expression may be null if no face
        _lastExpressionResult = expressionResult;
        if (expressionResult != null) {
          _exprTimestamp = DateTime.now();
        }
      });
      // After updating, try risk evaluation
      _evaluateAndMaybeSendXAI();
    } catch (e) {
      debugPrint('Main pipeline error: $e');
    } finally {
      _isProcessing = false;
    }
  }

    Future<File?> _saveCameraImageToJpeg(CameraImage image) async {
    try {
      // Convert YUV420 to RGB using the image package
      final img.Image rgbImage = _yuv420ToImage(image);

      final jpgBytes = img.encodeJpg(rgbImage, quality: 90);

      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/xai_frame_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File(path);
      await file.writeAsBytes(jpgBytes);

      return file;
    } catch (e) {
      debugPrint('[XAI] Error converting CameraImage to JPEG: $e');
      return null;
    }
  }

  // Basic YUV420 -> RGB conversion for CameraImage (Android)
  img.Image _yuv420ToImage(CameraImage image) {
    final width = image.width;
    final height = image.height;

    final img.Image imgBuffer = img.Image(width: width, height: height);

    final Plane planeY = image.planes[0];
    final Plane planeU = image.planes[1];
    final Plane planeV = image.planes[2];

    final int strideY = planeY.bytesPerRow;
    final int strideU = planeU.bytesPerRow;
    final int strideV = planeV.bytesPerRow;

    final bytesY = planeY.bytes;
    final bytesU = planeU.bytes;
    final bytesV = planeV.bytes;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int indexY = y * strideY + x;

        final int uvRow = (y / 2).floor();
        final int uvCol = (x / 2).floor();

        final int indexU = uvRow * strideU + uvCol;
        final int indexV = uvRow * strideV + uvCol;

        final int Y = bytesY[indexY];
        final int U = bytesU[indexU];
        final int V = bytesV[indexV];

        // Convert YUV to RGB (BT.601)
        double yf = Y.toDouble();
        double uf = U.toDouble() - 128.0;
        double vf = V.toDouble() - 128.0;

        int r = (yf + 1.402 * vf).round();
        int g = (yf - 0.344136 * uf - 0.714136 * vf).round();
        int b = (yf + 1.772 * uf).round();

        r = r.clamp(0, 255);
        g = g.clamp(0, 255);
        b = b.clamp(0, 255);

        imgBuffer.setPixelRgb(x, y, r, g, b);
      }
    }

    return imgBuffer;
  }


  Future<void> _sendCryXai(String wavPath) async {
    try {
      final result = await _xaiService.predictCry(File(wavPath));
      if (!mounted) return;
      setState(() {
        _lastCryXai = result;
      });
      debugPrint('[XAI] Cry label=${result.label}, '
          'conf=${result.confidence}, explanation=${result.explanation}');
    } catch (e) {
      debugPrint('[XAI] Cry error: $e');
    }
  }

  Future<void> _runInjectionTest() async {
    debugPrint("STARTING FILE INJECTION TEST");

    File? tempFile;

    try {
      // 1. Load WAV from assets
      final byteData = await rootBundle.load('assets/pain_1s_4.wav');

      // 2. Write to temp file
      final dir = await getTemporaryDirectory();
      tempFile = File('${dir.path}/temp_injection_test.wav');
      await tempFile.writeAsBytes(byteData.buffer.asUint8List());

      debugPrint("Loaded injection file (${byteData.lengthInBytes} bytes)");
      debugPrint("Feeding to CryClassifier...");

      // 3. Run LOCAL classifier
      final result = await _cryClassifier.classifyLongAudio(tempFile.path);

      if (!mounted) return;

      if (result != null) {
        setState(() {
          _lastCryResult = result;
        });
        _cryTimestamp = DateTime.now();

        // 4. Feed into risk scoring (pose + expr + cry)
        final risk = _evaluateAndMaybeSendXAI();

        debugPrint("------------------------------------------------");
        debugPrint("LOCAL CRY RESULT: ${result.label}");
        debugPrint(
          "Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%",
        );
        debugPrint("All Probs: ${result.rawProbs}");
        debugPrint("------------------------------------------------");

        // 5. Only call cry XAI backend if risk says shouldSendToCloud
        if (risk != null && risk.shouldSendToCloud && tempFile != null) {
          debugPrint(
            "[XAI] Risk.shouldSendToCloud = true (from injection), calling cry XAI...",
          );

          XaiResult? cryXai;
          try {
            // tempFile is non-null here because of the check above
            final wavFile = tempFile;

            cryXai = await _xaiService.predictCry(wavFile);
            if (!mounted) return;

            setState(() {
              _lastCryXai = cryXai;
            });
          } catch (e) {
            debugPrint("[XAI] Cry injection error: $e");
          }

          // 6. Optional: show a dialog with cry explainability
          if (cryXai != null && mounted) {
            // Promote to non-null inside this block
            final nonNullCryXai = cryXai;

            debugPrint(
              '[XAI] Cry label=${nonNullCryXai.label}, '
              'conf=${nonNullCryXai.confidence}, '
              'explanation=${nonNullCryXai.explanation}',
            );

            await showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: const Text('Cry Injection XAI'),
                  content: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Local classifier:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${result.label} '
                          '(${(result.confidence * 100).toStringAsFixed(1)}%)',
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Backend explainability:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${nonNullCryXai.label} '
                          '(${(nonNullCryXai.confidence * 100).toStringAsFixed(1)}%)',
                        ),
                        const SizedBox(height: 4),
                        Text(nonNullCryXai.explanation),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 180,
                          child: Image.memory(nonNullCryXai.overlayImageBytes),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                );
              },
            );
          }
        } else {
          debugPrint(
            "[XAI] Risk is null or shouldSendToCloud = false; skipping cry XAI.",
          );
        }
      } else {
        debugPrint("Classifier returned null (File error?)");
      }
    } catch (e) {
      debugPrint("INJECTION ERROR: $e");
    } finally {
      // Clean up temp file
      if (tempFile != null) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }


    Future<void> _sendXaiRequest() async {
      debugPrint('[XAI] Sending cached frame to backend...');

      try {
        // 0) Make sure we actually have a cached frame
        if (_lastFrameFile == null) {
          debugPrint('[XAI] No cached frame available; skipping XAI.');
          return;
        }

        final imageFile = _lastFrameFile!;

        // 1) Pose XAI on cached FULL frame
        final poseXai = await _xaiService.predictPose(imageFile);

        // 2) Prepare expression XAI image using cached face rect (if any)
        File? exprImageFile;
        final faceRect = _lastExprFaceRect;

        if (faceRect != null) {
          try {
            debugPrint(
              '[XAI] Using cached face rect for expression: '
              'left=${faceRect.left}, top=${faceRect.top}, '
              'width=${faceRect.width}, height=${faceRect.height}',
            );

            final bytes = await imageFile.readAsBytes();
            final original = img.decodeImage(bytes);

            if (original != null) {
              int x = faceRect.left.round();
              int y = faceRect.top.round();
              int w = faceRect.width.round();
              int h = faceRect.height.round();

              if (x < 0) x = 0;
              if (y < 0) y = 0;
              if (x + w > original.width) {
                w = original.width - x;
              }
              if (y + h > original.height) {
                h = original.height - y;
              }

              final cropped = img.copyCrop(
                original,
                x: x,
                y: y,
                width: w,
                height: h,
              );

              final dir = await getTemporaryDirectory();
              final facePath =
                  '${dir.path}/xai_expr_face_${DateTime.now().millisecondsSinceEpoch}.jpg';
              final faceFile = File(facePath);
              await faceFile.writeAsBytes(img.encodeJpg(cropped));

              exprImageFile = faceFile;
            } else {
              debugPrint('[XAI] Failed to decode cached frame for cropping.');
            }
          } catch (e) {
            debugPrint('[XAI] Error while cropping cached face: $e');
          }
        } else {
          debugPrint('[XAI] No cached face rect; expression XAI will use full frame.');
        }

        // 3) Expression XAI: prefer cropped face; fallback to full frame
        XaiResult? exprXai;
        try {
          final fileForExpr = exprImageFile ?? imageFile;
          exprXai = await _xaiService.predictExpression(fileForExpr);
        } catch (e) {
          debugPrint('[XAI] Expression call failed: $e');
        }

        if (!mounted) return;

        setState(() {
          _lastPoseXai = poseXai;
          _lastExpressionXai = exprXai;
        });

        // 4) Show dialog (same as before)
        await showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Explainability Snapshot'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pose (backend):',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${poseXai.label} '
                      '(${(poseXai.confidence * 100).toStringAsFixed(1)}%)',
                    ),
                    const SizedBox(height: 4),
                    Text(poseXai.explanation),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 180,
                      child: Image.memory(poseXai.overlayImageBytes),
                    ),
                    const SizedBox(height: 16),

                    if (exprXai != null) ...[
                      const Text(
                        'Expression (backend):',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${exprXai.label} '
                        '(${(exprXai.confidence * 100).toStringAsFixed(1)}%)',
                      ),
                      const SizedBox(height: 4),
                      Text(exprXai.explanation),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 180,
                        child: Image.memory(exprXai.overlayImageBytes),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      } catch (e) {
        debugPrint('[XAI] Error sending snapshot: $e');
      } finally {
        // No need to stop/start image stream here anymore,
        // since we used the cached frame, not takePicture().
      }
  }


  RiskResult? _evaluateAndMaybeSendXAI() {
    final now = DateTime.now();
    debugPrint('[Risk] ENTER evaluateAndMaybeSendXAI at $now');

    // --- 1) Decide which labels to use based on freshness ---
    String sleepLabel = 'Normal';
    if (_lastPoseResult != null &&
        _poseTimestamp != null &&
        now.difference(_poseTimestamp!) <= _riskWindow) {
      sleepLabel = _lastPoseResult!.label;
    }

    String exprLabel = 'Normal';
    if (_lastExpressionResult != null &&
        _exprTimestamp != null &&
        now.difference(_exprTimestamp!) <= _riskWindow) {
      exprLabel = _lastExpressionResult!.label;
    }

    String cryLabel = 'Silent';
    if (_lastCryResult != null &&
        _cryTimestamp != null &&
        now.difference(_cryTimestamp!) <= _riskWindow) {
      cryLabel = _lastCryResult!.label;
    }

    debugPrint('[Risk] Using labels -> '
        'sleep=$sleepLabel, expr=$exprLabel, cry=$cryLabel');

    // If literally everything is baseline, skip
    if (sleepLabel == 'Normal' &&
        exprLabel == 'Normal' &&
        cryLabel == 'Silent') {
      debugPrint('[Risk] All baseline (Normal/Normal/Silent), skipping.');
      return null;
    }

    // --- 2) Evaluate risk ---
    final risk = evaluateRisk(
      sleeping: Pred(sleepLabel),
      expression: Pred(exprLabel),
      cry: Pred(cryLabel),
    );

    setState(() {
      _lastRiskResult = risk;
    });

    debugPrint(
      '[Risk] RESULT -> total=${risk.totalScore} '
      'level=${risk.riskLevel} '
      'action=${risk.action} '
      'sendToCloud=${risk.shouldSendToCloud}',
    );

    if (risk.totalScore <= 0) {
      debugPrint('[Risk] totalScore <= 0, no further action.');
      return risk;
    }

    if (risk.riskLevel == 'High') {
      debugPrint('[Risk] HIGH risk detected! (should alert user)');
      // TODO: local alert UI/notification
    }

    if (risk.shouldSendToCloud) {
      debugPrint('[Risk] shouldSendToCloud = true, call XAI backend here.');
      _sendXaiRequest(); 
    }

    return risk;
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

    // Convert camera format to MLKit format
    final format = _mapFormat(image.format.raw);
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

    _cryTimer?.cancel();
    _recorder.cancel(); // ensures recorder is released
    _cryClassifier.dispose();

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
                    const SizedBox(height: 4),
                    Text(
                      _lastCryResult != null
                          ? 'Cry: ${_lastCryResult!.label} '
                            '(${(_lastCryResult!.confidence * 100).toStringAsFixed(1)}%)'
                          : 'Cry: --',
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
            Positioned(
            top: 50,
            right: 20,
            child: FloatingActionButton.small(
              backgroundColor: Colors.white,
              child: const Icon(Icons.bug_report, color: Colors.black),
              onPressed: () {
                _runInjectionTest();
              },
            ),
          ),
          ],
        ),
      ),
    );
  }
}
