// pages/report_details_page.dart
import 'package:flutter/material.dart';
import 'package:fyp2_babyguard/utilities/color.dart';
import 'package:fyp2_babyguard/components/header_bar.dart';
import 'package:fyp2_babyguard/components/report_components.dart';

class ReportDetailsPage extends StatelessWidget {
  const ReportDetailsPage({
    super.key,
    required this.heroImage,
    required this.timestamp,
    required this.alertTitle,
    required this.alertBody,
    required this.riskLevel,
    required this.insights,
    required this.metrics,
    required this.combinedRisk,
  });

  final ImageProvider heroImage;
  final String timestamp;
  final String alertTitle;
  final String alertBody;
  final String riskLevel; // "HIGH" | "MEDIUM" | "LOW"
  final List<InsightItem> insights;
  final Map<String, double> metrics;
  final String combinedRisk;

  Color _riskColor(String level) {
    switch (level.toUpperCase()) {
      case 'HIGH':
        return const Color(0xFFE84D3C);
      case 'MEDIUM':
        return const Color(0xFFF4A261);
      case 'LOW':
        return const Color(0xFF2A9D8F);
      default:
        return darkBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF1FF),
      appBar: HeaderBar(
        title: 'Report',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image(image: heroImage, fit: BoxFit.cover, filterQuality: FilterQuality.high),
                    Container(color: Colors.black12),
                    const Center(child: Icon(Icons.play_circle_fill_rounded, size: 60, color: Colors.white)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            AlertDetailCard(
              title: alertTitle,
              body: alertBody,
              timestamp: timestamp,
              icon: const Icon(Icons.report_gmailerrorred_rounded, color: Colors.white, size: 22),
              badgeColor: _riskColor(riskLevel),
            ),

            const SizedBox(height: 18),
            const SectionTitle('Explainable AI insights'),

            ...insights.map((i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InsightCard(image: i.image, title: i.title, body: i.body),
                )),

            const SizedBox(height: 6),
            const SectionTitle('Risk Assessment Summary'),

            SummaryCard(metrics: metrics),

            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TagCard(
                    label: 'Combined risk assessment',
                    trailing: RiskTag(text: combinedRisk, color: _riskColor(combinedRisk)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
