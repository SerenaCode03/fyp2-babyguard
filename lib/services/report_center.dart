//services/report_center.dart
import 'dart:io'; 
import 'package:flutter/foundation.dart';
import 'package:fyp2_babyguard/services/xai_backend_service.dart';

/// A single saved alert generated when we called the XAI backend.
class AlertSnapshot {
  final DateTime time;     // when this alert happened
  final String riskLevel;  // "HIGH" | "MEDIUM" | "LOW"
  final String summary;    // short description used in list
  final XaiResult poseXai;
  final XaiResult? expressionXai;
  final XaiResult? cryXai;
  final File originalFrameFile;
  final String poseLabel;
  final String expressionLabel;
  final String cryLabel;

  AlertSnapshot({
    required this.time,
    required this.riskLevel,
    required this.summary,
    required this.poseXai,
    this.expressionXai,
    this.cryXai,
    required this.originalFrameFile,
    required this.poseLabel,
    required this.expressionLabel,
    required this.cryLabel,
  });
}

class ReportCenter {
  ReportCenter._();
  static final ReportCenter instance = ReportCenter._();

  final ValueNotifier<List<AlertSnapshot>> _alerts =
      ValueNotifier<List<AlertSnapshot>>([]);

  ValueListenable<List<AlertSnapshot>> get alerts => _alerts;

  void addAlert(AlertSnapshot snapshot) {
    final list = List<AlertSnapshot>.from(_alerts.value);
    list.insert(0, snapshot); // newest first
    _alerts.value = list;
  }

  void clear() {
    _alerts.value = [];
  }
}
