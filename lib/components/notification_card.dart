import 'package:flutter/material.dart';
import 'package:fyp2_babyguard/utilities/color.dart'; // expects black/white/gray

enum NoticeKind { alert, notice }

class NotificationItem {
  final NoticeKind kind;        // alert vs notice (styling)
  final String title;           // e.g., "Alert: Asphyxia cry detected"
  final DateTime time;          // timestamp
  final IconData icon;          // leading icon
  final Color tint;             // icon + chip tint color
  final VoidCallback? onTap;

  NotificationItem({
    required this.kind,
    required this.title,
    required this.time,
    required this.icon,
    required this.tint,
    this.onTap,
  });
}

class NotificationCard extends StatelessWidget {
  const NotificationCard({super.key, required this.item});
  final NotificationItem item;

  @override
  Widget build(BuildContext context) {
    final bool isAlert = item.kind == NoticeKind.alert;

    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Leading rounded chip
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.tint.withOpacity(0.20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, size: 26, color: item.tint),
            ),
            const SizedBox(width: 12),

            // Title + time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isAlert ? Colors.black : Colors.black87,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(item.time),
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.55),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),
            // const Icon(Icons.chevron_right_rounded, color: Colors.black54),
          ],
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
}
