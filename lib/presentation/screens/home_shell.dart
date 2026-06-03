import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import '../widgets/animated_bottom_nav.dart';
import '../widgets/onboarding_tooltip.dart';
import 'home_screen.dart';
import 'diary_screen.dart';
import 'snap_screen.dart';
import 'progress_screen.dart';
import 'settings_screen.dart';
import '../../core/theme/theme_colors.dart';

/// Shell widget that hosts the bottom navigation and switches between tabs
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  bool _showTooltips = false;

  final _screens = const [
    HomeScreen(),
    DiaryScreen(),
    SnapScreen(),
    ProgressScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _checkTooltips();
  }

  Future<void> _checkTooltips() async {
    final shouldShow = await OnboardingTooltip.shouldShow();
    if (shouldShow && mounted) {
      setState(() => _showTooltips = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: C.of(context).bg,
          appBar: _currentIndex == 2
              ? null
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
          floatingActionButton: _currentIndex != 2
              ? FloatingActionButton(
                  onPressed: () => setState(() => _currentIndex = 2),
                  backgroundColor: AppColors.accentGreen,
                  child: Icon(Icons.camera_alt_rounded,
                      color: C.of(context).bg),
                )
                    .animate(
                      onPlay: (controller) =>
                          controller.repeat(reverse: true),
                    )
                    .scale(
                      begin: const Offset(1.0, 1.0),
                      end: const Offset(1.08, 1.08),
                      duration: 1200.ms,
                    )
              : null,
        ),
        // Onboarding tooltips overlay
        if (_showTooltips)
          TooltipOverlay(
            onDismiss: () => setState(() => _showTooltips = false),
          ),
      ],
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
