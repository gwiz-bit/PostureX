import 'package:flutter/material.dart';

import 'screens/main_shell.dart';
import 'theme/app_theme.dart';

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
      home: const MainShell(),
    );
  }
}
