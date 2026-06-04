import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_logger.dart';
import '../../data/services/notification_service.dart';
import '../../providers/reminder_provider.dart';
import '../../data/models/analyzed_item.dart';
import '../../data/models/meal_entry.dart';
import '../../data/models/scan_history.dart';
import '../../data/services/barcode_service.dart';
import '../../data/services/gemini_service.dart';
import '../../data/services/scan_limit_service.dart';
import '../../data/services/storage_service.dart';
import 'barcode_screen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../core/theme/theme_colors.dart';

class SnapScreen extends ConsumerStatefulWidget {
  final ImageSource? initialSource;
  final String? initialBarcode;
  final bool initialManual;

  const SnapScreen({
    super.key,
    this.initialSource,
    this.initialBarcode,
    this.initialManual = false,
  });

  @override
  ConsumerState<SnapScreen> createState() => _SnapScreenState();
}

class _SnapScreenState extends ConsumerState<SnapScreen> {
  File? _imageFile;
  List<AnalyzedItem> _analyzedItems = [];
  String _mealName = '';
  bool _isAnalyzing = false;
  bool _isSaving = false;
  bool _isRecalculating = false;
  bool _hasEdits = false;
  String? _error;
  int _snapMode = 0; // 0=Capture, 1=Scan, 2=Manual
  final _notesController = TextEditingController();
  final _scanLimitService = ScanLimitService();

  @override
  void initState() {
    super.initState();
    if (widget.initialSource != null) {
      _snapMode = 0;
    } else if (widget.initialBarcode != null) {
      _snapMode = 1;
    } else if (widget.initialManual) {
      _snapMode = 2;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialSource != null) {
        _pickImage(widget.initialSource!);
      } else if (widget.initialBarcode != null) {
        _handleBarcode(widget.initialBarcode!);
      } else if (widget.initialManual) {
        _manualEntry();
      }
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    HapticFeedback.lightImpact();
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: AppConfig.imagePickerMaxWidth.toDouble(),
      maxHeight: AppConfig.imagePickerMaxWidth.toDouble(),
      imageQuality: AppConfig.imagePickerQuality,
    );
    if (picked == null) return;

