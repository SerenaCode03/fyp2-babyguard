import 'package:flutter/material.dart';
import 'package:fyp2_babyguard/utilities/color.dart';
import 'package:fyp2_babyguard/pages/login_page.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BabyGuard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter', // optional, falls back to default if not added
        colorScheme: ColorScheme.fromSeed(
          seedColor: black, // dark navy
          background: backgroundWhite, // warm off-white
        ),
      ),
      home: const LandingPage(),
    );
  }
}

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isSmall = media.size.height < 750;

    return Scaffold(
      backgroundColor: backgroundWhite,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(35),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 55,),
                  // Title
                  const Text(
                    'BabyGuard',
                    style: TextStyle(
                      color: black,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 17),
                  // Subtitle with bold emphasis on “infant monitoring”
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: black.withOpacity(0.85),
                        fontSize: 18,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                      children: const [
                        TextSpan(text: 'Your trusted companion for '),
                        TextSpan(
                          text: 'infant monitoring',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  
                  // Illustration
                 Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          // keep ~20px padding visually and avoid overflow
                          maxWidth: media.size.width - 40,
                          // take nearly half the screen height; tweak as you like
                          maxHeight: media.size.height * 0.5,
                        ),
                        child: Image.asset(
                          'assets/images/landing_page_image.png',
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                ],
              ),
            ),

            // Bottom-right circular “Get Started” arrow
            Positioned(
              right: 24,
              bottom: 40 + media.padding.bottom,
              child: _StartButton(
                onTap: () {
                  debugPrint('Get Started tapped');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StartButton extends StatefulWidget {
  const _StartButton({required this.onTap, super.key});
  final VoidCallback onTap;

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: _isPressed
              ? darkBlue.withOpacity(0.8) // slightly lighter/darker when pressed
              : darkBlue,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: darkBlue.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(
          Icons.arrow_forward_rounded,
          color: white,
          size: 28,
        ),
      ),
    );
  }
}
