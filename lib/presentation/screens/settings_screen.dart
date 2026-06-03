import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_colors.dart';
import '../../core/utils/app_logger.dart';
import '../../data/services/export_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/theme_provider.dart';
import '../widgets/shimmer_loader.dart';
import 'profile_edit_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<void> _signOut() async {
    final confirmed = await _showConfirmSheet(
      title: 'Sign Out',
      message: 'Are you sure you want to sign out?',
      confirmLabel: 'Sign Out',
      isDestructive: false,
    );

    if (confirmed != true) return;
    await ref.read(authServiceProvider).signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  Future<void> _deleteAccount() async {
    final confirmed = await _showConfirmSheet(
      title: 'Delete Account',
      message:
          'This will permanently delete your account and all data. This action cannot be undone.',
      confirmLabel: 'Delete Account',
      isDestructive: true,
    );

    if (confirmed != true) return;

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      await ref.read(firestoreServiceProvider).deleteAllUserData(user.uid);
      await ref.read(authServiceProvider).deleteAccount();

      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
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
    }
  }

  Future<bool?> _showConfirmSheet({
    required String title,
    required String message,
    required String confirmLabel,
    required bool isDestructive,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: C.of(context).bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: C.of(context).text30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (isDestructive ? AppColors.error : AppColors.warning)
                    .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isDestructive ? Icons.delete_forever : Icons.logout,
                color: isDestructive ? AppColors.error : AppColors.warning,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDestructive ? AppColors.error : C.of(context).text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: C.of(context).text54, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: C.of(context).text70,
                        side: BorderSide(color: C.of(context).glassBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        Navigator.pop(context, true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isDestructive ? AppColors.error : AppColors.accentGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(confirmLabel),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _exportData() {
    String selectedRange = '7'; // default 7 days

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: C.of(context).bg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: C.of(context).text30,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Export Meal History',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: C.of(context).text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose a date range to export as CSV',
                    style:
                        TextStyle(fontSize: 13, color: C.of(context).text30),
                  ),
                  const SizedBox(height: 20),
                  // Range options
                  ...['7', '14', '30', '90'].map((days) {
                    final isSelected = selectedRange == days;
                    final label = days == '7'
                        ? 'Last 7 days'
                        : days == '14'
                            ? 'Last 2 weeks'
                            : days == '30'
                                ? 'Last 30 days'
                                : 'Last 3 months';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: () =>
                            setSheetState(() => selectedRange = days),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.accentGreen
                                    .withValues(alpha: 0.12)
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
                              Icon(
                                Icons.calendar_today,
                                size: 18,
                                color: isSelected
                                    ? AppColors.accentGreen
                                    : C.of(context).text54,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? AppColors.accentGreen
                                      : C.of(context).text70,
                                ),
                              ),
                              const Spacer(),
                              if (isSelected)
                                const Icon(Icons.check_circle,
                                    color: AppColors.accentGreen, size: 20),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _performExport(int.parse(selectedRange));
                      },
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Export & Share'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _performExport(int days) async {
    final user = ref.read(currentUserProvider);
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (user == null || profile == null) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: C.of(context).card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                  color: AppColors.accentGreen),
              const SizedBox(height: 16),
              Text(
                'Preparing export...',
                style: TextStyle(
                  color: C.of(context).text,
                  fontSize: 14,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days));

      final meals = await ref
          .read(firestoreServiceProvider)
          .getMealsForRange(user.uid, startDate, endDate);

      if (!mounted) return;
      Navigator.pop(context); // close loading

      if (meals.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No meals found in this period'),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }

      log.i('[Export] Exporting ${meals.length} meals for last $days days');
      await ExportService().exportAsCSV(
        meals: meals,
        profile: profile,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      log.e('[Export] Failed: $e');
      if (!mounted) return;
      Navigator.pop(context); // close loading if still open
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _editGoals() {
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile == null) return;

    final calorieController =
        TextEditingController(text: '${profile.dailyCalorieTarget}');
    final proteinController =
        TextEditingController(text: '${profile.proteinTarget}');
    final carbsController =
        TextEditingController(text: '${profile.carbsTarget}');
    final fatController =
        TextEditingController(text: '${profile.fatTarget}');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: C.of(context).bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: C.of(context).text30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Edit Daily Targets',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: C.of(context).text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Customize your nutrition goals',
                style: TextStyle(fontSize: 13, color: C.of(context).text30),
              ),
              const SizedBox(height: 20),
              _dialogField('Daily Calories', calorieController,
                  Icons.local_fire_department),
              const SizedBox(height: 12),
              _dialogField(
                  'Protein (g)', proteinController, Icons.fitness_center),
              const SizedBox(height: 12),
              _dialogField('Carbs (g)', carbsController, Icons.grain),
              const SizedBox(height: 12),
              _dialogField('Fat (g)', fatController, Icons.opacity),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    final user = ref.read(currentUserProvider);
                    if (user == null) return;

                    await ref.read(firestoreServiceProvider).updateProfile(
                      user.uid,
                      {
                        'dailyCalorieTarget':
                            int.tryParse(calorieController.text) ?? AppConfig.defaultCalorieTarget,
                        'proteinTarget':
                            int.tryParse(proteinController.text) ?? AppConfig.defaultProteinTarget,
                        'carbsTarget':
                            int.tryParse(carbsController.text) ?? AppConfig.defaultCarbsTarget,
                        'fatTarget':
                            int.tryParse(fatController.text) ?? AppConfig.defaultFatTarget,
                      },
                    );

                    if (!context.mounted) return;
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context);
                  },
                  child: const Text('Save Targets'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogField(
      String label, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: TextStyle(color: C.of(context).text),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: C.of(context).text54, size: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final user = ref.watch(currentUserProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 24),

          // Profile card
          profileAsync.when(
            data: (profile) {
              if (profile == null) return const SizedBox.shrink();
              final photoUrl = user?.photoURL;
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: C.of(context).card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: C.of(context).glassBorder),
                ),
                child: Column(
                  children: [
                    // Avatar - use Google photo if available
                    CircleAvatar(
                      radius: 38,
                      backgroundColor:
                          AppColors.accentGreen.withValues(alpha: 0.15),
                      backgroundImage: photoUrl != null
                          ? NetworkImage(photoUrl)
                          : null,
                      child: photoUrl == null
                          ? Text(
                              profile.name.isNotEmpty
                                  ? profile.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accentGreen,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      profile.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${profile.age}y  •  ${profile.weight}kg  •  ${profile.height}cm',
                      style:
                          TextStyle(color: C.of(context).text30, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color:
                            AppColors.accentGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.accentGreen
                                .withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        '${profile.goal[0].toUpperCase()}${profile.goal.substring(1)} weight  •  ${profile.activityLevel.replaceAll('_', ' ')}',
                        style: const TextStyle(
                          color: AppColors.accentGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: C.of(context).bg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _targetItem(
                              'Calories',
                              '${profile.dailyCalorieTarget}',
                              AppColors.accentGreen),
                          _targetDivider(),
                          _targetItem('Protein',
                              '${profile.proteinTarget}g', AppColors.protein),
                          _targetDivider(),
                          _targetItem('Carbs',
                              '${profile.carbsTarget}g', AppColors.carbs),
                          _targetDivider(),
                          _targetItem(
                              'Fat', '${profile.fatTarget}g', AppColors.fat),
                        ],
                      ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 100.ms)
                  .slideY(begin: 0.05, end: 0);
            },
            loading: () => const ShimmerLoader(height: 240),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),

          // Settings items
          _settingsTile(
            icon: Icons.person_outline,
            title: 'Edit Profile',
            subtitle: 'Update weight, height, activity, and goal',
            onTap: () {
              final profile = ref.read(userProfileProvider).valueOrNull;
              if (profile == null) return;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProfileEditScreen(profile: profile),
                ),
              );
            },
            delay: 200,
          ),
          _settingsTile(
            icon: Icons.track_changes,
            title: 'Edit Goals',
            subtitle: 'Adjust your daily targets',
            onTap: _editGoals,
            delay: 250,
          ),
          _settingsTile(
            icon: Icons.file_download_outlined,
            title: 'Export Data',
            subtitle: 'Share meal history as CSV',
            onTap: _exportData,
            delay: 275,
          ),
          Builder(builder: (context) {
            final themeMode = ref.watch(themeModeProvider);
            final isDark = themeMode == ThemeMode.dark;
            return _settingsTile(
              icon: isDark ? Icons.dark_mode : Icons.light_mode,
              title: 'Appearance',
              subtitle: isDark ? 'Dark mode' : 'Light mode',
              trailing: Switch(
                value: !isDark,
                onChanged: (_) {
                  HapticFeedback.lightImpact();
                  ref.read(themeModeProvider.notifier).toggle();
                },
                activeColor: AppColors.accentGreen,
              ),
              delay: 250,
            );
          }),
          _settingsTile(
            icon: Icons.notifications_outlined,
            title: 'Reminders',
            subtitle: 'Meal logging reminders',
            trailing: Switch(
              value: false,
              onChanged: (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Notification reminders coming soon!'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
              activeColor: AppColors.accentGreen,
            ),
            delay: 300,
          ),
          const SizedBox(height: 8),
          _settingsTile(
            icon: Icons.logout,
            title: 'Sign Out',
            subtitle: 'Sign out of your account',
            onTap: _signOut,
            delay: 400,
          ),
          _settingsTile(
            icon: Icons.delete_forever,
            title: 'Delete Account',
            subtitle: 'Permanently delete all data',
            onTap: _deleteAccount,
            iconColor: AppColors.error,
            titleColor: AppColors.error,
            delay: 500,
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'Caliora v1.0.0',
              style: TextStyle(
                fontSize: 12,
                color: C.of(context).text30,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _targetItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: C.of(context).text30),
        ),
      ],
    );
  }

  Widget _targetDivider() {
    return Container(width: 1, height: 28, color: C.of(context).glassBorder);
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    Color iconColor = AppColors.accentGreen,
    Color? titleColor,
    int delay = 0,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap?.call();
        },
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: titleColor ?? C.of(context).text,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: C.of(context).text30, fontSize: 12),
        ),
        trailing: trailing ??
            Icon(Icons.chevron_right, color: C.of(context).text30),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        tileColor: C.of(context).card,
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: Duration(milliseconds: delay))
        .slideX(begin: 0.03, end: 0);
  }
}
