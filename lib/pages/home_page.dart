import 'dart:ui';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fyp2_babyguard/pages/notification_page.dart';
import 'package:fyp2_babyguard/pages/report_page.dart';
import 'package:fyp2_babyguard/utilities/color.dart';
import 'package:fyp2_babyguard/pages/setting_page.dart';
import 'package:fyp2_babyguard/components/bottom_nav_bar.dart';

import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fyp2_babyguard/pages/camera_preview_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  static const double _navBarHeight = 72; // tweak to match your BottomNavBar

  final List<Widget> _pages = <Widget>[
    const _HomeContent(),
    const ReportPage(),
    const NotificationPage(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: backgroundWhite,
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // CONTENT AREA
          SafeArea(
            child: Padding(
              // 👇 reserve space for: 40 (your bottom offset) + nav bar height
              padding: EdgeInsets.only(bottom: 40 + _navBarHeight),
              child: IndexedStack(
                index: _index,
                children: _pages,
              ),
            ),
          ),

          // FLOATING NAV BAR
          Positioned(
            left: 12,
            right: 12,
            bottom: 40 + bottomInset,
            child: BottomNavBar(
              currentIndex: _index,
              onTap: (i) => setState(() => _index = i),
            ),
          ),
        ],
      ),
    );
  }
}


const _kSectionStyle = TextStyle(
  color: black,
  fontSize: 20,
  fontWeight: FontWeight.w700,
);

class _HomeContent extends StatefulWidget {
  const _HomeContent();

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  bool _monitoringActive = false;
  CameraController? _cameraController;
  Future<void>? _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    debugPrint('[_HomeContentState.initState] called');
  }

  Future<bool> _requestCameraAndMic() async {
    final cameraStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();
    // final storageStatus = await Permission.storage.request();

    debugPrint('[_requestCameraAndMic] camera: $cameraStatus, mic: $micStatus');

    if (cameraStatus.isGranted && micStatus.isGranted) {
      return true;
    } else {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera and microphone permissions are required.'),
        ),
      );
      return false;
    }
  }

  Future<void> _startCameraIfNeeded() async {
    if (_cameraController != null) {
      debugPrint('[_startCameraIfNeeded] Camera already initialized');
      return;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      if (!mounted) return;
      debugPrint('[_startCameraIfNeeded] No cameras found');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No camera available')),
      );
      return;
    }

    final firstCamera = cameras.first;

    _cameraController = CameraController(
      firstCamera,
      ResolutionPreset.high,
      enableAudio: false, // mic handled by flutter_sound
    );

    debugPrint('[_startCameraIfNeeded] Initializing camera...');
    _initializeControllerFuture = _cameraController!.initialize();
  }

  Future<void> _onStartMonitoringPressed() async {
    debugPrint('[_onStartMonitoringPressed] Start pressed');
    final granted = await _requestCameraAndMic();
    if (!granted || !mounted) {
      debugPrint('[_onStartMonitoringPressed] Permissions not granted or widget not mounted');
      return;
    }

    await _startCameraIfNeeded();

    if (_cameraController == null || _initializeControllerFuture == null) {
      debugPrint('[_onStartMonitoringPressed] Camera controller not initialized');
      return;
    }

    setState(() {
      _monitoringActive = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Monitoring started. Tap the play button to view the live camera.',
        ),
      ),
    );
  }

  Future<void> _onPlayPressed() async {
    debugPrint('[_onPlayPressed] Play pressed');

    if (!_monitoringActive ||
        _cameraController == null ||
        _initializeControllerFuture == null) {
      if (!mounted) return;
      debugPrint('[_onPlayPressed] Monitoring not active or camera not ready');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Monitoring is not active. Tap Start Monitoring first'),
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraPreviewPage(
          controller: _cameraController!,
          initializeFuture: _initializeControllerFuture!,
        ),
      ),
    );
  }

  Future<void> _onStopMonitoringPressed() async {
    debugPrint('[_onStopMonitoringPressed] Stop pressed');

    if (_cameraController != null) {
      debugPrint('[_onStopMonitoringPressed] Disposing camera controller');
      await _cameraController!.dispose();
      _cameraController = null;
      _initializeControllerFuture = null;
    }

    if (!mounted) return;

    setState(() {
      _monitoringActive = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Monitoring stopped.')),
    );
  }

  @override
  void dispose() {
    debugPrint('[_HomeContentState.dispose] Disposing');
    _cameraController?.dispose();
    // _recorder.closeRecorder();
    // _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome back,\nSerena!',
            style: TextStyle(
              color: black,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 20),

          // CAMERA SECTION
          Container(
            decoration: BoxDecoration(
              color: white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Camera',
                  style: TextStyle(
                    color: black,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
                        child: Image.asset(
                          'assets/images/baby_preview.jpg',
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _onPlayPressed,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          size: 45,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _circleButton(Icons.camera_alt_rounded),
                    const SizedBox(width: 40),
                    _circleButton(Icons.mic_rounded),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // START / STOP BUTTONS
          ElevatedButton(
            onPressed: _monitoringActive ? null : _onStartMonitoringPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0C1C4B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              minimumSize: const Size(double.infinity, 65),
            ),
            child: Text(
              _monitoringActive ? 'Monitoring Active' : 'Start Monitoring',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: OutlinedButton(
              onPressed: _monitoringActive ? _onStopMonitoringPressed : null,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.transparent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                minimumSize: const Size(double.infinity, 65),
                backgroundColor: Colors.white,
              ),
              child: const Text(
                'Stop Monitoring',
                style: TextStyle(
                  fontSize: 18,
                  color: black,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _circleButton(IconData icon) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black26, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, size: 28, color: Colors.black87),
    );
  }
}
