// lib/services/xai_backend_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class XaiResult {
  final String label;
  final double confidence;
  final String explanation;
  final Uint8List overlayImageBytes;

  XaiResult({
    required this.label,
    required this.confidence,
    required this.explanation,
    required this.overlayImageBytes,
  });

  factory XaiResult.fromJson(Map<String, dynamic> json) {
    final overlayBase64 = json['overlay_image'] as String;
    final bytes = base64Decode(overlayBase64);

    return XaiResult(
      label: json['label'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      explanation: json['explanation'] as String,
      overlayImageBytes: bytes,
    );
  }
}

class XaiBackendService {
  /// - Physical device:  http://<your-laptop-ip>:8000
  final String baseUrl;

  XaiBackendService({
    this.baseUrl = 'https://c5efad4b6cf8.ngrok-free.app',
  });

  Future<XaiResult> predictPose(File imageFile) async {
    final uri = Uri.parse('$baseUrl/predict/pose');
    final request = http.MultipartRequest('POST', uri);

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',       // MUST match `file: UploadFile = File(...)`
        imageFile.path,
      ),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception('Pose XAI failed: ${response.body}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    return XaiResult.fromJson(data);
  }

  Future<XaiResult> predictExpression(File imageFile) async {
    final uri = Uri.parse('$baseUrl/predict/expression');
    final request = http.MultipartRequest('POST', uri);

    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception('Expression XAI failed: ${response.body}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    return XaiResult.fromJson(data);
  }

  Future<XaiResult> predictCry(File audioFile) async {
    final uri = Uri.parse('$baseUrl/predict/cry');
    final request = http.MultipartRequest('POST', uri);

    request.files.add(
      await http.MultipartFile.fromPath('file', audioFile.path));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception('Cry XAI failed: ${response.body}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    return XaiResult.fromJson(data);
  }
}
