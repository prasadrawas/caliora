import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_colors.dart';

class OnboardingTooltip {
  static const _prefKey = 'onboarding_tooltips_shown';

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_prefKey) ?? false);
  }

  static Future<void> markShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }
}

class TooltipOverlay extends StatefulWidget {
  final VoidCallback onDismiss;

  const TooltipOverlay({super.key, required this.onDismiss});

  @override
  State<TooltipOverlay> createState() => _TooltipOverlayState();
}

class _TooltipOverlayState extends State<TooltipOverlay> {
  int _currentTip = 0;

  static const _tips = [
    _Tip(
      icon: Icons.camera_alt_rounded,
      title: 'Snap Your Meal',
      description: 'Tap the camera button to take a photo and let AI analyze your meal\'s nutrition.',
      color: AppColors.accentGreen,
    ),
    _Tip(
      icon: Icons.qr_code_scanner,
      title: 'Scan Barcodes',
      description: 'Scan packaged food barcodes for instant and accurate nutrition data.',
      color: AppColors.protein,
    ),
    _Tip(
      icon: Icons.swipe_left,
      title: 'Swipe to Delete',
      description: 'Swipe any meal card left in the diary to delete it. You can undo within 4 seconds.',
      color: AppColors.error,
    ),
    _Tip(
      icon: Icons.touch_app,
      title: 'Tap to Edit',
      description: 'Tap on any logged meal in the diary to edit its nutrition details.',
      color: AppColors.carbs,
    ),
    _Tip(
      icon: Icons.water_drop,
      title: 'Track Water',
      description: 'Tap +250ml on the home screen to log your water intake throughout the day.',
      color: AppColors.water,
    ),
    _Tip(
      icon: Icons.edit_note,
      title: 'Manual Entry',
      description: 'Don\'t have a photo? Use Manual entry to type meal details directly.',
      color: AppColors.white70,
    ),
  ];

  void _next() {
    if (_currentTip < _tips.length - 1) {
      setState(() => _currentTip++);
    } else {
      _finish();
    }
  }

  void _finish() async {
    await OnboardingTooltip.markShown();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final tip = _tips[_currentTip];

    return Material(
      color: Colors.black.withValues(alpha: 0.75),
      child: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GestureDetector(
                  onTap: _finish,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: C.of(context).text.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Skip All',
                      style: TextStyle(
                        color: C.of(context).text70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const Spacer(),

            // Tip content
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Padding(
                key: ValueKey(_currentTip),
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: tip.color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(tip.icon, color: tip.color, size: 48),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      tip.title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: C.of(context).text,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tip.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: C.of(context).text54,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Progress dots + Next button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                children: [
                  // Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_tips.length, (i) {
                      final isActive = i == _currentTip;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: isActive ? 24 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: isActive
                              ? tip.color
                              : C.of(context).text.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  // Next button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _next,
                      child: Text(
                        _currentTip < _tips.length - 1
                            ? 'Next'
                            : 'Get Started',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tip {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _Tip({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}
