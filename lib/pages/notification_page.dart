//pages/notification_page.dart
import 'package:flutter/material.dart';
import 'package:fyp2_babyguard/components/header_bar.dart';
import 'package:fyp2_babyguard/components/notification_card.dart';
import 'package:fyp2_babyguard/utilities/color.dart';
import 'package:fyp2_babyguard/services/notification_center.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return SafeArea( 
      child: Column(
        children: [
          const HeaderBar(title: 'Notifications'),

          Expanded(
            child: Container(
              color: const Color(0xFFE6EEFA),

              child: ValueListenableBuilder<List<NotificationItem>>(
                valueListenable: NotificationCenter.instance.items,
                builder: (context, items, _) {
                  if (items.isEmpty) {
                    return const Center(
                      child: Text(
                        'No notifications yet',
                        style: TextStyle(color: black),
                      ),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16,16,16,16),
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
                  );
                },
              ),
            ),
          ),
        ],
      ),
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

