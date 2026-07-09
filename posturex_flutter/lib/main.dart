import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'widgets/bottom_nav_scaffold.dart';

void main() {
  runApp(const PostureXApp());
}

class PostureXApp extends StatelessWidget {
  const PostureXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PostureX',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const BottomNavScaffold(),
    );
  }
}
