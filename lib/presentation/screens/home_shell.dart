import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import '../widgets/animated_bottom_nav.dart';
import 'home_screen.dart';
import 'diary_screen.dart';
import 'snap_screen.dart';
import 'progress_screen.dart';
import 'settings_screen.dart';

/// Shell widget that hosts the bottom navigation and switches between tabs
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  final _screens = const [
    HomeScreen(),
    DiaryScreen(),
    SnapScreen(),
    ProgressScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _currentIndex == 2
          ? null // Snap screen has its own layout
          : AppBar(
              title: Text(_titles[_currentIndex]),
              automaticallyImplyLeading: false,
            ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: AnimatedBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
      // Floating action button for quick snap access (visible on non-snap tabs)
      floatingActionButton: _currentIndex != 2
          ? FloatingActionButton(
              onPressed: () => setState(() => _currentIndex = 2),
              backgroundColor: AppColors.accentGreen,
              child: const Icon(Icons.camera_alt_rounded,
                  color: AppColors.background),
            )
              .animate(
                onPlay: (controller) => controller.repeat(reverse: true),
              )
              .scale(
                begin: const Offset(1.0, 1.0),
                end: const Offset(1.08, 1.08),
                duration: 1200.ms,
              )
          : null,
    );
  }

  static const _titles = [
    'Caliora',
    'Food Diary',
    'Snap',
    'Progress',
    'Settings',
  ];
}
