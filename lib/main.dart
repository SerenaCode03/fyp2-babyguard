import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fyp2_babyguard/pages/forgot_password_page.dart';
import 'package:fyp2_babyguard/pages/home_page.dart';
import 'package:fyp2_babyguard/pages/sign_up_page.dart';
import 'package:fyp2_babyguard/utilities/color.dart';
import 'package:fyp2_babyguard/pages/login_page.dart';
import 'package:fyp2_babyguard/pages/landing_page.dart'; // add this

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock app to portrait by default
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BabyGuard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: black,
          background: white,
        ),
      ),
      initialRoute: '/landing',
      routes: {
        '/landing': (context) => const LandingPage(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/forgot': (context) => const ForgotPasswordPage(),
        '/home':    (context) => const HomePage(), 
      },
    );
  }
}
