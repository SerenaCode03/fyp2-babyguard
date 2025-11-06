import 'package:flutter/material.dart';
import 'package:fyp2_babyguard/utilities/color.dart';

/* ----------------------------- Reusable pieces ---------------------------- */

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: black,
          fontSize: 16.5,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.child, this.padding, this.color});
  final Widget child;
  final EdgeInsets? padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color ?? backgroundWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class AlertDetailCard extends StatelessWidget {
  const AlertDetailCard({
    super.key,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.icon,
    required this.badgeColor,
  });

  final String title;
  final String body;
  final String timestamp;
  final Widget icon;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      color: white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(10)),
            child: Center(child: icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: badgeColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5,
                          height: 1.2,
                        ),
                      ),
                    ),
                    Text(
                      timestamp,
                      style: TextStyle(color: black.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(
                    color: black.withOpacity(0.85),
                    fontSize: 13.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class InsightCard extends StatelessWidget {
  const InsightCard({
    super.key,
    required this.image,
    required this.title,
    required this.body,
  });

  final ImageProvider image;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      color: white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image(
              image: image,
              width: 68,
              height: 68,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: black),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    color: black.withOpacity(0.85),
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key, required this.metrics});
  final Map<String, double> metrics;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      color: white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Confidence Value:',
            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: black),
          ),
          const SizedBox(height: 10),
          ...metrics.entries.map((e) => _bullet('${e.key}: ${(e.value * 100).toStringAsFixed(0)}%')),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 14, height: 1.35, color: black)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.35, color: black, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class TagCard extends StatelessWidget {
  const TagCard({super.key, required this.label, required this.trailing});
  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      color: white,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: black.withOpacity(0.8), fontWeight: FontWeight.w800),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class RiskTag extends StatelessWidget {
  const RiskTag({super.key, required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.7), width: 1),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/* --------------------------------- Models -------------------------------- */

class InsightItem {
  final ImageProvider image;
  final String title;
  final String body;
  const InsightItem({required this.image, required this.title, required this.body});
}
