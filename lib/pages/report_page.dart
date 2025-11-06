import 'package:flutter/material.dart';
import 'package:fyp2_babyguard/components/alert_card.dart';
import 'package:fyp2_babyguard/components/header_bar.dart';
import 'package:fyp2_babyguard/pages/report_details_page.dart';
import 'package:fyp2_babyguard/utilities/color.dart';
import 'package:fyp2_babyguard/components/report_components.dart';


class ReportPage extends StatelessWidget {
  const ReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    final items = <AlertItem>[
      AlertItem(
        level: AlertLevel.high,
        title: 'High Risk Alert',
        time: DateTime(today.year, today.month, today.day, 11, 40),
        onTap: () {
          // TODO: navigate to alert details
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ReportDetailsPage(
                heroImage: AssetImage('assets/images/baby_preview.jpg'),
                timestamp: '11:40 AM',
                alertTitle: 'High Risk Alert',
                alertBody: 'Baby detected in prone position. Asphyxia cry is detected. Take action immediately!',
                riskLevel: 'HIGH',
                insights: [
                  InsightItem(
                    image: AssetImage('assets/images/gradcam1.png'),
                    title: 'Distressed face',
                    body: 'The model detected distress, focusing on the lower face and mouth, where discomfort cues typically appear.',
                  ),
                  InsightItem(
                    image: AssetImage('assets/images/gradcam1.png'),
                    title: 'Distressed face',
                    body: 'The model detected distress, focusing on the lower face and mouth, where discomfort cues typically appear.',
                  ),
                ],
                metrics: {
                  'Distressed face': 0.90,
                  'Abnormal Pose': 0.94,
                  'Asphyxia cry': 0.80,
                },
                combinedRisk: 'HIGH',
              ),
            ),
);

        },
      ),
      AlertItem(
        level: AlertLevel.moderate,
        title: 'Moderate Risk Alert',
        time: DateTime(today.year, today.month, today.day, 11, 40),
      ),
      AlertItem(
        level: AlertLevel.low,
        title: 'Low Risk Alert',
        time: DateTime(today.year, today.month, today.day, 11, 40),
      ),
    ];

    // Match SettingsPage structure: HeaderBar + Expanded scrollable content
    return Column(
      children: [
        const HeaderBar(title: 'Report'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _DateHeader(date: today),
              const SizedBox(height: 12),
              ...items.map(
                (a) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: AlertCard(alert: a),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DateHeader extends StatelessWidget {
  final DateTime date;
  const _DateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatLabel(date),
      style: const TextStyle(
        color: black,
        fontSize: 14,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
      ),
    );
  }

  String _formatLabel(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return 'TODAY $mm/$dd';
  }
}
