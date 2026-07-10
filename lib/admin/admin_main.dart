import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../screens/login_screen.dart';

void main() => runApp(const PostureXAdminApp());

class PostureXAdminApp extends StatelessWidget {
  const PostureXAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PostureX Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const LoginScreen(),
    );
  }
}
