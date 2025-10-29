import 'package:flutter/material.dart';
import 'package:fyp2_babyguard/pages/notification_page.dart';
import 'package:fyp2_babyguard/pages/report_page.dart';
import 'package:fyp2_babyguard/utilities/color.dart';
import 'package:fyp2_babyguard/pages/setting_page.dart';
import 'package:fyp2_babyguard/components/bottom_nav_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  final List<Widget> _pages = <Widget>[
    const _HomeContent(),
    const ReportPage(),
    const NotificationPage(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: backgroundWhite,
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          SafeArea(
            child: IndexedStack(
              index: _index,
              children: _pages,
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 40 + bottomInset,
            child: BottomNavBar(
              currentIndex: _index,
              onTap: (i) => setState(() => _index = i),
            ),
          ),
        ],
      ),
    );
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome back,\nSerena!',
            style: TextStyle(
              color: black,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 20),

          // CAMERA SECTION
          Container(
            decoration: BoxDecoration(
              color: white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Camera',
                  style: TextStyle(
                    color: black,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/baby_preview.jpg', // replace with your camera widget later
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),

                // CAMERA + MIC BUTTONS
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _circleButton(Icons.camera_alt_rounded),
                    const SizedBox(width: 40),
                    _circleButton(Icons.mic_rounded),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // START / STOP BUTTONS
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0C1C4B), // dark navy
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              minimumSize: const Size(double.infinity, 65),
            ),
            child: const Text(
              'Start Monitoring',
              style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 16),

          // Stop Monitoring Button (white with shadow)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.transparent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                minimumSize: const Size(double.infinity, 65),
                backgroundColor: Colors.white,
              ),
              child: const Text(
                'Stop Monitoring',
                style: TextStyle(fontSize: 18, color: black, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // helper for circle icon buttons with border
  static Widget _circleButton(IconData icon) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black26, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, size: 28, color: Colors.black87),
    );
  }
}
