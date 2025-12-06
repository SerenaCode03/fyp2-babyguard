import 'package:flutter/material.dart';
import 'package:fyp2_babyguard/utilities/color.dart';
import '../services/auth_service.dart';
import '../services/session_manager.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();

  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _secAnswerCtrl = TextEditingController();

  final List<String> _questions = [
    'What is your mother\'s maiden name?',
    'What was your first pet\'s name?',
    'What is the name of the town you were born in?',
    'What is your favorite childhood food?',
  ];
  String? _selectedQuestion;

  @override
  void initState() {
    super.initState();
    _selectedQuestion = _questions.first;
  }

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false; 

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _secAnswerCtrl.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Enter email';
    final emailReg =
        RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,}$'); // simple check
    if (!emailReg.hasMatch(v.trim())) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Enter password';
    if (v.length < 6) return 'Min 6 characters';
    return null;
  }

  void _submit() async {
    if (_isSubmitting) return;

    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_selectedQuestion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a security question')),
      );
      return;
    }

    if (_secAnswerCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an answer')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final email = _emailCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;
    final question = _selectedQuestion!;
    final answer = _secAnswerCtrl.text.trim();

    final userId = await AuthService.instance.signUp(
      email: email,
      username: username,
      password: password,
      securityQuestion: question,
      securityAnswer: answer,
    );

    // widget might have been disposed while awaiting
    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email is already registered')),
      );
      return;
    }

    SessionManager.login(userId, email, username);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account created successfully')),
    );

    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Let's get started!",
                  style: TextStyle(
                    color: black,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Sign up to continue',
                  style: TextStyle(
                    color: black.withOpacity(0.85),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 28),

                _InputBox(
                  controller: _usernameCtrl,
                  hint: 'Username',
                  icon: Icons.person_2_outlined,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter username' : null,
                ),
                const SizedBox(height: 20),

                _InputBox(
                  controller: _emailCtrl,
                  hint: 'Email',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 20),

                _InputBox(
                  controller: _passwordCtrl,
                  hint: 'Password',
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscurePass,
                  trailing: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                    icon: Icon(
                      _obscurePass ? Icons.visibility_off : Icons.visibility,
                      color: black.withOpacity(0.55),
                    ),
                  ),
                  validator: _validatePassword,
                ),
                const SizedBox(height: 20),

                _InputBox(
                  controller: _confirmCtrl,
                  hint: 'Confirm password',
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscureConfirm,
                  trailing: IconButton(
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                      color: black.withOpacity(0.55),
                    ),
                  ),
                  validator: (v) {
                    final base = _validatePassword(v);
                    if (base != null) return base;
                    if (v != _passwordCtrl.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),
                const Text(
                  'Security Question',
                  style: TextStyle(
                    color: black,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),

                // Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: gray,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: DropdownButtonFormField<String>(
                    isExpanded: true, // 
                    value: _selectedQuestion,
                    items: _questions.map((q) {
                      return DropdownMenuItem<String>(
                        value: q,
                        child: SizedBox(
                          width: double.infinity, 
                          child: Text(
                            q,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis, // or remove to allow full wrap
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: black,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedQuestion = value);
                    },
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                    ),
                    validator: (v) =>
                        v == null ? 'Please select a security question' : null,
                  ),
                ),

                const SizedBox(height: 20),

                // Security Answer input
                _InputBox(
                  controller: _secAnswerCtrl,
                  hint: 'Your answer',
                  icon: Icons.question_answer_outlined,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter your answer' : null,
                ),

                const SizedBox(height: 40),

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
                    onPressed: _submit,
                    child: const Text(
                      'Sign up',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account?  ',
                      style: TextStyle(
                        color: black.withOpacity(0.8),
                        fontSize: 14.5,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Go to Login page
                        Navigator.pushNamed(context, '/login');
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Login',
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
        color: gray,          // matches mockup field background
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
