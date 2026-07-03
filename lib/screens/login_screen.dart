import 'package:flutter/material.dart';

import '../models/user_session.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/or_divider.dart';
import 'main_shell.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  void _goToRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  void _continueWithGoogle() {
    UserSession.signInWithGoogle();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primaryMuted,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.fitness_center_rounded, color: AppColors.primary, size: 28),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Welcome back',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Log in to continue your posture journey',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 36),
              AuthTextField(
                label: 'Email',
                hint: 'you@example.com',
                icon: Icons.mail_outline_rounded,
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Enter your email';
                  if (!value.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 18),
              AuthTextField(
                label: 'Password',
                hint: 'Enter your password',
                icon: Icons.lock_outline_rounded,
                controller: _passwordController,
                isPassword: true,
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter your password';
                  if (value.length < 6) return 'At least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Log in',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const OrDivider(),
              const SizedBox(height: 24),
              GoogleSignInButton(onPressed: _continueWithGoogle),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: _goToRegister,
                    child: const Text(
                      'Sign up',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
