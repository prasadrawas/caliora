import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/app_logger.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../core/theme/theme_colors.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();

    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    log.i('[Splash] Waiting for auth state...');

    // Wait for splash animation
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    // Check current user directly — Firebase persists auth state
    // authStateChanges.first can emit null before restoring session
    User? authState = FirebaseAuth.instance.currentUser;
    log.d('[Splash] currentUser: ${authState?.uid ?? "null"}');

    // If null, wait briefly for auth state stream in case it's still loading
    if (authState == null) {
      log.d('[Splash] Waiting for authStateChanges...');
      authState = await ref
          .read(authServiceProvider)
          .authStateChanges
          .firstWhere((user) => user != null, orElse: () => null)
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => null,
          );
      log.d('[Splash] Stream resolved: ${authState?.uid ?? "null"}');
    }
    if (!mounted) return;

    if (authState == null) {
      log.i('[Splash] No user session → Login');
      _navigateTo('/login');
    } else {
      log.i('[Splash] User found: ${authState.uid}');
      log.d('[Splash] Email: ${authState.email}');
      final hasProfile =
          await ref.read(firestoreServiceProvider).hasProfile(authState.uid);
      if (hasProfile) {
        log.i('[Splash] Profile exists → Home');
        _navigateTo('/home');
      } else {
        log.i('[Splash] No profile → Onboarding');
        _navigateTo('/onboarding');
      }
    }
  }

  void _navigateTo(String route) {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.of(context).bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App icon with glow
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final progress = _controller.value;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow behind icon
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentGreen
                                .withValues(alpha: 0.3 * progress),
                            blurRadius: 50,
                            spreadRadius: 15,
                          ),
                        ],
                      ),
                    ),
                    // App icon
                    SizedBox(
                      width: 72 + (8 * progress),
                      height: 72 + (8 * progress),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: Image.asset(
                            'assets/images/app_icon.png',
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Bite'),
                  TextSpan(
                    text: 'Bloom',
                    style: TextStyle(color: AppColors.accentGreen),
                  ),
                ],
              ),
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    letterSpacing: 2,
                  ),
            )
                .animate()
                .fadeIn(duration: 800.ms, delay: 400.ms)
                .slideY(begin: 0.3, end: 0, duration: 800.ms, delay: 400.ms),
            const SizedBox(height: 8),
            Text(
              AppStrings.tagline,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: C.of(context).text54,
                  ),
            )
                .animate()
                .fadeIn(duration: 800.ms, delay: 800.ms),
            const SizedBox(height: 48),
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.accentGreen.withOpacity(0.5),
              ),
            )
                .animate()
                .fadeIn(duration: 600.ms, delay: 1200.ms),
          ],
        ),
      ),
    );
  }
}
