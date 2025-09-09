import 'package:flutter/material.dart';
import 'package:fyp2_babyguard/pages/home_page.dart';
import 'package:fyp2_babyguard/pages/sign_up_page.dart';
import 'package:fyp2_babyguard/utilities/color.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 140, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                const Text(
                  'Welcome back !',
                  style: TextStyle(
                    color: black,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  'Log in to continue',
                  style: TextStyle(
                    color: black.withOpacity(0.85),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 35),

                // Username
                _InputBox(
                  controller: _userCtrl,
                  hint: 'Username',
                  icon: Icons.person_2_outlined,
                  keyboardType: TextInputType.text,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter username' : null,
                ),
                const SizedBox(height: 22),

                // Password
                _InputBox(
                  controller: _passCtrl,
                  hint: 'Password',
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscure,
                  trailing: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      color: black.withOpacity(0.55),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Enter password' : null,
                ),

                const SizedBox(height: 45),

                // Login button
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: darkBlue,
                      foregroundColor: white,
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        // TODO: handle real login
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Logging in…')),
                        );
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const HomePage()),
                        );
                      }
                    },
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Sign up
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don’t have an account yet?  ",
                      style: TextStyle(
                        color: black.withOpacity(0.8),
                        fontSize: 14.5,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // TODO: push to Sign up page
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SignUpPage()),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Sign up',
                        style: TextStyle(
                          color: black,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InputBox extends StatelessWidget {
  const _InputBox({
    required this.controller,
    required this.hint,
    required this.icon,
    this.trailing,
    this.obscure = false,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final Widget? trailing;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: lightBlue, // soft light input background
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(
          color: black,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          icon: Icon(icon, color: black.withOpacity(0.7)),
          hintText: hint,
          hintStyle: TextStyle(
            color: black.withOpacity(0.6),
            fontWeight: FontWeight.w600,
          ),
          border: InputBorder.none,
          suffixIcon: trailing,
        ),
      ),
    );
  }
}
