import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';    // reuse your base backend URL
import '../services/session_manager.dart';

class EmailAlertService {
  EmailAlertService._();
  static final EmailAlertService instance = EmailAlertService._();

  Future<void> sendRiskEmail({
    required String riskLevel,
    required String sleepLabel,
    required String exprLabel,
    required String cryLabel,
    required String summary,
  }) async {
    final toEmail = SessionManager.currentUserEmail;
    if (toEmail == null || toEmail.isEmpty) {
      // No email known for this user -> skip
      return;
    }

    final url = Uri.parse('${ApiConfig.xaiBaseUrl}/notify/risk_email');

    final payload = {
      'to_email': toEmail,
      'risk_level': riskLevel,
      'sleep_label': sleepLabel,
      'expr_label': exprLabel,
      'cry_label': cryLabel,
      'summary': summary,
    };

    try {
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (resp.statusCode != 200) {
        debugPrint('[EMAIL] Failed: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      debugPrint('[EMAIL] Error sending risk email: $e');
    }
  }
}
