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
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    children: _buildNotificationList(items, now),
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

List<Widget> _buildNotificationList(
  List<NotificationItem> items,
  DateTime now,
) {
  final List<Widget> children = [];
  DateTime? currentGroupDate;

  for (final n in items) {
    // Use only Y/M/D, ignore time of day
    final dateOfItem = _dateOnly(n.time);

    if (currentGroupDate == null ||
        !_isSameCalendarDay(dateOfItem, currentGroupDate!)) {
      // New date group → add a header
      currentGroupDate = dateOfItem;
      children.add(_DateHeader(date: dateOfItem, now: now));
      children.add(const SizedBox(height: 12));
    }

    children.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: NotificationCard(item: n),
      ),
    );
  }

  return children;
}


class _DateHeader extends StatelessWidget {
  final DateTime date;   // this is the date of the group
  final DateTime now;    // current time so we can compare

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
