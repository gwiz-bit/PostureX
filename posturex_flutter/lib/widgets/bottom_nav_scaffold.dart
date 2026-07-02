import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../screens/home_screen.dart';
import '../screens/workout_screen.dart';
import '../screens/camera_screen.dart';
import '../screens/progress_screen.dart';
import '../screens/profile_screen.dart';

class BottomNavScaffold extends StatefulWidget {
  const BottomNavScaffold({super.key});

  @override
  State<BottomNavScaffold> createState() => _BottomNavScaffoldState();
}

class _BottomNavScaffoldState extends State<BottomNavScaffold> {
  int _currentIndex = 0;
  String _selectedExercise = 'Squat';

  void _openCamera(String exerciseName) {
    setState(() {
      _selectedExercise = exerciseName;
      _currentIndex = 2;
    });
  }

  void _goToTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        onOpenCamera: _openCamera,
        onOpenWorkout: () => _goToTab(1),
        onOpenProfile: () => _goToTab(4),
      ),
      WorkoutScreen(
        onOpenCamera: _openCamera,
        onOpenProfile: () => _goToTab(4),
      ),
      CameraScreen(
        key: ValueKey(_selectedExercise),
        exerciseName: _selectedExercise,
        onOpenProfile: () => _goToTab(4),
      ),
      ProgressScreen(onOpenProfile: () => _goToTab(4)),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _goToTab,
        backgroundColor: AppColors.surfaceAlt,
        selectedItemColor: AppColors.teal,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Trang chủ'),
          BottomNavigationBarItem(
              icon: Icon(Icons.fitness_center_outlined),
              activeIcon: Icon(Icons.fitness_center),
              label: 'Bài tập'),
          BottomNavigationBarItem(
              icon: Icon(Icons.camera_alt_outlined),
              activeIcon: Icon(Icons.camera_alt),
              label: 'Camera'),
          BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'Tiến trình'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Hồ sơ'),
        ],
      ),
    );
  }
}
