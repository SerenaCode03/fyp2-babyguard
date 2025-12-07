// pages/report_page.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fyp2_babyguard/components/alert_card.dart';
import 'package:fyp2_babyguard/components/header_bar.dart';
import 'package:fyp2_babyguard/pages/report_details_page.dart';
import 'package:fyp2_babyguard/utilities/color.dart';
import 'package:fyp2_babyguard/components/report_components.dart';
import 'package:fyp2_babyguard/services/report_center.dart';

class ReportPage extends StatelessWidget {
  const ReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const HeaderBar(title: 'Report'),
        Expanded(
          child: ValueListenableBuilder<List<AlertSnapshot>>(
            valueListenable: ReportCenter.instance.alerts,
            builder: (context, alerts, _) {
              if (alerts.isEmpty) {
                return const Center(
                  child: Text(
                    'No risk alerts recorded yet.',
                    style: TextStyle(
                      color: black,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }

              final now = DateTime.now();

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: _buildAlertList(alerts, now, context),
              );
            },
          ),
        ),
      ],
    );
  }

  static AlertLevel _mapAlertLevel(String riskLevel) {
    switch (riskLevel.toUpperCase()) {
      case 'HIGH':
        return AlertLevel.high;
      case 'MODERATE':
        return AlertLevel.moderate;
      case 'LOW':
      default:
        return AlertLevel.low;
    }
  }

  static String _titleForRiskLevel(String riskLevel) {
    switch (riskLevel.toUpperCase()) {
      case 'HIGH':
        return 'High Risk Alert';
      case 'MODERATE':
        return 'Moderate Risk Alert';
      case 'LOW':
      default:
        return 'Low Risk Alert';
    }
  }

  void _openDetails(BuildContext context, AlertSnapshot snap) {
    final insights = <InsightItem>[];
    final metrics = <String, double>{};

    // CASE 1: Live (in-memory) XAI
    if (snap.poseXai != null) {
      // Pose insight (always)
      insights.add(
        InsightItem(
          image: MemoryImage(snap.poseXai!.overlayImageBytes),
          title: 'Sleeping pose insight',
          body: snap.poseXai!.explanation,
        ),
      );

      // Expression insight (optional)
      if (snap.expressionXai != null) {
        insights.add(
          InsightItem(
            image: MemoryImage(snap.expressionXai!.overlayImageBytes),
            title: 'Facial expression insight',
            body: snap.expressionXai!.explanation,
          ),
        );
      }

      // Cry insight (optional)
      if (snap.cryXai != null) {
        insights.add(
          InsightItem(
            image: MemoryImage(snap.cryXai!.overlayImageBytes),
            title: 'Cry pattern insight',
            body: snap.cryXai!.explanation,
          ),
        );
      }

      // Metrics from XaiResult confidences
      metrics['Pose: ${snap.poseLabel}'] = snap.poseXai!.confidence;
      if (snap.expressionXai != null) {
        metrics['Expression: ${snap.expressionLabel}'] =
            snap.expressionXai!.confidence;
      }
      if (snap.cryXai != null) {
        metrics['Cry: ${snap.cryLabel}'] = snap.cryXai!.confidence;
      }
    } else {
      // CASE 2: Loaded from database
      if (snap.storedInsights != null) {
        for (final si in snap.storedInsights!) {
          insights.add(
            InsightItem(
              image: FileImage(File(si.imagePath)),
              title: si.title,
              body: si.description,
            ),
          );
        }
      }

      if (snap.storedMetrics != null) {
        metrics.addAll(snap.storedMetrics!);
      }
    }

    final ts = _formatTime(snap.time);
    final riskUpper = snap.riskLevel.toUpperCase();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportDetailsPage(
          heroImage: FileImage(snap.originalFrameFile),
          timestamp: ts,
          alertTitle: _titleForRiskLevel(riskUpper),
          alertBody: snap.summary,
          riskLevel: riskUpper,
          insights: insights,
          metrics: metrics,
          combinedRisk: riskUpper,
          reportLatencyMs: snap.reportLatencyMs, 
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  List<Widget> _buildAlertList(
    List<AlertSnapshot> alerts,
    DateTime now,
    BuildContext context,
  ) {
    final List<Widget> children = [];
    DateTime? currentGroupDate;

    for (final snap in alerts) {
      final dateOfAlert = _dateOnly(snap.time);

      // New date group → add header
      if (currentGroupDate == null ||
          !_isSameCalendarDay(dateOfAlert, currentGroupDate!)) {
        currentGroupDate = dateOfAlert;
        children.add(_DateHeader(date: dateOfAlert, now: now));
        children.add(const SizedBox(height: 12));
      }

      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: AlertCard(
            alert: AlertItem(
              level: _mapAlertLevel(snap.riskLevel),
              title: _titleForRiskLevel(snap.riskLevel),
              time: snap.time,
              onTap: () => _openDetails(context, snap),
            ),
          ),
        ),
      );
    }

    return children;
  }
}

class _DateHeader extends StatelessWidget {
  final DateTime date; // group date (midnight)
  final DateTime now;

  const _DateHeader({
    required this.date,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      _fmt(date),
      style: const TextStyle(
        color: black,
        fontSize: 14,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
      ),
    );
  }

  String _fmt(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');

    final today = _dateOnly(now);
    final yesterday = today.subtract(const Duration(days: 1));

    if (_isSameCalendarDay(d, today)) {
      return 'TODAY $mm/$dd';
    } else if (_isSameCalendarDay(d, yesterday)) {
      return 'YESTERDAY $mm/$dd';
    } else {
      return '$mm/$dd';
    }
  }
}

bool _isSameCalendarDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime _dateOnly(DateTime dt) {
  return DateTime(dt.year, dt.month, dt.day);
}
