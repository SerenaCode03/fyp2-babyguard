import 'package:flutter/material.dart';
import 'package:fyp2_babyguard/utilities/color.dart';
import '../services/auth_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _answerCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _loadingQuestion = false;
  bool _resetting = false;
  String? _securityQuestion;   // loaded from DB
  bool _questionLoaded = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _answerCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Enter new password';
    if (v.length < 6) return 'Min 6 characters';
    return null;
  }

  Future<void> _loadQuestion() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email first')),
      );
      return;
    }

    setState(() {
      _loadingQuestion = true;
      _questionLoaded = false;
      _securityQuestion = null;
    });

    final question =
        await AuthService.instance.getSecurityQuestion(email); // from AuthService

    if (!mounted) return;

    setState(() {
      _loadingQuestion = false;
      if (question != null) {
        _securityQuestion = question;
        _questionLoaded = true;
      } else {
        _questionLoaded = false;
      }
    });

    if (question == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No account found for this email')),
      );
    }
  }

  Future<void> _handleReset() async {
    if (!_questionLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Load your security question first')),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_answerCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your security answer')),
      );
      return;
    }

    setState(() => _resetting = true);

    final email = _emailCtrl.text.trim();
    final answer = _answerCtrl.text.trim();
    final newPassword = _newPassCtrl.text;

    final success = await AuthService.instance.resetPasswordWithSecurityAnswer(
      email: email,
      answer: answer,
      newPassword: newPassword,
    );

    if (!mounted) return;

    setState(() => _resetting = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect security answer')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password reset successfully. Please log in.')),
    );

    Navigator.pop(context); // back to login
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: white,
      appBar: AppBar(
        title: const Text('Forgot Password'),
        backgroundColor: white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: black,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reset your password',
                  style: TextStyle(
                    color: black,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Enter your registered email. We’ll show you the security question you chose during sign up.',
                  style: TextStyle(
                    color: black.withOpacity(0.8),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 28),

                // Email input
                Container(
                  decoration: BoxDecoration(
                    color: gray,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) return 'Enter your email';
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                    style: const TextStyle(
                      color: black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      icon: Icon(Icons.alternate_email, color: black.withOpacity(0.7)),
                      hintText: 'Email',
                      hintStyle: TextStyle(
                        color: black.withOpacity(0.6),
                        fontWeight: FontWeight.w600,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _loadingQuestion ? null : _loadQuestion,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: darkBlue.withOpacity(0.7)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      _loadingQuestion ? 'Loading question...' : 'Get security question',
                      style: TextStyle(
                        color: darkBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                if (_questionLoaded && _securityQuestion != null) ...[
                  const Text(
                    'Security Question',
                    style: TextStyle(
                      color: black,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: gray,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _securityQuestion!,
                      style: const TextStyle(
                        color: black,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Answer field
                  Container(
                    decoration: BoxDecoration(
                      color: gray,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextFormField(
                      controller: _answerCtrl,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Enter your answer';
                        }
                        return null;
                      },
                      style: const TextStyle(
                        color: black,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        icon: Icon(Icons.question_answer_outlined,
                            color: black.withOpacity(0.7)),
                        hintText: 'Your answer',
                        hintStyle: TextStyle(
                          color: black.withOpacity(0.6),
                          fontWeight: FontWeight.w600,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // New password
                  Container(
                    decoration: BoxDecoration(
                      color: gray,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextFormField(
                      controller: _newPassCtrl,
                      obscureText: true,
                      validator: _validatePassword,
                      style: const TextStyle(
                        color: black,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        icon: Icon(Icons.lock_outline_rounded,
                            color: black.withOpacity(0.7)),
                        hintText: 'New password',
                        hintStyle: TextStyle(
                          color: black.withOpacity(0.6),
                          fontWeight: FontWeight.w600,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Confirm password
                  Container(
                    decoration: BoxDecoration(
                      color: gray,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextFormField(
                      controller: _confirmPassCtrl,
                      obscureText: true,
                      validator: (v) {
                        final base = _validatePassword(v);
                        if (base != null) return base;
                        if (v != _newPassCtrl.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                      style: const TextStyle(
                        color: black,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        icon: Icon(Icons.lock_outline_rounded,
                            color: black.withOpacity(0.7)),
                        hintText: 'Confirm new password',
                        hintStyle: TextStyle(
                          color: black.withOpacity(0.6),
                          fontWeight: FontWeight.w600,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Reset button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _resetting ? null : _handleReset,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: darkBlue,
                        foregroundColor: white,
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        _resetting ? 'Resetting...' : 'Reset password',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
