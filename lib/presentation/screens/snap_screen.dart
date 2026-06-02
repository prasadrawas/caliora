import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_logger.dart';
import '../../data/models/meal_entry.dart';
import '../../data/services/barcode_service.dart';
import '../../data/services/gemini_service.dart';
import '../../data/services/storage_service.dart';
import 'barcode_screen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';

class SnapScreen extends ConsumerStatefulWidget {
  const SnapScreen({super.key});

  @override
  ConsumerState<SnapScreen> createState() => _SnapScreenState();
}

class _SnapScreenState extends ConsumerState<SnapScreen> {
  File? _imageFile;
  MealEntry? _result;
  bool _isAnalyzing = false;
  bool _isSaving = false;
  String? _error;

  final _nameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _fiberController = TextEditingController();
  final _sugarController = TextEditingController();
  final _saturatedFatController = TextEditingController();
  final _sodiumController = TextEditingController();
  final _potassiumController = TextEditingController();
  final _calciumController = TextEditingController();
  final _ironController = TextEditingController();
  final _magnesiumController = TextEditingController();
  final _vitaminAController = TextEditingController();
  final _vitaminCController = TextEditingController();
  final _vitaminDController = TextEditingController();
  final _vitaminB12Controller = TextEditingController();
  final _servingController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _fiberController.dispose();
    _sugarController.dispose();
    _saturatedFatController.dispose();
    _sodiumController.dispose();
    _potassiumController.dispose();
    _calciumController.dispose();
    _ironController.dispose();
    _magnesiumController.dispose();
    _vitaminAController.dispose();
    _vitaminCController.dispose();
    _vitaminDController.dispose();
    _vitaminB12Controller.dispose();
    _servingController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    HapticFeedback.lightImpact();
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() {
      _imageFile = File(picked.path);
      _result = null;
      _error = null;
      _notesController.clear();
      _nameController.clear();
      _caloriesController.clear();
      _proteinController.clear();
      _carbsController.clear();
      _fatController.clear();
      _fiberController.clear();
      _sugarController.clear();
      _saturatedFatController.clear();
      _sodiumController.clear();
      _potassiumController.clear();
      _calciumController.clear();
      _ironController.clear();
      _magnesiumController.clear();
      _vitaminAController.clear();
      _vitaminCController.clear();
      _vitaminDController.clear();
      _vitaminB12Controller.clear();
      _servingController.clear();
    });

    _showNotesDialog();
  }

  void _showNotesDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppColors.background,
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
                    color: AppColors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.notes,
                        color: AppColors.accentGreen, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Notes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                      Text(
                        'Optional — helps AI estimate better',
                        style: TextStyle(fontSize: 12, color: AppColors.white30),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                maxLines: 3,
                autofocus: true,
                style: const TextStyle(color: AppColors.white),
                decoration: const InputDecoration(
                  hintText:
                      'e.g. "2 chapatis, 1 bowl dal, oil-free prep, ~200g rice"',
                  hintStyle: TextStyle(color: AppColors.white30, fontSize: 13),
                  labelText: 'Notes about this meal',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _analyzeImage();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.white70,
                          side: BorderSide(color: AppColors.glassBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Skip'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _analyzeImage();
                        },
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: const Text('Analyze'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _analyzeImage() async {
    if (_imageFile == null) return;

    setState(() {
      _isAnalyzing = true;
      _error = null;
    });

    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        throw GeminiAnalysisException(
            'Gemini API key not configured. Add GEMINI_API_KEY to your .env file');
      }

      final gemini = GeminiService(apiKey: apiKey);
      final notes = _notesController.text.trim();
      final result = await gemini.analyzeFood(_imageFile!, notes: notes);

      if (result != null && mounted) {
        HapticFeedback.mediumImpact();
        setState(() {
          _result = result;
          _nameController.text = result.mealName;
          _caloriesController.text = result.calories.toString();
          _proteinController.text = result.protein.toStringAsFixed(1);
          _carbsController.text = result.carbs.toStringAsFixed(1);
          _fatController.text = result.fat.toStringAsFixed(1);
          _fiberController.text = result.fiber.toStringAsFixed(1);
          _sugarController.text = result.sugar.toStringAsFixed(1);
          _saturatedFatController.text = result.saturatedFat.toStringAsFixed(1);
          _sodiumController.text = result.sodium.toStringAsFixed(1);
          _potassiumController.text = result.potassium.toStringAsFixed(1);
          _calciumController.text = result.calcium.toStringAsFixed(1);
          _ironController.text = result.iron.toStringAsFixed(1);
          _magnesiumController.text = result.magnesium.toStringAsFixed(1);
          _vitaminAController.text = result.vitaminA.toStringAsFixed(1);
          _vitaminCController.text = result.vitaminC.toStringAsFixed(1);
          _vitaminDController.text = result.vitaminD.toStringAsFixed(1);
          _vitaminB12Controller.text = result.vitaminB12.toStringAsFixed(1);
          _servingController.text = result.servingSize;
        });
        _showResultSheet();
      }
    } on GeminiAnalysisException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Failed to analyze: $e');
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _scanBarcode() async {
    HapticFeedback.lightImpact();
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScreen()),
    );
    if (barcode == null || !mounted) return;

    log.i('[Snap] Barcode scanned: $barcode');
    setState(() {
      _isAnalyzing = true;
      _error = null;
      _imageFile = null;
      _result = null;
    });

    try {
      final result = await BarcodeService().lookupBarcode(barcode);
      if (result == null) {
        setState(() => _error = 'Product not found in database. Try photo analysis instead.');
        return;
      }

      if (mounted) {
        setState(() {
          _result = result;
          _nameController.text = result.mealName;
          _caloriesController.text = result.calories.toString();
          _proteinController.text = result.protein.toStringAsFixed(1);
          _carbsController.text = result.carbs.toStringAsFixed(1);
          _fatController.text = result.fat.toStringAsFixed(1);
          _fiberController.text = result.fiber.toStringAsFixed(1);
          _sugarController.text = result.sugar.toStringAsFixed(1);
          _saturatedFatController.text = result.saturatedFat.toStringAsFixed(1);
          _sodiumController.text = result.sodium.toStringAsFixed(1);
          _potassiumController.text = result.potassium.toStringAsFixed(1);
          _calciumController.text = result.calcium.toStringAsFixed(1);
          _ironController.text = result.iron.toStringAsFixed(1);
          _magnesiumController.text = result.magnesium.toStringAsFixed(1);
          _vitaminAController.text = result.vitaminA.toStringAsFixed(1);
          _vitaminCController.text = result.vitaminC.toStringAsFixed(1);
          _vitaminDController.text = result.vitaminD.toStringAsFixed(1);
          _vitaminB12Controller.text = result.vitaminB12.toStringAsFixed(1);
          _servingController.text = result.servingSize;
        });
        HapticFeedback.mediumImpact();
        _showResultSheet();
      }
    } on BarcodeException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Barcode lookup failed: $e');
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _showResultSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildResultSheet(),
    );
  }

  Future<void> _saveMealWithState(StateSetter setSheetState) async {
    setState(() => _isSaving = true);
    setSheetState(() {});
    await _saveMeal();
    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  double _parsePositive(String text) {
    final val = double.tryParse(text) ?? 0;
    return val < 0 ? 0 : val;
  }

  Future<void> _saveMeal() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Meal name cannot be empty'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      String? imageUrl;
      if (_imageFile != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        imageUrl = await StorageService()
            .uploadMealImage(user.uid, fileName, _imageFile!);
      }

      final meal = MealEntry(
        id: '',
        mealName: _nameController.text.trim(),
        calories: _parsePositive(_caloriesController.text).toInt(),
        protein: _parsePositive(_proteinController.text),
        carbs: _parsePositive(_carbsController.text),
        fat: _parsePositive(_fatController.text),
        fiber: _parsePositive(_fiberController.text),
        sugar: _parsePositive(_sugarController.text),
        saturatedFat: _parsePositive(_saturatedFatController.text),
        sodium: _parsePositive(_sodiumController.text),
        potassium: _parsePositive(_potassiumController.text),
        calcium: _parsePositive(_calciumController.text),
        iron: _parsePositive(_ironController.text),
        magnesium: _parsePositive(_magnesiumController.text),
        vitaminA: _parsePositive(_vitaminAController.text),
        vitaminC: _parsePositive(_vitaminCController.text),
        vitaminD: _parsePositive(_vitaminDController.text),
        vitaminB12: _parsePositive(_vitaminB12Controller.text),
        imageUrl: imageUrl,
        mealType: MealEntry.mealTypeFromTime(DateTime.now()),
        servingSize: _servingController.text,
        itemsDetected: _result?.itemsDetected ?? [],
      );

      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.addMeal(user.uid, meal);

      final profile = await firestoreService.getProfile(user.uid);
      await firestoreService.recalculateDailySummary(
        user.uid,
        DateTime.now(),
        profile?.dailyCalorieTarget ?? 2000,
      );

      if (!mounted) return;
      HapticFeedback.heavyImpact();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Meal logged successfully!'),
          backgroundColor: AppColors.accentGreen,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      setState(() {
        _imageFile = null;
        _result = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving meal: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Widget _buildResultSheet() {
    return StatefulBuilder(
      builder: (context, setSheetState) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.white30,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Header with icon
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color:
                            AppColors.accentGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.auto_awesome,
                          color: AppColors.accentGreen, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Analysis',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Text(
                          'Review and edit before logging',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.white30,
                          ),
                        ),
                      ],
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms),
                const SizedBox(height: 24),

                // Quick summary card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _quickStat(
                          _caloriesController.text, 'kcal', AppColors.accentGreen),
                      _quickStatDivider(),
                      _quickStat(
                          '${_proteinController.text}g', 'Protein', AppColors.protein),
                      _quickStatDivider(),
                      _quickStat(
                          '${_carbsController.text}g', 'Carbs', AppColors.carbs),
                      _quickStatDivider(),
                      _quickStat(
                          '${_fatController.text}g', 'Fat', AppColors.fat),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 100.ms)
                    .slideY(begin: 0.1, end: 0),
                const SizedBox(height: 20),

                // Editable fields
                _editableField('Meal Name', _nameController, Icons.restaurant),
                _editableField(
                    'Serving Size', _servingController, Icons.straighten),
                _editableField(
                    'Calories', _caloriesController, Icons.local_fire_department,
                    keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                _fieldSectionLabel('Macronutrients'),
                _editableField(
                    'Protein (g)', _proteinController, Icons.fitness_center,
                    keyboardType: TextInputType.number),
                _editableField('Carbs (g)', _carbsController, Icons.grain,
                    keyboardType: TextInputType.number),
                _editableField('Fat (g)', _fatController, Icons.opacity,
                    keyboardType: TextInputType.number),
                _editableField('Fiber (g)', _fiberController, Icons.eco,
                    keyboardType: TextInputType.number),
                _editableField('Sugar (g)', _sugarController, Icons.cookie_outlined,
                    keyboardType: TextInputType.number),
                _editableField('Saturated Fat (g)', _saturatedFatController, Icons.water_drop_outlined,
                    keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                _fieldSectionLabel('Minerals'),
                _editableField('Sodium (mg)', _sodiumController, Icons.science_outlined,
                    keyboardType: TextInputType.number),
                _editableField('Potassium (mg)', _potassiumController, Icons.bolt_outlined,
                    keyboardType: TextInputType.number),
                _editableField('Calcium (mg)', _calciumController, Icons.shield_outlined,
                    keyboardType: TextInputType.number),
                _editableField('Iron (mg)', _ironController, Icons.bloodtype_outlined,
                    keyboardType: TextInputType.number),
                _editableField('Magnesium (mg)', _magnesiumController, Icons.spa_outlined,
                    keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                _fieldSectionLabel('Vitamins'),
                _editableField('Vitamin A (mcg)', _vitaminAController, Icons.visibility_outlined,
                    keyboardType: TextInputType.number),
                _editableField('Vitamin C (mg)', _vitaminCController, Icons.local_pharmacy_outlined,
                    keyboardType: TextInputType.number),
                _editableField('Vitamin D (mcg)', _vitaminDController, Icons.wb_sunny_outlined,
                    keyboardType: TextInputType.number),
                _editableField('Vitamin B12 (mcg)', _vitaminB12Controller, Icons.psychology_outlined,
                    keyboardType: TextInputType.number),

                if (_result?.itemsDetected.isNotEmpty == true) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Items Detected',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _result!.itemsDetected
                        .map((item) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.secondary,
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: AppColors.glassBorder),
                              ),
                              child: Text(
                                item,
                                style: const TextStyle(
                                    color: AppColors.white70, fontSize: 12),
                              ),
                            ))
                        .toList(),
                  ),
                ],

                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSaving
                        ? null
                        : () {
                            setSheetState(() {});
                            _saveMealWithState(setSheetState);
                          },
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.background,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline, size: 20),
                              SizedBox(width: 8),
                              Text('Log Meal'),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Full-screen loading overlay
        if (_isSaving)
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: AppColors.accentGreen,
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Logging your meal...',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
          },
        );
      },
    );
  }

  Widget _fieldSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.white54,
        ),
      ),
    );
  }

  Widget _quickStat(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.white30),
        ),
      ],
    );
  }

  Widget _quickStatDivider() {
    return Container(width: 1, height: 30, color: AppColors.glassBorder);
  }

  Widget _editableField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.white),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.white54, size: 20),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Image preview area
            Expanded(
              child: _imageFile != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          margin: const EdgeInsets.all(16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.file(
                              _imageFile!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        if (_isAnalyzing)
                          Container(
                            margin: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentGreen
                                          .withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: CircularProgressIndicator(
                                        color: AppColors.accentGreen,
                                        strokeWidth: 3,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  const Text(
                                    'Analyzing your meal...',
                                    style: TextStyle(
                                      color: AppColors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                      .animate(
                                        onPlay: (c) => c.repeat(),
                                      )
                                      .shimmer(
                                        duration: 1500.ms,
                                        color: AppColors.accentGreen
                                            .withValues(alpha: 0.3),
                                      ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Identifying food items and nutrients',
                                    style: TextStyle(
                                      color: AppColors.white30,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // Retake button (top-right)
                        if (!_isAnalyzing)
                          Positioned(
                            top: 28,
                            right: 28,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _imageFile = null;
                                  _result = null;
                                  _error = null;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.black.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    color: AppColors.white, size: 20),
                              ),
                            ),
                          ),
                      ],
                    )
                  : Container(
                      margin: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.cardSurface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.accentGreen
                                    .withValues(alpha: 0.08),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 56,
                                color: AppColors.accentGreen,
                              ),
                            )
                                .animate(
                                  onPlay: (c) => c.repeat(reverse: true),
                                )
                                .scale(
                                  begin: const Offset(1.0, 1.0),
                                  end: const Offset(1.06, 1.06),
                                  duration: 1500.ms,
                                ),
                            const SizedBox(height: 24),
                            const Text(
                              'Snap your meal',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'AI will analyze the nutrition instantly',
                              style: TextStyle(
                                color: AppColors.white30,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),

            // Error message
            if (_error != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                            color: AppColors.white70, fontSize: 13),
                      ),
                    ),
                    GestureDetector(
                      onTap: _analyzeImage,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Retry',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms).shake(hz: 2, offset: const Offset(2, 0)),

            // Barcode scan button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _isAnalyzing ? null : _scanBarcode,
                  icon: const Icon(Icons.qr_code_scanner, size: 20),
                  label: const Text('Scan Barcode'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentGreen,
                    side: const BorderSide(color: AppColors.accentGreen),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: _isAnalyzing
                            ? null
                            : () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Gallery'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.white70,
                          side: BorderSide(color: AppColors.glassBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isAnalyzing
                            ? null
                            : () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_rounded),
                        label: const Text('Take Photo'),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Show results button
            if (_result != null && !_isAnalyzing)
              Padding(
                padding:
                    const EdgeInsets.only(left: 20, right: 20, bottom: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _showResultSheet,
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('View Analysis Results'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accentGreen,
                      side: const BorderSide(color: AppColors.accentGreen),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 300.ms)
                  .slideY(begin: 0.1, end: 0),
          ],
        ),
      ),
    );
  }
}
