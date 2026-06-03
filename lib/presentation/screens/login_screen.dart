import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../core/theme/theme_colors.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final credential = await authService.signInWithGoogle();
      if (credential == null || !mounted) return;

      final user = credential.user;
      if (user == null) return;

      final hasProfile =
          await ref.read(firestoreServiceProvider).hasProfile(user.uid);

      if (!mounted) return;
      if (hasProfile) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        Navigator.of(context).pushReplacementNamed('/onboarding');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign in failed: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.of(context).bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              // Logo
              SizedBox(
                width: 72,
                height: 72,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: Image.asset(
                      'assets/images/app_icon.png',
                    ),
                  ),
                ),
              )
                  .animate()
                  .scale(duration: 800.ms, curve: Curves.elasticOut),
              const SizedBox(height: 32),
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
                style: Theme.of(context).textTheme.headlineLarge,
              )
                  .animate()
                  .fadeIn(duration: 600.ms, delay: 200.ms),
              const SizedBox(height: 8),
              Text(
                'Track your nutrition with\nthe power of AI',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: C.of(context).text54,
                    ),
              )
                  .animate()
                  .fadeIn(duration: 600.ms, delay: 400.ms),
              const Spacer(flex: 2),
              // Google Sign-In Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: C.of(context).text,
                    foregroundColor: C.of(context).bg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: C.of(context).bg,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.g_mobiledata,
                              size: 28,
                              color: C.of(context).bg,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Continue with Google',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 600.ms, delay: 600.ms)
                  .slideY(begin: 0.3, end: 0),
              const SizedBox(height: 16),
              Text(
                'By continuing, you agree to our Terms of Service',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(duration: 600.ms, delay: 800.ms),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
