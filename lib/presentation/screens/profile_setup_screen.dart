import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/nutrition_calculator.dart';
import '../../data/models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../core/theme/theme_colors.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _pageController = PageController();

  String _selectedGender = 'male';
  String _selectedActivityLevel = 'moderate';
  String _selectedDietaryPreference = 'none';
  String _selectedGoal = 'maintain';
  int _currentPage = 0;
  bool _isSaving = false;

  static const _totalPages = 4;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage == 0 && !_formKey.currentState!.validate()) return;
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  double get _activityMultiplier {
    switch (_selectedActivityLevel) {
      case 'sedentary':
        return 1.2;
      case 'light':
        return 1.375;
      case 'moderate':
        return 1.55;
      case 'active':
        return 1.725;
      case 'very_active':
        return 1.9;
      default:
        return 1.55;
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      final age = int.parse(_ageController.text);
      final weight = double.parse(_weightController.text);
      final height = double.parse(_heightController.text);

      final calorieTarget = NutritionCalculator.calculateCalorieTarget(
        weight: weight,
        height: height,
        age: age,
        goal: _selectedGoal,
        gender: _selectedGender,
        activityMultiplier: _activityMultiplier,
      );
      final macros = NutritionCalculator.calculateMacroTargets(
        calorieTarget: calorieTarget,
        goal: _selectedGoal,
      );

      final profile = UserProfile(
        uid: user.uid,
        name: _nameController.text.trim(),
        age: age,
        weight: weight,
        height: height,
        gender: _selectedGender,
        activityLevel: _selectedActivityLevel,
        dietaryPreference: _selectedDietaryPreference,
        goal: _selectedGoal,
        dailyCalorieTarget: calorieTarget,
        proteinTarget: macros['protein']!,
        carbsTarget: macros['carbs']!,
        fatTarget: macros['fat']!,
      );

      await ref.read(firestoreServiceProvider).saveProfile(user.uid, profile);

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving profile: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (_nameController.text.isEmpty && user?.displayName != null) {
      _nameController.text = user!.displayName!;
    }

    return Scaffold(
      backgroundColor: C.of(context).bg,
      appBar: AppBar(
        title: const Text('Setup Your Profile'),
        leading: _currentPage > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _previousPage,
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: List.generate(_totalPages, (i) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i <= _currentPage
                            ? AppColors.accentGreen
                            : C.of(context).text12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildBasicInfoPage(),
                  _buildGenderPage(),
                  _buildActivityPage(),
                  _buildGoalPage(),
                ],
              ),
            ),

            // Bottom button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : _currentPage == _totalPages - 1
                          ? _saveProfile
                          : _nextPage,
                  child: _isSaving
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: C.of(context).bg,
                          ),
                        )
                      : Text(_currentPage == _totalPages - 1
                          ? 'Get Started'
                          : 'Continue'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Page 1: Basic Info ──

  Widget _buildBasicInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Let's get to\nknow you",
              style: Theme.of(context).textTheme.headlineMedium,
            ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.1, end: 0),
            const SizedBox(height: 32),
            _buildField(
              controller: _nameController,
              label: 'Name',
              icon: Icons.person_outline,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter your name' : null,
              delay: 0,
            ),
            const SizedBox(height: 16),
            _buildField(
              controller: _ageController,
              label: 'Age',
              icon: Icons.cake_outlined,
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter your age';
                final age = int.tryParse(v);
                if (age == null || age < 10 || age > 120) {
                  return 'Enter a valid age';
                }
                return null;
              },
              delay: 100,
            ),
            const SizedBox(height: 16),
            _buildField(
              controller: _weightController,
              label: 'Weight (kg)',
              icon: Icons.monitor_weight_outlined,
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter your weight';
                final w = double.tryParse(v);
                if (w == null || w < 20 || w > 300) {
                  return 'Enter a valid weight';
                }
                return null;
              },
              delay: 200,
            ),
            const SizedBox(height: 16),
            _buildField(
              controller: _heightController,
              label: 'Height (cm)',
              icon: Icons.height_outlined,
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter your height';
                final h = double.tryParse(v);
                if (h == null || h < 100 || h > 250) {
                  return 'Enter a valid height';
                }
                return null;
              },
              delay: 300,
            ),
          ],
        ),
      ),
    );
  }

  // ── Page 2: Gender ──

  Widget _buildGenderPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "What's your\ngender?",
            style: Theme.of(context).textTheme.headlineMedium,
          ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.1, end: 0),
          const SizedBox(height: 8),
          Text(
            'This helps us calculate your daily calorie needs accurately.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: C.of(context).text54),
          ).animate().fadeIn(duration: 500.ms, delay: 100.ms),
          const SizedBox(height: 32),
          _buildOptionCard(
            value: 'male',
            selectedValue: _selectedGender,
            icon: Icons.male,
            label: 'Male',
            onTap: () => setState(() => _selectedGender = 'male'),
            delay: 200,
          ),
          const SizedBox(height: 12),
          _buildOptionCard(
            value: 'female',
            selectedValue: _selectedGender,
            icon: Icons.female,
            label: 'Female',
            onTap: () => setState(() => _selectedGender = 'female'),
            delay: 300,
          ),
        ],
      ),
    );
  }

  // ── Page 3: Activity Level & Diet ──

  Widget _buildActivityPage() {
    final activityOptions = [
      ('sedentary', 'Sedentary', 'Little or no exercise', Icons.weekend_outlined),
      ('light', 'Lightly Active', 'Exercise 1-3 days/week', Icons.directions_walk_outlined),
      ('moderate', 'Moderately Active', 'Exercise 3-5 days/week', Icons.directions_run_outlined),
      ('active', 'Very Active', 'Exercise 6-7 days/week', Icons.fitness_center_outlined),
      ('very_active', 'Extremely Active', 'Intense daily exercise', Icons.local_fire_department_outlined),
    ];

    final dietOptions = [
      ('none', 'No Preference'),
      ('vegetarian', 'Vegetarian'),
      ('vegan', 'Vegan'),
      ('keto', 'Keto'),
      ('paleo', 'Paleo'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "How active\nare you?",
            style: Theme.of(context).textTheme.headlineMedium,
          ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.1, end: 0),
          const SizedBox(height: 20),
          ...activityOptions.asMap().entries.map((entry) {
            final (value, label, subtitle, icon) = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildOptionCard(
                value: value,
                selectedValue: _selectedActivityLevel,
                icon: icon,
                label: label,
                subtitle: subtitle,
                onTap: () => setState(() => _selectedActivityLevel = value),
                delay: entry.key * 80,
              ),
            );
          }),
          const SizedBox(height: 24),
          Text(
            'Dietary Preference',
            style: Theme.of(context).textTheme.titleMedium,
          ).animate().fadeIn(duration: 400.ms, delay: 500.ms),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: dietOptions.map((option) {
              final (value, label) = option;
              final isSelected = _selectedDietaryPreference == value;
              return GestureDetector(
                onTap: () =>
                    setState(() => _selectedDietaryPreference = value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accentGreen.withOpacity(0.15)
                        : C.of(context).card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.accentGreen
                          : C.of(context).glassBorder,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          isSelected ? AppColors.accentGreen : C.of(context).text54,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ).animate().fadeIn(duration: 400.ms, delay: 600.ms),
        ],
      ),
    );
  }

  // ── Page 4: Goal ──

  Widget _buildGoalPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "What's your\ngoal?",
            style: Theme.of(context).textTheme.headlineMedium,
          ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.1, end: 0),
          const SizedBox(height: 8),
          Text(
            'We\'ll customize your daily targets based on this.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: C.of(context).text54),
          ).animate().fadeIn(duration: 500.ms, delay: 100.ms),
          const SizedBox(height: 32),
          _buildOptionCard(
            value: 'lose',
            selectedValue: _selectedGoal,
            icon: Icons.trending_down,
            label: 'Lose Weight',
            subtitle: '500 calorie deficit per day',
            onTap: () => setState(() => _selectedGoal = 'lose'),
            delay: 200,
          ),
          const SizedBox(height: 12),
          _buildOptionCard(
            value: 'maintain',
            selectedValue: _selectedGoal,
            icon: Icons.balance,
            label: 'Maintain Weight',
            subtitle: 'Stay at your current weight',
            onTap: () => setState(() => _selectedGoal = 'maintain'),
            delay: 300,
          ),
          const SizedBox(height: 12),
          _buildOptionCard(
            value: 'gain',
            selectedValue: _selectedGoal,
            icon: Icons.trending_up,
            label: 'Gain Weight',
            subtitle: '300 calorie surplus per day',
            onTap: () => setState(() => _selectedGoal = 'gain'),
            delay: 400,
          ),
        ],
      ),
    );
  }

  // ── Shared Widgets ──

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int delay = 0,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: C.of(context).text),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: C.of(context).text54),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: Duration(milliseconds: delay))
        .slideX(begin: 0.05, end: 0);
  }

  Widget _buildOptionCard({
    required String value,
    required String selectedValue,
    required IconData icon,
    required String label,
    String? subtitle,
    required VoidCallback onTap,
    int delay = 0,
  }) {
    final isSelected = selectedValue == value;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentGreen.withOpacity(0.15)
              : C.of(context).card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.accentGreen : C.of(context).glassBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.accentGreen : C.of(context).text54,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      color: isSelected ? C.of(context).text : C.of(context).text70,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? C.of(context).text54
                            : C.of(context).text30,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.accentGreen, size: 24),
          ],
        ),
      ),
    ).animate().fadeIn(
        duration: 400.ms, delay: Duration(milliseconds: delay));
  }
}
