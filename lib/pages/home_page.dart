import 'package:flutter/material.dart';
import 'package:fyp2_babyguard/utilities/color.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: backgroundWhite,
      body: Stack(
        children: [
          // Page content
          SafeArea(
            child: Padding(
              // add extra bottom padding so content isn't hidden by the floating bar
              padding: const EdgeInsets.fromLTRB(24, 35, 24, 120),
              child: _buildBody(),
            ),
          ),

          // Floating bottom nav bar
          Positioned(
            left: 12,
            right: 12,
            bottom: 40 + bottomInset, // lift it up; tweak 40 as you like
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: black.withOpacity(0.12),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 6), // soft shadow below the bar
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _NavItem(
                    icon: Icons.home_rounded,
                    isActive: _index == 0,
                    onTap: () => setState(() => _index = 0),
                  ),
                  _NavItem(
                    icon: Icons.assignment_rounded, // records/logs
                    isActive: _index == 1,
                    onTap: () => setState(() => _index = 1),
                  ),
                  _NavItem(
                    icon: Icons.notifications_none_rounded,
                    isActive: _index == 2,
                    onTap: () => setState(() => _index = 2),
                  ),
                  _NavItem(
                    icon: Icons.settings_rounded,
                    isActive: _index == 3,
                    onTap: () => setState(() => _index = 3),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Restored body builder with tabs
  Widget _buildBody() {
    switch (_index) {
      case 0:
        return const _HomeContent();
      case 1:
        return const Center(child: Text('Records / Logs', style: _kSectionStyle));
      case 2:
        return const Center(child: Text('Notifications', style: _kSectionStyle));
      case 3:
        return const Center(child: Text('Settings', style: _kSectionStyle));
      default:
        return const _HomeContent();
    }
  }
}

const _kSectionStyle = TextStyle(
  color: black,
  fontSize: 20,
  fontWeight: FontWeight.w700,
);

class _HomeContent extends StatelessWidget {
  const _HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          'Welcome back,\nSerena!',
          style: TextStyle(
            color: black,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.25,
          ),
        ),
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
