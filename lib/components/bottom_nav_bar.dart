import 'package:flutter/material.dart';
import 'package:fyp2_babyguard/utilities/color.dart';

typedef OnNavTap = void Function(int index);

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final OnNavTap onTap;

  @override
  Widget build(BuildContext context) {
    // DO NOT use Positioned here — let the parent position it.
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: black.withOpacity(0.12),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _NavItem(icon: Icons.home_rounded, isActive: currentIndex == 0, onTap: () => onTap(0)),
          _NavItem(icon: Icons.assignment_rounded, isActive: currentIndex == 1, onTap: () => onTap(1)),
          _NavItem(icon: Icons.notifications_none_rounded, isActive: currentIndex == 2, onTap: () => onTap(2)),
          _NavItem(icon: Icons.settings_rounded, isActive: currentIndex == 3, onTap: () => onTap(3)),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 56,
        height: 44,
        decoration: BoxDecoration(
          color: isActive ? middleBlue.withOpacity(0.6) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          size: 26,
          color: isActive ? darkBlue : black.withOpacity(0.85),
        ),
      ),
    );
  }
}