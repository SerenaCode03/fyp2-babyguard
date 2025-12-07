// services/report_center.dart
import 'dart:io';
import 'dart:typed_data'; 
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

import 'database_helper.dart';
import 'xai_backend_service.dart';

/// For DB-loaded insights
class StoredInsight {
  final String imagePath;
  final String title;
  final String description;

  StoredInsight({
    required this.imagePath,
    required this.title,
    required this.description,
  });
}

/// A single saved alert generated when we called the XAI backend.
class AlertSnapshot {
  final DateTime time;     // when this alert happened
  final String riskLevel;  // "HIGH" | "MODERATE" | "LOW"
  final String summary;    // short description used in list

  // Live XAI results (when just generated in this session).
  // These will be null for DB-loaded alerts.
  final XaiResult? poseXai;
  final XaiResult? expressionXai;
  final XaiResult? cryXai;

  // Snapshot frame
  final File originalFrameFile;

  // Labels
  final String poseLabel;
  final String expressionLabel;
  final String cryLabel;

  // When loaded from DB, we don’t reconstruct XaiResult;
  // instead we keep pre-parsed insights & metrics.
  final List<StoredInsight>? storedInsights;
  final Map<String, double>? storedMetrics;

  final int? reportLatencyMs;

  AlertSnapshot({
    required this.time,
    required this.riskLevel,
    required this.summary,
    required this.poseXai,
    required this.expressionXai,
    required this.cryXai,
    required this.originalFrameFile,
    required this.poseLabel,
    required this.expressionLabel,
    required this.cryLabel,
    this.storedInsights,
    this.storedMetrics,
    this.reportLatencyMs,
  });
}

class ReportCenter {
  ReportCenter._();
  static final ReportCenter instance = ReportCenter._();

  final ValueNotifier<List<AlertSnapshot>> _alerts =
      ValueNotifier<List<AlertSnapshot>>([]);

  ValueListenable<List<AlertSnapshot>> get alerts => _alerts;

  /// In-memory only (old behaviour, still ok to use in tests)
  void addAlert(AlertSnapshot snapshot) {
    final list = List<AlertSnapshot>.from(_alerts.value);
    list.insert(0, snapshot); // newest first
    _alerts.value = list;
  }

  void clear() {
    _alerts.value = [];
  }

