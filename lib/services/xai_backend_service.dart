import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import '../config/api_config.dart'; 

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
  final String baseUrl;

  XaiBackendService({
    this.baseUrl = ApiConfig.xaiBaseUrl,  // <-- NOW coming from config
  });

  Future<XaiResult> predictPose(File imageFile) async {
    final uri = Uri.parse('$baseUrl/predict/pose');
    final request = http.MultipartRequest('POST', uri);

    request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception('Pose XAI failed: ${response.body}');
    }

    return XaiResult.fromJson(json.decode(response.body));
  }

  Future<XaiResult> predictExpression(File imageFile) async {
    final uri = Uri.parse('$baseUrl/predict/expression');
    final request = http.MultipartRequest('POST', uri);

    request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception('Expression XAI failed: ${response.body}');
    }

    return XaiResult.fromJson(json.decode(response.body));
  }

  Future<XaiResult> predictCry(File audioFile) async {
    final uri = Uri.parse('$baseUrl/predict/cry');
    final request = http.MultipartRequest('POST', uri);

    request.files.add(await http.MultipartFile.fromPath('file', audioFile.path));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception('Cry XAI failed: ${response.body}');
    }

    return XaiResult.fromJson(json.decode(response.body));
  }
}
