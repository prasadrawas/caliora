import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import 'legal_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;
  bool _isRegister = false;
  bool _obscurePassword = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAuthSuccess(dynamic credential) async {
    final user = credential.user;
    if (user == null || !mounted) return;

    final hasProfile = await ref
        .read(firestoreServiceProvider)
        .hasProfile(user.uid);

    if (!mounted) return;
    if (hasProfile) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacementNamed('/profile-setup');
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final credential = await ref.read(authServiceProvider).signInWithGoogle();
      if (credential == null || !mounted) return;
      await _handleAuthSuccess(credential);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('network') || msg.contains('socket') || msg.contains('timeout')) {
        _showError('Please check your internet connection and try again.');
      } else if (msg.contains('canceled') || msg.contains('cancelled')) {
        // User cancelled — do nothing
      } else {
        _showError('Google sign-in failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final credential = _isRegister
          ? await authService.registerWithEmail(email, password)
          : await authService.signInWithEmail(email, password);

      if (!mounted) return;
      await _handleAuthSuccess(credential);
    } on String catch (e) {
      if (!mounted) return;
      _showError(e);
    } catch (e) {
      if (!mounted) return;
      _showError('$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('Enter your email first, then tap Forgot Password.');
      return;
    }
    try {
      await ref.read(authServiceProvider).sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset link sent to $email'),
          backgroundColor: AppColors.accentGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Could not send reset email. Check the address.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.of(context).bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                // Logo
                SizedBox(
                  width: 72,
                  height: 72,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: Image.asset('assets/images/app_icon.png'),
                    ),
                  ),
                ).animate().scale(duration: 800.ms, curve: Curves.elasticOut),
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
                  style: Theme.of(context).textTheme.headlineLarge,
                ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
                const SizedBox(height: 8),
                Text(
                  'Track your nutrition with\nthe power of AI',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: C.of(context).text54),
                ).animate().fadeIn(duration: 600.ms, delay: 400.ms),
                const SizedBox(height: 40),

                // Email/Password Form
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _emailController,
                        hint: 'Email',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email is required';
                          }
                          final emailRegex = RegExp(
                              r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                          if (!emailRegex.hasMatch(v.trim())) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _passwordController,
                        hint: 'Password',
                        icon: Icons.lock_outline,
                        obscure: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: _isLoading ? null : _submitEmailAuth,
                        suffix: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: C.of(context).text30,
                            size: 20,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty)
                            return 'Password is required';
                          if (_isRegister && v.length < 6) {
                            return 'At least 6 characters';
                          }
                          return null;
                        },
                      ),
                      if (!_isRegister) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _isLoading ? null : _forgotPassword,
                            child: Text(
                              'Forgot Password?',
                              style: TextStyle(
                                color: AppColors.accentGreen,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ] else
                        const SizedBox(height: 16),
                    ],
                  ),
                ).animate().fadeIn(duration: 600.ms, delay: 500.ms),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitEmailAuth,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentGreen,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            ),
                          )
                        : Text(
                            _isRegister ? 'Create Account' : 'Sign In',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ).animate().fadeIn(duration: 600.ms, delay: 600.ms),

                const SizedBox(height: 16),

                // Toggle Register / Sign In
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isRegister
                          ? 'Already have an account?'
                          : "Don't have an account?",
                      style: TextStyle(
                        color: C.of(context).text54,
                        fontSize: 14,
                      ),
                    ),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => setState(() => _isRegister = !_isRegister),
                      child: Text(
                        _isRegister ? 'Sign In' : 'Register',
                        style: TextStyle(
                          color: AppColors.accentGreen,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 600.ms, delay: 650.ms),

                const SizedBox(height: 8),

                // Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: C.of(context).text12)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'or',
                        style: TextStyle(
                          color: C.of(context).text30,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: C.of(context).text12)),
                  ],
                ).animate().fadeIn(duration: 600.ms, delay: 700.ms),

                const SizedBox(height: 16),

                // Google Sign-In Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: C.of(context).text12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.g_mobiledata,
                          size: 28,
                          color: C.of(context).text,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Continue with Google',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: C.of(context).text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 600.ms, delay: 750.ms),

                const SizedBox(height: 20),
                Text.rich(
                  TextSpan(
                    style: Theme.of(context).textTheme.bodySmall,
                    children: [
                      const TextSpan(text: 'By continuing, you agree to our '),
                      TextSpan(
                        text: 'Terms of Service',
                        style: TextStyle(
                          color: AppColors.accentGreen,
                          fontWeight: FontWeight.w600,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LegalScreen(
                                title: 'Terms of Service',
                                url:
                                    'https://bitebloom.prasadrawas.online/terms.html',
                              ),
                            ),
                          ),
                      ),
                      const TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: TextStyle(
                          color: AppColors.accentGreen,
                          fontWeight: FontWeight.w600,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LegalScreen(
                                title: 'Privacy Policy',
                                url:
                                    'https://bitebloom.prasadrawas.online/privacy.html',
                              ),
                            ),
                          ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(duration: 600.ms, delay: 800.ms),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
    TextInputAction? textInputAction,
    VoidCallback? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      validator: validator,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted != null ? (_) => onFieldSubmitted() : null,
      style: TextStyle(color: C.of(context).text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: C.of(context).text30),
        prefixIcon: Icon(icon, color: C.of(context).text30, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: C.of(context).card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.accentGreen, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}