  // Helper: save Grad-CAM overlay bytes to a PNG file and return its path
  Future<String> _saveOverlayToFile(Uint8List bytes, String prefix) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes);
    return file.path;
  }

  // SAVE: DB-backed save (called from CameraPreviewPage)
  Future<void> addAlertAndPersist({
  required int userId,
  required AlertSnapshot snapshot,
}) async {
  final db = await DatabaseHelper.instance.database;

  // 0) Persist the hero frame into app documents dir
  final docsDir = await getApplicationDocumentsDirectory();
  final ts = snapshot.time.millisecondsSinceEpoch;
  final persistedFrameFile = await snapshot.originalFrameFile.copy(
    '${docsDir.path}/frame_$ts.png',
  );

  // 1) Insert main report row using the *persisted* path
  final reportId = await db.insert('reports', {
    'userId': userId,
    'timestamp': snapshot.time.toIso8601String(),
    'riskLevel': snapshot.riskLevel,
    'alertTitle': 'BabyGuard Alert',
    'alertMessage': snapshot.summary,
    'snapshotPath': persistedFrameFile.path,  
    'poseLabel': snapshot.poseLabel,
    'poseConfidence': snapshot.poseXai?.confidence,
    'expressionLabel':
        snapshot.expressionLabel.isNotEmpty ? snapshot.expressionLabel : null,
    'expressionConfidence': snapshot.expressionXai?.confidence,
    'cryLabel': snapshot.cryLabel.isNotEmpty ? snapshot.cryLabel : null,
    'cryConfidence': snapshot.cryXai?.confidence,
    'reportLatencyMs': snapshot.reportLatencyMs,
  });

    // 2) Save Grad-CAM overlays to files (if available)
    String? poseOverlayPath;
    String? exprOverlayPath;
    String? cryOverlayPath;

    if (snapshot.poseXai != null) {
      poseOverlayPath = await _saveOverlayToFile(
        snapshot.poseXai!.overlayImageBytes,
        'pose_overlay',
      );
    }

    if (snapshot.expressionXai != null) {
      exprOverlayPath = await _saveOverlayToFile(
        snapshot.expressionXai!.overlayImageBytes,
        'expr_overlay',
      );
    }

    if (snapshot.cryXai != null) {
      cryOverlayPath = await _saveOverlayToFile(
        snapshot.cryXai!.overlayImageBytes,
        'cry_overlay',
      );
    }

    // 3) Insert XAI insights using those overlay image paths
    if (poseOverlayPath != null) {
      await db.insert('report_xai_insights', {
        'reportId': reportId,
        'imagePath': poseOverlayPath,
        'title': 'Pose: ${snapshot.poseLabel}',
        'description': snapshot.poseXai!.explanation,
      });
    }

    if (exprOverlayPath != null) {
      await db.insert('report_xai_insights', {
        'reportId': reportId,
        'imagePath': exprOverlayPath,
        'title': 'Expression: ${snapshot.expressionLabel}',
        'description': snapshot.expressionXai!.explanation,
      });
    }

    if (cryOverlayPath != null) {
      await db.insert('report_xai_insights', {
        'reportId': reportId,
        'imagePath': cryOverlayPath,
        'title': 'Cry: ${snapshot.cryLabel}',
        'description': snapshot.cryXai!.explanation,
      });
    }

    // 4) Update in-memory list so UI refreshes immediately
    final list = List<AlertSnapshot>.from(_alerts.value);
    list.insert(
      0,
      AlertSnapshot(
        time: snapshot.time,
        riskLevel: snapshot.riskLevel,
        summary: snapshot.summary,
        poseXai: snapshot.poseXai,
        expressionXai: snapshot.expressionXai,
        cryXai: snapshot.cryXai,
        originalFrameFile: persistedFrameFile, 
        poseLabel: snapshot.poseLabel,
        expressionLabel: snapshot.expressionLabel,
        cryLabel: snapshot.cryLabel,
        storedInsights: snapshot.storedInsights,
        storedMetrics: snapshot.storedMetrics,
        reportLatencyMs: snapshot.reportLatencyMs, 
      ),
    );
    _alerts.value = list;
  }

  // LOAD: Hydrate reports from DB for the current user
  Future<void> loadForUser(int userId) async {
    final db = await DatabaseHelper.instance.database;

    final reportRows = await db.query(
      'reports',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
    );

    final List<AlertSnapshot> loaded = [];

    for (final row in reportRows) {
      final reportId = row['id'] as int;

      // Load XAI insights rows
      final insightRows = await db.query(
        'report_xai_insights',
        where: 'reportId = ?',
        whereArgs: [reportId],
      );

      final storedInsights = insightRows.map((ir) {
        return StoredInsight(
          imagePath: ir['imagePath'] as String,
          title: ir['title'] as String,
          description: ir['description'] as String,
        );
      }).toList();

      final poseLabel = (row['poseLabel'] as String?) ?? '';
      final exprLabel = (row['expressionLabel'] as String?) ?? '';
      final cryLabel = (row['cryLabel'] as String?) ?? '';

      final poseConf = row['poseConfidence'] as num?;
      final exprConf = row['expressionConfidence'] as num?;
      final cryConf = row['cryConfidence'] as num?;

      final metrics = <String, double>{};
      if (poseLabel.isNotEmpty && poseConf != null) {
        metrics['Pose: $poseLabel'] = poseConf.toDouble();
      }
      if (exprLabel.isNotEmpty && exprConf != null) {
        metrics['Expression: $exprLabel'] = exprConf.toDouble();
      }
      if (cryLabel.isNotEmpty && cryConf != null) {
        metrics['Cry: $cryLabel'] = cryConf.toDouble();
      }

      final snapshotPath = row['snapshotPath'] as String?;
      File frameFile;

      if (snapshotPath != null && snapshotPath.isNotEmpty) {
        final candidate = File(snapshotPath);
        if (await candidate.exists()) {
          frameFile = candidate;
        } else if (storedInsights.isNotEmpty) {
          frameFile = File(storedInsights.first.imagePath);
        } else {
          frameFile = File(''); // or handle with placeholder in UI
        }
      } else if (storedInsights.isNotEmpty) {
        frameFile = File(storedInsights.first.imagePath);
      } else {
        frameFile = File('');
      }


      final snap = AlertSnapshot(
        time: DateTime.parse(row['timestamp'] as String),
        riskLevel: (row['riskLevel'] as String?) ?? 'LOW',
        summary: (row['alertMessage'] as String?) ?? '',
        poseXai: null,
        expressionXai: null,
        cryXai: null,
        originalFrameFile: frameFile,
        poseLabel: poseLabel,
        expressionLabel: exprLabel,
        cryLabel: cryLabel,
        storedInsights: storedInsights,
        storedMetrics: metrics.isEmpty ? null : metrics,
        reportLatencyMs: row['reportLatencyMs'] as int?,
      );

      loaded.add(snap);
    }

    _alerts.value = loaded;
  }
}