    setState(() {
      _imageFile = File(picked.path);
      _analyzedItems = [];
      _hasEdits = false;
      _error = null;
      _mealName = '';
      _notesController.clear();
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meal Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: C.of(context).text,
                        ),
                      ),
                      Text(
                        'Helps AI estimate portions accurately',
                        style: TextStyle(fontSize: 12, color: C.of(context).text30),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Quick hint chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _noteChip('Home cooked'),
                  _noteChip('Restaurant'),
                  _noteChip('Oil-free'),
                  _noteChip('Deep fried'),
                  _noteChip('Small portion'),
                  _noteChip('Large portion'),
                ].map((chip) => chip).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 3,
                autofocus: false,
                style: TextStyle(color: C.of(context).text),
                decoration: InputDecoration(
                  hintText:
                      'e.g. "2 chapatis, 1 bowl dal, 200g rice, less oil"',
                  hintStyle: TextStyle(color: C.of(context).text30, fontSize: 13),
                  labelText: 'Quantity, prep method, or ingredients',
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
                          foregroundColor: C.of(context).text70,
                          side: BorderSide(color: C.of(context).glassBorder),
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

  void _saveScanHistory(String userId) {
    final items = _analyzedItems;
    int totalCal = 0;
    double totalP = 0, totalC = 0, totalF = 0;
    double totalFiber = 0, totalSugar = 0, totalSatFat = 0, totalSodium = 0;
    for (final item in items) {
      totalCal += item.calories;
      totalP += item.protein;
      totalC += item.carbs;
      totalF += item.fat;
      totalFiber += item.fiber;
      totalSugar += item.sugar;
      totalSatFat += item.saturatedFat;
      totalSodium += item.sodium;
    }

    final scan = ScanHistory(
      id: '',
      mealName: _mealName,
      score: _calculateMealScore(),
      totalCalories: totalCal,
      totalProtein: totalP,
      totalCarbs: totalC,
      totalFat: totalF,
      totalFiber: totalFiber,
      totalSugar: totalSugar,
      totalSaturatedFat: totalSatFat,
      totalSodium: totalSodium,
      items: items
          .map((i) => ScanHistoryItem(
                name: i.name,
                portion: i.portion,
                calories: i.calories,
                protein: i.protein,
                carbs: i.carbs,
                fat: i.fat,
              ))
          .toList(),
    );

    ref.read(firestoreServiceProvider).saveScanHistory(userId, scan);
    log.d('[Snap] Scan history saved: ${scan.mealName}');
  }

  // ── Meal Score ────────────────────────────────────────────────────────

  Widget _buildMealScore(BuildContext context) {
    if (_analyzedItems.isEmpty) return const SizedBox.shrink();
    if (_isManualMode && !_hasBeenAnalysed) return const SizedBox.shrink();

    final score = _calculateMealScore();
    final suggestions = _getMealSuggestions();
    final scoreColor = score >= 80
        ? AppColors.accentGreen
        : score >= 60
            ? AppColors.carbs
            : score >= 40
                ? AppColors.warning
                : AppColors.error;

    final label = score >= 80
        ? 'Excellent'
        : score >= 60
            ? 'Good'
            : score >= 40
                ? 'Needs Improvement'
                : 'Poor';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scoreColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scoreColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Score circle
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scoreColor.withValues(alpha: 0.12),
                  border: Border.all(color: scoreColor, width: 2.5),
                ),
                child: Center(
                  child: Text(
                    '$score',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: scoreColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meal Score',
                      style: TextStyle(
                        fontSize: 12,
                        color: C.of(context).text30,
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: scoreColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...suggestions.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(s.icon, size: 14, color: s.color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.text,
                          style: TextStyle(
                            fontSize: 12,
                            color: C.of(context).text70,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  int _calculateMealScore() {
    int score = 70; // base score

    double totalCal = 0, totalP = 0, totalC = 0, totalF = 0;
    double totalFiber = 0, totalSugar = 0, totalSatFat = 0, totalSodium = 0;
    for (final item in _analyzedItems) {
      totalCal += item.calories;
      totalP += item.protein;
      totalC += item.carbs;
      totalF += item.fat;
      totalFiber += item.fiber;
      totalSugar += item.sugar;
      totalSatFat += item.saturatedFat;
      totalSodium += item.sodium;
    }

    // Protein: 20-35% of calories is ideal
    final proteinPct = totalCal > 0 ? (totalP * 4 / totalCal * 100) : 0;
    if (proteinPct >= 20 && proteinPct <= 35) score += 10;
    if (proteinPct < 10) score -= 15;

    // Fiber: >5g per meal is good
    if (totalFiber >= 5) score += 10;
    if (totalFiber < 2) score -= 10;

    // Sugar: <15g per meal is good
    if (totalSugar <= 15) score += 5;
    if (totalSugar > 30) score -= 15;

    // Saturated fat: <7g per meal
    if (totalSatFat <= 7) score += 5;
    if (totalSatFat > 15) score -= 15;

    // Sodium: <800mg per meal
    if (totalSodium <= 800) score += 5;
    if (totalSodium > 1500) score -= 10;

    // Calorie range: 300-700 per meal is balanced
    if (totalCal >= 300 && totalCal <= 700) score += 5;
    if (totalCal > 1000) score -= 10;

    return score.clamp(0, 100);
  }

  List<_Suggestion> _getMealSuggestions() {
    final suggestions = <_Suggestion>[];

    double totalCal = 0, totalP = 0, totalC = 0, totalF = 0;
    double totalFiber = 0, totalSugar = 0, totalSatFat = 0, totalSodium = 0;
    for (final item in _analyzedItems) {
      totalCal += item.calories;
      totalP += item.protein;
      totalC += item.carbs;
      totalF += item.fat;
      totalFiber += item.fiber;
      totalSugar += item.sugar;
      totalSatFat += item.saturatedFat;
      totalSodium += item.sodium;
    }

    final proteinPct = totalCal > 0 ? (totalP * 4 / totalCal * 100) : 0;

    // Positive feedback
    if (proteinPct >= 20 && proteinPct <= 35) {
      suggestions.add(_Suggestion(
        icon: Icons.check_circle,
        color: AppColors.accentGreen,
        text: 'Good protein ratio (${proteinPct.toInt()}% of calories)',
      ));
    }
    if (totalFiber >= 5) {
      suggestions.add(_Suggestion(
        icon: Icons.check_circle,
        color: AppColors.accentGreen,
        text: 'Good fiber content (${totalFiber.toStringAsFixed(1)}g)',
      ));
    }

    // Improvement suggestions
    if (proteinPct < 15) {
      suggestions.add(_Suggestion(
        icon: Icons.arrow_upward,
        color: AppColors.protein,
        text: 'Add more protein — try eggs, paneer, dal, or chicken',
      ));
    }
    if (totalFiber < 3) {
      suggestions.add(_Suggestion(
        icon: Icons.arrow_upward,
        color: AppColors.fiber,
        text: 'Low fiber — add salad, vegetables, or whole grains',
      ));
    }

    // Cut suggestions
    if (totalSugar > 25) {
      suggestions.add(_Suggestion(
        icon: Icons.arrow_downward,
        color: AppColors.warning,
        text: 'High sugar (${totalSugar.toInt()}g) — reduce sweet items',
      ));
    }
    if (totalSatFat > 12) {
      suggestions.add(_Suggestion(
        icon: Icons.arrow_downward,
        color: AppColors.error,
        text: 'High saturated fat (${totalSatFat.toInt()}g) — reduce fried/oily items',
      ));
    }
    if (totalSodium > 1200) {
      suggestions.add(_Suggestion(
        icon: Icons.arrow_downward,
        color: AppColors.warning,
        text: 'High sodium (${totalSodium.toInt()}mg) — reduce salty items, papad, pickles',
      ));
    }
    if (totalCal > 900) {
      suggestions.add(_Suggestion(
        icon: Icons.arrow_downward,
        color: AppColors.error,
        text: 'High calorie meal (${totalCal.toInt()} kcal) — consider smaller portions',
      ));
    }

    return suggestions;
  }

  Widget _noteChip(String label) {
    return GestureDetector(
      onTap: () {
        final current = _notesController.text;
        if (current.isEmpty) {
          _notesController.text = label;
        } else {
          _notesController.text = '$current, $label';
        }
        _notesController.selection = TextSelection.fromPosition(
          TextPosition(offset: _notesController.text.length),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.accentGreen.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: AppColors.accentGreen.withValues(alpha: 0.2)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.accentGreen,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Future<bool> _checkScanLimit() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return false;

    final canScan = await _scanLimitService.canScan(user.uid);
    if (!canScan) {
      final count = await _scanLimitService.getTodayCount(user.uid);
      if (!mounted) return false;
      setState(() => _error =
          'Daily scan limit reached ($count/${ScanLimitService.dailyLimit}). Limit resets at midnight. Use Manual entry instead.');
      return false;
    }
    return true;
  }

  Future<void> _analyzeImage() async {
    if (_imageFile == null) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    if (!await _checkScanLimit()) return;

    setState(() {
      _isAnalyzing = true;
      _error = null;
    });

    try {
      final apiKey = AppConfig.geminiApiKey;
      if (apiKey.isEmpty) {
        throw GeminiAnalysisException(
            'Gemini API key not configured. Add GEMINI_API_KEY to your .env file');
      }

      final gemini = GeminiService(apiKey: apiKey);
      final notes = _notesController.text.trim();
      final geminiResult = await gemini.analyzeFood(_imageFile!, notes: notes);

      if (geminiResult != null && mounted) {
        await _scanLimitService.incrementCount(user.uid);
        HapticFeedback.mediumImpact();
        setState(() {
          _mealName = geminiResult.mealName;
          _analyzedItems = geminiResult.items;
          _hasEdits = false;
        });
        // Save to scan history
        _saveScanHistory(user.uid);
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

  bool _isManualMode = false;
  bool _hasBeenAnalysed = false;

  void _manualEntry() {
    HapticFeedback.lightImpact();
    log.i('[Snap] Manual meal entry');

    setState(() {
      _imageFile = null;
      _error = null;
      _mealName = '';
      _analyzedItems = [];
      _hasEdits = false;
      _isManualMode = true;
      _hasBeenAnalysed = false;
    });

    _showResultSheet();
  }

  Future<void> _handleBarcode(String barcode) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    log.i('[Snap] Barcode lookup: $barcode');
    setState(() {
      _snapMode = 1;
      _isAnalyzing = true;
      _error = null;
      _imageFile = null;
      _analyzedItems = [];
    });

    try {
      final result = await BarcodeService().lookupBarcode(barcode);
      if (result == null) {
        setState(() => _error = 'Product not found in database. Try photo analysis instead.');
        return;
      }

      if (mounted) {
        setState(() {
          _mealName = result.mealName;
          _analyzedItems = [
            AnalyzedItem(
              name: result.mealName,
              portion: result.servingSize,
              calories: result.calories,
              protein: result.protein,
              carbs: result.carbs,
              fat: result.fat,
              fiber: result.fiber,
              sugar: result.sugar,
              saturatedFat: result.saturatedFat,
              sodium: result.sodium,
              potassium: result.potassium,
              calcium: result.calcium,
              iron: result.iron,
              magnesium: result.magnesium,
              vitaminA: result.vitaminA,
              vitaminC: result.vitaminC,
              vitaminD: result.vitaminD,
              vitaminB12: result.vitaminB12,
            ),
          ];
          _hasEdits = false;
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

  // ── Result Sheet ──────────────────────────────────────────────────────

  void _showResultSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          // Sum micronutrients across all items
          double sumField(double Function(AnalyzedItem) fn) =>
              _analyzedItems.fold<double>(0, (s, i) => s + fn(i));
          final totalCal = _analyzedItems.fold<int>(0, (s, i) => s + i.calories);
          final totalProtein = sumField((i) => i.protein);
          final totalCarbs = sumField((i) => i.carbs);
          final totalFat = sumField((i) => i.fat);

          // Micronutrient pills data
          final microPills = <MapEntry<String, String>>[
            if (sumField((i) => i.fiber) > 0)
              MapEntry('Fiber', '${sumField((i) => i.fiber).toStringAsFixed(1)}g'),
            if (sumField((i) => i.sugar) > 0)
              MapEntry('Sugar', '${sumField((i) => i.sugar).toStringAsFixed(1)}g'),
            if (sumField((i) => i.saturatedFat) > 0)
              MapEntry('Sat Fat', '${sumField((i) => i.saturatedFat).toStringAsFixed(1)}g'),
            if (sumField((i) => i.sodium) > 0)
              MapEntry('Sodium', '${sumField((i) => i.sodium).toStringAsFixed(1)}mg'),
            if (sumField((i) => i.potassium) > 0)
              MapEntry('Potassium', '${sumField((i) => i.potassium).toStringAsFixed(1)}mg'),
            if (sumField((i) => i.calcium) > 0)
              MapEntry('Calcium', '${sumField((i) => i.calcium).toStringAsFixed(1)}mg'),
            if (sumField((i) => i.iron) > 0)
              MapEntry('Iron', '${sumField((i) => i.iron).toStringAsFixed(1)}mg'),
            if (sumField((i) => i.magnesium) > 0)
              MapEntry('Magnesium', '${sumField((i) => i.magnesium).toStringAsFixed(1)}mg'),
            if (sumField((i) => i.vitaminA) > 0)
              MapEntry('Vit A', '${sumField((i) => i.vitaminA).toStringAsFixed(1)}mcg'),
            if (sumField((i) => i.vitaminC) > 0)
              MapEntry('Vit C', '${sumField((i) => i.vitaminC).toStringAsFixed(1)}mg'),
            if (sumField((i) => i.vitaminD) > 0)
              MapEntry('Vit D', '${sumField((i) => i.vitaminD).toStringAsFixed(1)}mcg'),
            if (sumField((i) => i.vitaminB12) > 0)
              MapEntry('Vit B12', '${sumField((i) => i.vitaminB12).toStringAsFixed(1)}mcg'),
          ];

          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: C.of(context).bg,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(24)),
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
                                color: C.of(context).text30,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ── Meal Score ──
                          _buildMealScore(context),
                          const SizedBox(height: 16),

                          // ── Section 1: Meal Name ──
                          TextField(
                            controller: TextEditingController(text: _mealName),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: C.of(context).text,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Meal name',
                              hintStyle: TextStyle(
                                color: C.of(context).text30,
                                fontWeight: FontWeight.w700,
                              ),
                              prefixIcon: const Icon(Icons.restaurant,
                                  color: AppColors.accentGreen, size: 22),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 8),
                            ),
                            onChanged: (v) => _mealName = v,
                          ),
                          Divider(color: C.of(context).glassBorder),
                          const SizedBox(height: 12),

                          // ── Section 2: Items List ──
                          Text(
                            'Items',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: C.of(context).text54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._analyzedItems.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: C.of(context).card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: C.of(context).glassBorder),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name.isEmpty
                                              ? 'Untitled item'
                                              : item.name,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: item.name.isEmpty
                                                ? C.of(context).text30
                                                : C.of(context).text,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          item.portion,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.accentGreen,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${item.calories} kcal  \u2022  P ${item.protein.toStringAsFixed(1)}g  \u2022  C ${item.carbs.toStringAsFixed(1)}g  \u2022  F ${item.fat.toStringAsFixed(1)}g',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: C.of(context).text54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Edit + Delete buttons
                                  Column(
                                    children: [
                                      GestureDetector(
                                        onTap: () => _showItemEditor(
                                            index, setSheetState),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: AppColors.accentGreen
                                                .withValues(alpha: 0.08),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.edit,
                                              color: AppColors.accentGreen,
                                              size: 16),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      GestureDetector(
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          setSheetState(() {
                                            _analyzedItems.removeAt(index);
                                            _hasEdits = true;
                                          });
                                          setState(() {});
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: AppColors.error
                                                .withValues(alpha: 0.08),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.close,
                                              color: AppColors.error,
                                              size: 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),

                          // Add Item button
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              final newItem = AnalyzedItem(
                                  name: '', portion: '1 serving');
                              setSheetState(() {
                                _analyzedItems.add(newItem);
                              });
                              setState(() {});
                              _showItemEditor(
                                  _analyzedItems.length - 1, setSheetState,
                                  removeIfEmpty: true);
                            },
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.accentGreen
                                    .withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.accentGreen
                                      .withValues(alpha: 0.2),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add,
                                      color: AppColors.accentGreen,
                                      size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                    'Add Item',
                                    style: TextStyle(
                                      color: AppColors.accentGreen,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Quick summary row
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: C.of(context).card,
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: C.of(context).glassBorder),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _quickStat('$totalCal', 'kcal',
                                    AppColors.accentGreen),
                                _quickStatDivider(),
                                _quickStat(
                                    '${totalProtein.toStringAsFixed(1)}g',
                                    'Protein',
                                    AppColors.protein),
                                _quickStatDivider(),
                                _quickStat(
                                    '${totalCarbs.toStringAsFixed(1)}g',
                                    'Carbs',
                                    AppColors.carbs),
                                _quickStatDivider(),
                                _quickStat('${totalFat.toStringAsFixed(1)}g',
                                    'Fat', AppColors.fat),
                              ],
                            ),
                          ),

                          // ── Section 3: Combined Micronutrients ──
                          if (microPills.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Vitamins & Minerals',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: C.of(context).text54,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: C.of(context).card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: C.of(context).glassBorder),
                              ),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: microPills.map((pill) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentGreen
                                          .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${pill.key} ${pill.value}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: C.of(context).text70,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],

                          // ── Section 4: Bottom Buttons ──
                          const SizedBox(height: 20),
                          if (_analyzedItems.isNotEmpty &&
                              (_hasEdits || (_isManualMode && !_hasBeenAnalysed))) ...[
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: _isRecalculating
                                    ? null
                                    : () async {
                                        await _reAnalyse(setSheetState,
                                            forceAll: true);
                                      },
                                icon: _isRecalculating
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.accentGreen,
                                        ),
                                      )
                                    : Icon(_hasBeenAnalysed
                                        ? Icons.refresh
                                        : Icons.auto_awesome,
                                        size: 20),
                                label: Text(_isRecalculating
                                    ? 'Analysing...'
                                    : _hasBeenAnalysed
                                        ? 'Re-Analyse'
                                        : 'Analyse with AI'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.accentGreen,
                                  side: const BorderSide(
                                      color: AppColors.accentGreen),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          const SizedBox(height: 72),
                        ],
                      ),
                    ),
                  ),

                  // Pinned Log Meal button at bottom
                  if (!_isSaving && !_isRecalculating)
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 16,
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: (_analyzedItems.isEmpty ||
                                  _analyzedItems.every((i) => i.name.trim().isEmpty) ||
                                  _mealName.trim().isEmpty)
                              ? null
                              : () => _logMeal(setSheetState),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline, size: 20),
                              SizedBox(width: 8),
                              Text('Log Meal'),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Blocking loading overlay
                  if (_isSaving || _isRecalculating)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24)),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              color: AppColors.accentGreen,
                              strokeWidth: 3,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _isSaving
                                  ? 'Logging your meal...'
                                  : _hasBeenAnalysed
                                      ? 'Re-analysing meal...'
                                      : 'Analysing with AI...',
                              style: TextStyle(
                                color: C.of(context).text,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_isRecalculating) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Calculating nutrition from updated items',
                                style: TextStyle(
                                  color: C.of(context).text30,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
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
          style: TextStyle(fontSize: 10, color: C.of(context).text30),
        ),
      ],
    );
  }

  Widget _quickStatDivider() {
    return Container(width: 1, height: 30, color: C.of(context).glassBorder);
  }

  // ── Item Editor ───────────────────────────────────────────────────────

  void _showItemEditor(int index, StateSetter setSheetState,
      {bool removeIfEmpty = false}) {
    final item = _analyzedItems[index];

    final nameCtrl = TextEditingController(text: item.name);
    final portionCtrl = TextEditingController(text: item.portion);
    final caloriesCtrl = TextEditingController(text: '${item.calories}');
    final proteinCtrl =
        TextEditingController(text: item.protein.toStringAsFixed(1));
    final carbsCtrl =
        TextEditingController(text: item.carbs.toStringAsFixed(1));
    final fatCtrl = TextEditingController(text: item.fat.toStringAsFixed(1));
    final fiberCtrl =
        TextEditingController(text: item.fiber.toStringAsFixed(1));
    final sugarCtrl =
        TextEditingController(text: item.sugar.toStringAsFixed(1));
    final satFatCtrl =
        TextEditingController(text: item.saturatedFat.toStringAsFixed(1));
    final sodiumCtrl =
        TextEditingController(text: item.sodium.toStringAsFixed(1));
    final potassiumCtrl =
        TextEditingController(text: item.potassium.toStringAsFixed(1));
    final calciumCtrl =
        TextEditingController(text: item.calcium.toStringAsFixed(1));
    final ironCtrl = TextEditingController(text: item.iron.toStringAsFixed(1));
    final magnesiumCtrl =
        TextEditingController(text: item.magnesium.toStringAsFixed(1));
    final vitACtrl =
        TextEditingController(text: item.vitaminA.toStringAsFixed(1));
    final vitCCtrl =
        TextEditingController(text: item.vitaminC.toStringAsFixed(1));
    final vitDCtrl =
        TextEditingController(text: item.vitaminD.toStringAsFixed(1));
    final vitB12Ctrl =
        TextEditingController(text: item.vitaminB12.toStringAsFixed(1));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) => Container(
          decoration: BoxDecoration(
            color: C.of(ctx).bg,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: C.of(ctx).text30,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(
                          'Edit Item',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: C.of(ctx).text,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.close, color: C.of(ctx).text54),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Fields
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _editorField(ctx, 'Item Name', nameCtrl, Icons.restaurant),
                      _editorField(ctx, 'Portion', portionCtrl, Icons.straighten),
                      _editorField(
                          ctx, 'Calories', caloriesCtrl, Icons.local_fire_department,
                          isNumber: true),
                      const SizedBox(height: 8),
                      _editorSectionLabel(ctx, 'Macros & More'),
                      _editorFieldGrid(ctx, [
                        _EditorFieldData('Protein (g)', proteinCtrl),
                        _EditorFieldData('Carbs (g)', carbsCtrl),
                        _EditorFieldData('Fat (g)', fatCtrl),
                        _EditorFieldData('Fiber (g)', fiberCtrl),
                        _EditorFieldData('Sugar (g)', sugarCtrl),
                        _EditorFieldData('Sat Fat (g)', satFatCtrl),
                      ]),
                      const SizedBox(height: 8),
                      _editorSectionLabel(ctx, 'Minerals'),
                      _editorFieldGrid(ctx, [
                        _EditorFieldData('Sodium (mg)', sodiumCtrl),
                        _EditorFieldData('Potassium (mg)', potassiumCtrl),
                        _EditorFieldData('Calcium (mg)', calciumCtrl),
                        _EditorFieldData('Iron (mg)', ironCtrl),
                        _EditorFieldData('Magnesium (mg)', magnesiumCtrl),
                      ]),
                      const SizedBox(height: 8),
                      _editorSectionLabel(ctx, 'Vitamins'),
                      _editorFieldGrid(ctx, [
                        _EditorFieldData('Vit A (mcg)', vitACtrl),
                        _EditorFieldData('Vit C (mg)', vitCCtrl),
                        _EditorFieldData('Vit D (mcg)', vitDCtrl),
                        _EditorFieldData('Vit B12 (mcg)', vitB12Ctrl),
                      ]),
                    ],
                  ),
                ),
              ),

              // Done button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      item.name = nameCtrl.text.trim();
                      item.portion = portionCtrl.text.trim();
                      item.calories = _parsePositive(caloriesCtrl.text).toInt();
                      item.protein = _parsePositive(proteinCtrl.text);
                      item.carbs = _parsePositive(carbsCtrl.text);
                      item.fat = _parsePositive(fatCtrl.text);
                      item.fiber = _parsePositive(fiberCtrl.text);
                      item.sugar = _parsePositive(sugarCtrl.text);
                      item.saturatedFat = _parsePositive(satFatCtrl.text);
                      item.sodium = _parsePositive(sodiumCtrl.text);
                      item.potassium = _parsePositive(potassiumCtrl.text);
                      item.calcium = _parsePositive(calciumCtrl.text);
                      item.iron = _parsePositive(ironCtrl.text);
                      item.magnesium = _parsePositive(magnesiumCtrl.text);
                      item.vitaminA = _parsePositive(vitACtrl.text);
                      item.vitaminC = _parsePositive(vitCCtrl.text);
                      item.vitaminD = _parsePositive(vitDCtrl.text);
                      item.vitaminB12 = _parsePositive(vitB12Ctrl.text);
                      item.isUserEdited = true;

                      setState(() => _hasEdits = true);
                      setSheetState(() {});
                      Navigator.pop(ctx);
                    },
                    child: const Text('Done'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      if (removeIfEmpty && index < _analyzedItems.length &&
          _analyzedItems[index].name.trim().isEmpty) {
        setSheetState(() {
          _analyzedItems.removeAt(index);
        });
        setState(() {});
      }
    });
  }

  double _parsePositive(String text) {
    final val = double.tryParse(text) ?? 0;
    return val < 0 ? 0 : val;
  }

  Widget _editorField(
      BuildContext ctx, String label, TextEditingController ctrl, IconData icon,
      {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: TextStyle(color: C.of(ctx).text, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: C.of(ctx).text54, size: 20),
        ),
      ),
    );
  }

  Widget _editorSectionLabel(BuildContext ctx, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: C.of(ctx).text54,
        ),
      ),
    );
  }

  Widget _editorFieldGrid(BuildContext ctx, List<_EditorFieldData> fields) {
    final rows = <Widget>[];
    for (var i = 0; i < fields.length; i += 2) {
      final left = fields[i];
      final right = i + 1 < fields.length ? fields[i + 1] : null;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: left.ctrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: C.of(ctx).text, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: left.label,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (right != null)
                Expanded(
                  child: TextField(
                    controller: right.ctrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: C.of(ctx).text, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: right.label,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                  ),
                )
              else
                const Expanded(child: SizedBox()),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  // ── Re-Analyse ────────────────────────────────────────────────────────

  Future<void> _reAnalyse(StateSetter setSheetState,
      {bool forceAll = false}) async {
    _isRecalculating = true;
    setSheetState(() {});
    setState(() {});

    try {
      final apiKey = AppConfig.geminiApiKey;
      final gemini = GeminiService(apiKey: apiKey);

      // For first-time AI analysis, reset isUserEdited so all items get analysed
      if (forceAll) {
        for (final item in _analyzedItems) {
          item.isUserEdited = false;
        }
      }

      final result = await gemini.recalculateItems(_analyzedItems);

      if (result != null && mounted) {
        _analyzedItems = result;
        _hasEdits = false;
        _hasBeenAnalysed = true;
        setSheetState(() {});
        setState(() {});
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        _isRecalculating = false;
        setSheetState(() {});
        setState(() {});
      }
    }
  }

  // ── Log Meal ──────────────────────────────────────────────────────────

  Future<void> _logMeal(StateSetter setSheetState) async {
    FocusScope.of(context).unfocus();
    if (_mealName.trim().isEmpty && _analyzedItems.isNotEmpty) {
      _mealName = _analyzedItems.first.name;
    }
    if (_mealName.trim().isEmpty) {
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

    setState(() => _isSaving = true);
    setSheetState(() {});

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      String? imageUrl;
      if (_imageFile != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        imageUrl = await StorageService()
            .uploadMealImage(user.uid, fileName, _imageFile!);
      }

      // Sum all items
      double sumField(double Function(AnalyzedItem) fn) =>
          _analyzedItems.fold<double>(0, (s, i) => s + fn(i));
      final totalCal = _analyzedItems.fold<int>(0, (s, i) => s + i.calories);

      final meal = MealEntry(
        id: '',
        mealName: _mealName.trim(),
        calories: totalCal,
        protein: sumField((i) => i.protein),
        carbs: sumField((i) => i.carbs),
        fat: sumField((i) => i.fat),
        fiber: sumField((i) => i.fiber),
        sugar: sumField((i) => i.sugar),
        saturatedFat: sumField((i) => i.saturatedFat),
        sodium: sumField((i) => i.sodium),
        potassium: sumField((i) => i.potassium),
        calcium: sumField((i) => i.calcium),
        iron: sumField((i) => i.iron),
        magnesium: sumField((i) => i.magnesium),
        vitaminA: sumField((i) => i.vitaminA),
        vitaminC: sumField((i) => i.vitaminC),
        vitaminD: sumField((i) => i.vitaminD),
        vitaminB12: sumField((i) => i.vitaminB12),
        imageUrl: imageUrl,
        mealType: MealEntry.mealTypeFromTime(DateTime.now()),
        servingSize: _analyzedItems.length == 1
            ? _analyzedItems.first.portion
            : '${_analyzedItems.length} items',
        itemsDetected: _analyzedItems.map((i) => i.toString()).toList(),
        items: _analyzedItems.map((i) => i.copy()).toList(),
      );

      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.addMeal(user.uid, meal);

      final profile = await firestoreService.getProfile(user.uid);
      await firestoreService.recalculateDailySummary(
        user.uid,
        DateTime.now(),
        profile?.dailyCalorieTarget ?? AppConfig.defaultCalorieTarget,
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
        _analyzedItems = [];
        _mealName = '';
        _hasEdits = false;
      });

      _maybeShowReminderPrompt();
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
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
        setSheetState(() {});
      }
    }
  }

  Future<void> _maybeShowReminderPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final asked = prefs.getBool('reminder_prompt_shown') ?? false;
    final alreadyEnabled = ref.read(reminderProvider).enabled;
    if (asked || alreadyEnabled || !mounted) return;

    await prefs.setBool('reminder_prompt_shown', true);

    // Small delay so the meal success snackbar is visible first
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: C.of(context).card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Enable Meal Reminders?',
          style: TextStyle(
            color: C.of(context).text,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Great job logging your meal! Would you like daily reminders so you never forget to track your breakfast, lunch, and dinner?',
          style: TextStyle(color: C.of(context).text54, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Not Now',
                style: TextStyle(color: C.of(context).text30)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentGreen,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Yes, Remind Me'),
          ),
        ],
      ),
    );

    if (accepted == true && mounted) {
      await NotificationService().init();
      final granted = await NotificationService().requestPermission();
      if (granted) {
        ref.read(reminderProvider.notifier).toggle();
      }
    }
  }

  List<Widget> _scanCorners(BuildContext context) {
    const size = 24.0;
    const thickness = 3.0;
    const margin = 32.0;
    final color = AppColors.accentGreen;

    Widget corner(Alignment align, {bool flipH = false, bool flipV = false}) {
      return Positioned(
        top: align.y < 0 ? margin : null,
        bottom: align.y > 0 ? margin : null,
        left: align.x < 0 ? margin : null,
        right: align.x > 0 ? margin : null,
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _CornerPainter(color: color, thickness: thickness,
                flipH: flipH, flipV: flipV),
          ),
        ),
      );
    }

    return [
      corner(Alignment.topLeft),
      corner(Alignment.topRight, flipH: true),
      corner(Alignment.bottomLeft, flipV: true),
      corner(Alignment.bottomRight, flipH: true, flipV: true),
    ];
  }

  void _openBarcodeScanner() {
    Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScreen()),
    ).then((barcode) {
      if (barcode != null && mounted) {
        _handleBarcode(barcode);
      }
    });
  }

  Widget _modeTab(int index, IconData icon, String label) {
    final isSelected = _snapMode == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_snapMode == index) return;
          HapticFeedback.lightImpact();
          setState(() {
            _snapMode = index;
            _imageFile = null;
            _analyzedItems = [];
            _mealName = '';
            _error = null;
            _hasEdits = false;
            _isAnalyzing = false;
            _isManualMode = false;
            _hasBeenAnalysed = false;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accentGreen.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppColors.accentGreen.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: isSelected
                      ? AppColors.accentGreen
                      : C.of(context).text30),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.accentGreen
                      : C.of(context).text30,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.of(context).bg,
      body: SafeArea(
        child: Column(
          children: [
            // Mode toggle
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: C.of(context).card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: C.of(context).glassBorder),
                  ),
                  child: Row(
                    children: [
                      _modeTab(0, Icons.camera_alt_rounded, 'Capture'),
                      _modeTab(1, Icons.qr_code_scanner, 'Scan'),
                      _modeTab(2, Icons.edit_note, 'Manual'),
                    ],
                  ),
                ),
              ),

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
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Stack(
                              children: [
                                // Scanning line animation
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: Align(
                                      alignment: Alignment.topCenter,
                                      child: Container(
                                        height: 2,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.transparent,
                                              AppColors.accentGreen,
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                      )
                                          .animate(
                                            onPlay: (c) => c.repeat(),
                                          )
                                          .slideY(
                                            begin: 0,
                                            end: 150,
                                            duration: 2000.ms,
                                            curve: Curves.easeInOut,
                                          ),
                                    ),
                                  ),
                                ),
                                // Corner brackets
                                ..._scanCorners(context),
                                // Center content
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.document_scanner_outlined,
                                        color: AppColors.accentGreen,
                                        size: 48,
                                      )
                                          .animate(
                                            onPlay: (c) => c.repeat(reverse: true),
                                          )
                                          .scale(
                                            begin: const Offset(1.0, 1.0),
                                            end: const Offset(1.15, 1.15),
                                            duration: 1200.ms,
                                          ),
                                      const SizedBox(height: 20),
                                      Text(
                                        'Scanning your meal...',
                                        style: TextStyle(
                                          color: C.of(context).text,
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
                                      const SizedBox(height: 8),
                                      Text(
                                        'Identifying food items & nutrients',
                                        style: TextStyle(
                                          color: C.of(context).text54,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: AppColors.accentGreen
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: AppColors.accentGreen
                                                .withValues(alpha: 0.2),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.timer_outlined,
                                                color: AppColors.accentGreen,
                                                size: 14),
                                            const SizedBox(width: 6),
                                            Text(
                                              'This may take a few seconds',
                                              style: TextStyle(
                                                color: AppColors.accentGreen,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                          .animate()
                                          .fadeIn(
                                              duration: 600.ms,
                                              delay: 2000.ms),
                                    ],
                                  ),
                                ),
                              ],
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
                                  _analyzedItems = [];
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
                                child: Icon(Icons.close,
                                    color: C.of(context).text, size: 20),
                              ),
                            ),
                          ),
                      ],
                    )
                  : Container(
                      margin: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: C.of(context).card,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: C.of(context).glassBorder),
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
                              child: Icon(
                                _snapMode == 0
                                    ? Icons.camera_alt_rounded
                                    : _snapMode == 1
                                        ? Icons.qr_code_scanner
                                        : Icons.edit_note,
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
                            Text(
                              _snapMode == 0
                                  ? 'Snap your meal'
                                  : _snapMode == 1
                                      ? 'Scan a barcode'
                                      : 'Add manually',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: C.of(context).text,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _snapMode == 0
                                  ? 'AI will analyze the nutrition instantly'
                                  : _snapMode == 1
                                      ? 'Scan packaged food for nutrition info'
                                      : 'Enter food items and portions manually',
                              style: TextStyle(
                                color: C.of(context).text30,
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
                        style: TextStyle(
                            color: C.of(context).text70, fontSize: 13),
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

            // Action buttons based on mode
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: _snapMode == 0
                  ? Row(
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
                                foregroundColor: C.of(context).text70,
                                side: BorderSide(
                                    color: C.of(context).glassBorder),
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
                    )
                  : _snapMode == 1
                      ? SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: _isAnalyzing ? null : _openBarcodeScanner,
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text('Open Scanner'),
                          ),
                        )
                      : SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: _isAnalyzing ? null : _manualEntry,
                            icon: const Icon(Icons.edit_note),
                            label: const Text('Add Items Manually'),
                          ),
                        ),
            ),

            // Show results button
            if (_analyzedItems.isNotEmpty && !_isAnalyzing)
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

class _Suggestion {
  final IconData icon;
  final Color color;
  final String text;

  const _Suggestion({
    required this.icon,
    required this.color,
    required this.text,
  });
}

class _EditorFieldData {
  final String label;
  final TextEditingController ctrl;
  _EditorFieldData(this.label, this.ctrl);
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final bool flipH;
  final bool flipV;

  _CornerPainter({
    required this.color,
    required this.thickness,
    this.flipH = false,
    this.flipV = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final w = size.width;
    final h = size.height;

    if (!flipH && !flipV) {
      path.moveTo(0, h);
      path.lineTo(0, 0);
      path.lineTo(w, 0);
    } else if (flipH && !flipV) {
      path.moveTo(w, h);
      path.lineTo(w, 0);
      path.lineTo(0, 0);
    } else if (!flipH && flipV) {
      path.moveTo(0, 0);
      path.lineTo(0, h);
      path.lineTo(w, h);
    } else {
      path.moveTo(w, 0);
      path.lineTo(w, h);
      path.lineTo(0, h);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
