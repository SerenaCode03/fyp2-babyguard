import 'package:flutter/material.dart';
import 'package:fyp2_babyguard/components/header_bar.dart';
import 'package:fyp2_babyguard/components/notification_card.dart';
import 'package:fyp2_babyguard/utilities/color.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    // Sample data (swap with your real list)
    final items = <NotificationItem>[
      NotificationItem(
        kind: NoticeKind.alert,
        title: 'Alert: Asphyxia cry',
        time: DateTime(now.year, now.month, now.day, 11, 40),
        icon: Icons.graphic_eq_rounded,      // equalizer/wave
        tint: const Color(0xFFF0AD00),
      ),
      NotificationItem(
        kind: NoticeKind.alert,
        title: 'Alert: Abnormal posture',
        time: DateTime(now.year, now.month, now.day, 11, 40),
        icon: Icons.bed_rounded,             // bed icon
        tint: const Color(0xFFF0AD00),
      ),
      NotificationItem(
        kind: NoticeKind.alert,
        title: 'Alert: Distressed face',
        time: DateTime(now.year, now.month, now.day, 11, 40),
        icon: Icons.sentiment_dissatisfied_rounded,
        tint: const Color(0xFFF0AD00),
      ),
      NotificationItem(
        kind: NoticeKind.notice,
        title: 'Notice: Baby detected',
        time: DateTime(now.year, now.month, now.day, 11, 40),
        icon: Icons.child_care_rounded,
        tint: const Color(0xFF2ECC71),
      ),
    ];

    return Column(
      children: [
        const HeaderBar(title: 'Notifications'),
        Expanded(
          child: Container(
            color: const Color(0xFFE6EEFA), // light blue background like your mock
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _DateHeader(date: now),
                const SizedBox(height: 12),
                ...items.map(
                  (n) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: NotificationCard(item: n),
                  ),
                ),
              ],
            ),
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
    return 'TODAY $mm/$dd';
  }
}
