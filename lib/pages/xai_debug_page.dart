import 'dart:io';
import 'package:flutter/material.dart';
import '../services/xai_backend_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;

class XaiDebugPage extends StatefulWidget {
  const XaiDebugPage({super.key});

  @override
  State<XaiDebugPage> createState() => _XaiDebugPageState();
}

class _XaiDebugPageState extends State<XaiDebugPage> {
  final _service = XaiBackendService(
    baseUrl: 'https://4eae768fab73.ngrok-free.app', // make sure this matches backend
  );

  XaiResult? _result;
  bool _loading = false;
  String? _error;

  Future<File> _loadTestImageFromAssets() async {
    // 1) Put a file like assets/test_pose.jpg in your assets folder
    final data = await rootBundle.load('assets/prone_image.jpeg');

    // 2) Write it to a temp file so we can pass File to the service
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/prone_image.jpeg');
    await file.writeAsBytes(data.buffer.asUint8List());
    return file;
  }

  Future<void> _testPoseXai() async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final file = await _loadTestImageFromAssets();
      final res = await _service.predictPose(file);
      setState(() {
        _result = res;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('XAI Debug')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _loading ? null : _testPoseXai,
              child: const Text('Test Pose XAI (assets/prone_image.jpeg)'),
            ),
            const SizedBox(height: 16),
            if (_loading) const CircularProgressIndicator(),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                'Error: $_error',
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: 16),
            if (_result != null) ...[
              Text('Label: ${_result!.label}'),
              Text(
                'Confidence: '
                '${(_result!.confidence * 100).toStringAsFixed(1)}%',
              ),
              const SizedBox(height: 8),
              Text(_result!.explanation),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: Image.memory(_result!.overlayImageBytes),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
