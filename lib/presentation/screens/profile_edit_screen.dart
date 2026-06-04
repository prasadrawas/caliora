import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_colors.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/nutrition_calculator.dart';
import '../../data/models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  final UserProfile profile;

  const ProfileEditScreen({super.key, required this.profile});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  late final TextEditingController _weightController;
  late final TextEditingController _heightController;

  late String _selectedGender;
  late String _selectedActivityLevel;
  late String _selectedDietaryPreference;
  late String _selectedGoal;
  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameController = TextEditingController(text: p.name);
    _ageController = TextEditingController(text: '${p.age}');
    _weightController = TextEditingController(text: '${p.weight}');
    _heightController = TextEditingController(text: '${p.height}');
    _selectedGender = p.gender;
    _selectedActivityLevel = p.activityLevel;
    _selectedDietaryPreference = p.dietaryPreference;
    _selectedGoal = p.goal;
    for (final c in [_nameController, _ageController, _weightController, _heightController]) {
      c.addListener(() => _hasChanges = true);
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_hasChanges) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: C.of(context).card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Discard changes?',
            style: TextStyle(color: C.of(context).text, fontWeight: FontWeight.w700)),
        content: Text('You have unsaved changes that will be lost.',
            style: TextStyle(color: C.of(context).text70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Keep Editing', style: TextStyle(color: C.of(context).text30)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
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
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

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

      final updated = widget.profile.copyWith(
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

      await ref
          .read(firestoreServiceProvider)
          .saveProfile(user.uid, updated);

      log.i('[ProfileEdit] Profile updated: ${updated.name}');
      log.d('[ProfileEdit] New targets: ${updated.dailyCalorieTarget} kcal, P:${updated.proteinTarget}g C:${updated.carbsTarget}g F:${updated.fatTarget}g');

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile updated'),
          backgroundColor: AppColors.accentGreen,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      log.e('[ProfileEdit] Save failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.of(context).bg,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            if (await _confirmDiscard()) Navigator.pop(context);
          },
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            // Personal Info
            _sectionLabel('Personal Info'),
            const SizedBox(height: 12),
            _field('Name', _nameController, Icons.person_outline,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter your name' : null),
            _field('Age', _ageController, Icons.cake_outlined,
                isNumber: true,
                validator: (v) {
                  final age = int.tryParse(v ?? '');
                  if (age == null || age < 10 || age > 120)
                    return 'Enter valid age';
                  return null;
                }),
            _field('Weight (kg)', _weightController,
                Icons.monitor_weight_outlined,
                isNumber: true,
                validator: (v) {
                  final w = double.tryParse(v ?? '');
                  if (w == null || w < 20 || w > 300)
                    return 'Enter valid weight';
                  return null;
                }),
            _field(
                'Height (cm)', _heightController, Icons.height_outlined,
                isNumber: true,
                validator: (v) {
                  final h = double.tryParse(v ?? '');
                  if (h == null || h < 100 || h > 250)
                    return 'Enter valid height';
                  return null;
                }),
            const SizedBox(height: 24),

            // Gender
            _sectionLabel('Gender'),
            const SizedBox(height: 12),
            Row(
              children: [
                _chip('Male', 'male', _selectedGender,
                    (v) => setState(() => _selectedGender = v)),
                const SizedBox(width: 10),
                _chip('Female', 'female', _selectedGender,
                    (v) => setState(() => _selectedGender = v)),
              ],
            ),
            const SizedBox(height: 24),

            // Activity Level
            _sectionLabel('Activity Level'),
            const SizedBox(height: 12),
            ..._buildActivityOptions(),
            const SizedBox(height: 24),

            // Dietary Preference
            _sectionLabel('Dietary Preference'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['none', 'vegetarian', 'vegan', 'keto', 'paleo']
                  .map((v) => _chip(
                      v == 'none' ? 'No Preference' : v[0].toUpperCase() + v.substring(1),
                      v,
                      _selectedDietaryPreference,
                      (val) => setState(
                          () => _selectedDietaryPreference = val),
                      expand: false))
                  .toList(),
            ),
            const SizedBox(height: 24),

            // Goal
            _sectionLabel('Goal'),
            const SizedBox(height: 12),
            Row(
              children: [
                _chip('Lose', 'lose', _selectedGoal,
                    (v) => setState(() => _selectedGoal = v)),
                const SizedBox(width: 8),
                _chip('Maintain', 'maintain', _selectedGoal,
                    (v) => setState(() => _selectedGoal = v)),
                const SizedBox(width: 8),
                _chip('Gain', 'gain', _selectedGoal,
                    (v) => setState(() => _selectedGoal = v)),
              ],
            ),
            const SizedBox(height: 32),

            // Save
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                child: _isSaving
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: C.of(context).bg,
                        ),
                      )
                    : const Text('Save Profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: C.of(context).text,
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, IconData icon,
      {bool isNumber = false, String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        validator: validator,
        style: TextStyle(color: C.of(context).text),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: C.of(context).text54),
        ),
      ),
    );
  }

  Widget _chip(
      String label, String value, String selected, ValueChanged<String> onTap,
      {bool expand = true}) {
    final isSelected = selected == value;
    final child = GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          _hasChanges = true;
          onTap(value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accentGreen.withValues(alpha: 0.15)
                : C.of(context).card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppColors.accentGreen
                  : C.of(context).glassBorder,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                color: isSelected
                    ? AppColors.accentGreen
                    : C.of(context).text54,
              ),
            ),
          ),
        ),
    );
    return expand ? Expanded(child: child) : child;
  }

  List<Widget> _buildActivityOptions() {
    const options = [
      ('sedentary', 'Sedentary', 'Little or no exercise', Icons.weekend_outlined),
      ('light', 'Lightly Active', 'Exercise 1-3 days/week', Icons.directions_walk_outlined),
      ('moderate', 'Moderately Active', 'Exercise 3-5 days/week', Icons.directions_run_outlined),
      ('active', 'Very Active', 'Exercise 6-7 days/week', Icons.fitness_center_outlined),
      ('very_active', 'Extremely Active', 'Intense daily exercise', Icons.local_fire_department_outlined),
    ];

    return options.map((opt) {
      final (value, label, subtitle, icon) = opt;
      final isSelected = _selectedActivityLevel == value;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            _hasChanges = true;
            setState(() => _selectedActivityLevel = value);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.accentGreen.withValues(alpha: 0.12)
                  : C.of(context).card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? AppColors.accentGreen
                    : C.of(context).glassBorder,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(icon,
                    color: isSelected
                        ? AppColors.accentGreen
                        : C.of(context).text54,
                    size: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? C.of(context).text
                              : C.of(context).text70,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: C.of(context).text30,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle,
                      color: AppColors.accentGreen, size: 22),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }
}
