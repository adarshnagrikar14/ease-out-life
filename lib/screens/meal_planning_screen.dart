import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../services/food_service.dart';
import '../services/storage_service.dart';
import '../models/meal_model.dart';

class MealPlanningScreen extends StatefulWidget {
  const MealPlanningScreen({super.key});

  @override
  State<MealPlanningScreen> createState() => _MealPlanningScreenState();
}

class _MealPlanningScreenState extends State<MealPlanningScreen> {
  final _food = FoodService();
  final _storage = StorageService();
  final _picker = ImagePicker();

  List<MealEntry> _meals = [];
  bool _loading = false;
  int? _expandedIndex;

  String get _dateKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadMeals();
  }

  Future<void> _loadMeals() async {
    final meals = await _storage.getMeals(_dateKey);
    if (mounted) setState(() => _meals = meals);
  }

  double get _totalCal => _meals.fold(0, (s, m) => s + m.calories);
  double get _totalProtein => _meals.fold(0, (s, m) => s + m.protein);
  double get _totalCarbs => _meals.fold(0, (s, m) => s + m.carbs);
  double get _totalFat => _meals.fold(0, (s, m) => s + m.fat);

  Future<void> _addManualMeal() async {
    final dishController = TextEditingController();
    String mealType = 'lunch';

    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.backgroundSecondary,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                  24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add meal',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: dishController,
                    autofocus: true,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'e.g. Dal Makhani, 2 Roti, Raita',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    children: ['breakfast', 'lunch', 'dinner', 'snack']
                        .map((t) {
                      final sel = mealType == t;
                      return GestureDetector(
                        onTap: () => setSheetState(() => mealType = t),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppColors.primaryPurple
                                    .withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: sel
                                  ? AppColors.primaryPurple
                                      .withValues(alpha: 0.4)
                                  : AppColors.border,
                            ),
                          ),
                          child: Text(
                            t,
                            style: TextStyle(
                              color: sel
                                  ? AppColors.primaryPurple
                                  : AppColors.textHint,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                      ),
                      child: const Text('Analyse'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != true || dishController.text.trim().isEmpty) return;

    setState(() => _loading = true);
    try {
      final meal = await _food.analyzeMeal(
          dishController.text.trim(), mealType);
      await _storage.addMeal(_dateKey, meal);
      await _loadMeals();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addPhotoMeal({ImageSource source = ImageSource.camera}) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (file == null) return;

      setState(() => _loading = true);
      final bytes = await File(file.path).readAsBytes();
      final mimeType = file.path.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';

      final meal = await _food.analyzePhoto(bytes, mimeType, 'snack');
      await _storage.addMeal(_dateKey, meal);
      await _loadMeals();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteMeal(String id) async {
    await _storage.removeMeal(_dateKey, id);
    setState(() => _expandedIndex = null);
    await _loadMeals();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meals',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Nourish yourself right',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _loading
                          ? null
                          : () => _addPhotoMeal(
                              source: ImageSource.gallery),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.backgroundSecondary,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.photo_library_outlined,
                            color: AppColors.textSecondary, size: 18),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _loading ? null : _addPhotoMeal,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.backgroundSecondary,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.camera_alt_outlined,
                            color: AppColors.textSecondary, size: 18),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _loading ? null : _addManualMeal,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primaryPurple.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.primaryPurple
                                  .withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.add,
                            color: AppColors.primaryPurple, size: 20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Today's macros summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _macroChip('${_totalCal.round()}', 'kcal'),
                const SizedBox(width: 16),
                _macroChip('${_totalProtein.round()}g', 'protein'),
                const SizedBox(width: 16),
                _macroChip('${_totalCarbs.round()}g', 'carbs'),
                const SizedBox(width: 16),
                _macroChip('${_totalFat.round()}g', 'fat'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Loading indicator
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryPurple,
                  ),
                ),
              ),
            ),

          // Meal list
          Expanded(
            child: _meals.isEmpty && !_loading
                ? const Center(
                    child: Text(
                      'No meals logged today',
                      style:
                          TextStyle(color: AppColors.textHint, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    itemCount: _meals.length,
                    itemBuilder: (_, i) => _buildMealRow(_meals[i], i),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _macroChip(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textHint,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealRow(MealEntry meal, int index) {
    final expanded = _expandedIndex == index;

    return GestureDetector(
      onTap: () =>
          setState(() => _expandedIndex = expanded ? null : index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main row
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: _mealTypeColor(meal.mealType),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    meal.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  '${meal.calories.round()} kcal',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            // Expanded detail
            if (expanded) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _nutrientLine('Serving', meal.servingSize),
                    _nutrientLine('Protein', '${meal.protein.toStringAsFixed(1)}g'),
                    _nutrientLine('Carbs', '${meal.carbs.toStringAsFixed(1)}g'),
                    _nutrientLine('Fat', '${meal.fat.toStringAsFixed(1)}g'),
                    _nutrientLine('Fiber', '${meal.fiber.toStringAsFixed(1)}g'),
                    _nutrientLine('Sugar', '${meal.sugar.toStringAsFixed(1)}g'),
                    _nutrientLine('Sodium', '${meal.sodium.toStringAsFixed(0)}mg'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '${meal.mealType} · ${meal.source}',
                          style: const TextStyle(
                            color: AppColors.textHint,
                            fontSize: 11,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _deleteMeal(meal.id),
                          child: const Text(
                            'Remove',
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _nutrientLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textHint, fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _mealTypeColor(String type) {
    return switch (type) {
      'breakfast' => const Color(0xFFFBBF24),
      'lunch' => const Color(0xFF34D399),
      'dinner' => const Color(0xFF60A5FA),
      'snack' => const Color(0xFFFB923C),
      _ => AppColors.textSecondary,
    };
  }
}
