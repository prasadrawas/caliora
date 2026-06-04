import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/animated_bottom_nav.dart';
import '../widgets/onboarding_tooltip.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';
import 'diary_screen.dart';
import 'snap_screen.dart';
import 'barcode_screen.dart';
import 'progress_screen.dart';
import 'settings_screen.dart';

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
    _checkFirstVisit();
  }

  Future<void> _checkFirstVisit() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingSeen = prefs.getBool('onboarding_seen') ?? false;

    if (!onboardingSeen && mounted) {
      await prefs.setBool('onboarding_seen', true);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    }

    if (!mounted) return;
    final shouldShowTooltips = await OnboardingTooltip.shouldShow();
    if (shouldShowTooltips && mounted) {
      setState(() => _showTooltips = true);
    }
  }

  void _showLogMenu() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: BoxDecoration(
          color: C.of(context).bg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: C.of(context).text30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Log a Meal',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: C.of(context).text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose how you want to log',
              style: TextStyle(
                fontSize: 13,
                color: C.of(context).text30,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _menuOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Take Photo',
                  color: AppColors.accentGreen,
                  onTap: () {
                    Navigator.pop(context);
                    _openSnap(ImageSource.camera);
                  },
                ),
                const SizedBox(width: 12),
                _menuOption(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  color: AppColors.protein,
                  onTap: () {
                    Navigator.pop(context);
                    _openSnap(ImageSource.gallery);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _menuOption(
                  icon: Icons.qr_code_scanner,
                  label: 'Barcode',
                  color: AppColors.carbs,
                  onTap: () {
                    Navigator.pop(context);
                    _openBarcode();
                  },
                ),
                const SizedBox(width: 12),
                _menuOption(
                  icon: Icons.edit_note_rounded,
                  label: 'Manual Entry',
                  color: AppColors.fat,
                  onTap: () {
                    Navigator.pop(context);
                    _openManual();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSnap(ImageSource source) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SnapScreen(initialSource: source),
      ),
    );
  }

  void _openBarcode() {
    Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScreen()),
    ).then((barcode) {
      if (barcode != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SnapScreen(initialBarcode: barcode),
          ),
        );
      }
    });
  }

  void _openManual() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SnapScreen(initialManual: true),
      ),
    );
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
                  title: _currentIndex == 0
                      ? Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(text: 'Bite'),
                              TextSpan(
                                text: 'Bloom',
                                style: TextStyle(
                                    color: AppColors.accentGreen),
                              ),
                            ],
                          ),
                        )
                      : Text(_titles[_currentIndex]),
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
          floatingActionButton: _currentIndex == 2 ? null : FloatingActionButton(
            onPressed: _showLogMenu,
            backgroundColor: AppColors.accentGreen,
            child: Icon(Icons.camera_alt_rounded, color: C.of(context).bg, size: 26),
          )
              .animate(
                onPlay: (controller) => controller.repeat(reverse: true),
              )
              .scale(
                begin: const Offset(1.0, 1.0),
                end: const Offset(1.06, 1.06),
                duration: 1200.ms,
              ),
        ),
        if (_showTooltips)
          TooltipOverlay(
            onDismiss: () => setState(() => _showTooltips = false),
          ),
      ],
    );
  }

  static const _titles = [
    'BiteBloom',
    'Food Diary',
    'Snap',
    'Progress',
    'Settings',
  ];
}
