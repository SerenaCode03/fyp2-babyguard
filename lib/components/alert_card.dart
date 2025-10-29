import 'package:flutter/material.dart';
import 'package:fyp2_babyguard/utilities/color.dart'; // expects black/white/gray

enum AlertLevel { high, moderate, low }

class AlertItem {
  final AlertLevel level;
  final String title;
  final DateTime time;
  final VoidCallback? onTap;

  AlertItem({
    required this.level,
    required this.title,
    required this.time,
    this.onTap,
  });
}

class AlertCard extends StatelessWidget {
  final AlertItem alert;
  const AlertCard({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(alert.level);

    return InkWell(
      onTap: alert.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: style.chipBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(style.icon, color: style.chipIcon, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: style.titleColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(alert.time),
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
            const Icon(Icons.chevron_right_rounded, color: Colors.black54),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  _AlertStyle _styleFor(AlertLevel level) {
    switch (level) {
      case AlertLevel.high:
        return const _AlertStyle(
          chipBg: Color(0xFFFFE5E5),
          chipIcon: Color(0xFFE74C3C),
          titleColor: Color(0xFFE74C3C),
          icon: Icons.error_rounded,
        );
      case AlertLevel.moderate:
        return const _AlertStyle(
          chipBg: Color(0xFFFFF3D6),
          chipIcon: Color(0xFFF0AD00),
          titleColor: Color(0xFFCC8A00),
          icon: Icons.warning_amber_rounded,
        );
      case AlertLevel.low:
        return const _AlertStyle(
          chipBg: Color(0xFFEAF8EE),
          chipIcon: Color(0xFF2ECC71),
          titleColor: Color(0xFF2EAF5E),
          icon: Icons.check_circle_rounded,
        );
    }
  }
}

class _AlertStyle {
  final Color chipBg;
  final Color chipIcon;
  final Color titleColor;
  final IconData icon;
  const _AlertStyle({
    required this.chipBg,
    required this.chipIcon,
    required this.titleColor,
    required this.icon,
  });
}