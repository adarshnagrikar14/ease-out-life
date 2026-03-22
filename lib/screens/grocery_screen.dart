import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../services/gemini_service.dart';
import '../services/storage_service.dart';
import '../models/grocery_model.dart';

const _breakfastDishes = [
  'Poha',
  'Upma',
  'Aloo Paratha',
  'Idli Sambar',
  'Masala Dosa',
  'Chole Bhature',
  'Besan Chilla',
  'Bread Omelette',
  'Moong Dal Cheela',
  'Puri Bhaji',
];

const _lunchDishes = [
  'Dal Rice',
  'Rajma Chawal',
  'Chole Rice',
  'Paneer Butter Masala + Roti',
  'Veg Biryani',
  'Kadhi Chawal',
  'Aloo Gobi + Roti',
  'Sambar Rice',
  'Egg Curry + Rice',
  'Matar Paneer + Roti',
];

const _dinnerDishes = [
  'Roti + Mixed Sabzi',
  'Khichdi + Raita',
  'Dal Makhani + Roti',
  'Palak Paneer + Roti',
  'Jeera Rice + Dal Fry',
  'Aloo Matar + Paratha',
  'Bhindi Masala + Roti',
  'Paneer Tikka + Naan',
  'Methi Thepla + Curd',
  'Baingan Bharta + Roti',
];

const _snackDishes = [
  'Chai + Biscuit',
  'Samosa',
  'Pakora',
  'Sprouts Chaat',
  'Fruit Bowl',
  'Roasted Makhana',
  'Peanut Chikki',
  'Bread Pakora',
  'Murmura Chivda',
  'Banana Shake',
];

class GroceryScreen extends StatefulWidget {
  const GroceryScreen({super.key});

  @override
  State<GroceryScreen> createState() => _GroceryScreenState();
}

class _GroceryScreenState extends State<GroceryScreen> {
  final _gemini = GeminiService();
  final _storage = StorageService();

  String _breakfast = _breakfastDishes[0];
  String _lunch = _lunchDishes[0];
  String _dinner = _dinnerDishes[0];
  String _snack = _snackDishes[0];

  String _selectedDay = 'All';
  bool _loading = false;
  WeeklyGroceryList? _groceryList;

  late DateTime _weekStart;
  late List<String> _dayNames;
  late String _weekKey;

  @override
  void initState() {
    super.initState();
    _initWeek(DateTime.now());
  }

  void _initWeek(DateTime date) {
    _weekStart = date.subtract(Duration(days: date.weekday - 1));
    _dayNames = List.generate(
        7, (i) => DateFormat('EEEE').format(_weekStart.add(Duration(days: i))));
    _weekKey = DateFormat('yyyy-MM-dd').format(_weekStart);
    _selectedDay = 'All';
    _loadGroceries();
  }

  String get _weekLabel {
    final end = _weekStart.add(const Duration(days: 6));
    return '${DateFormat('MMM d').format(_weekStart)} – ${DateFormat('MMM d').format(end)}';
  }

  Future<void> _loadGroceries() async {
    final cached = await _storage.getGroceryList(_weekKey);
    if (mounted) setState(() => _groceryList = cached);
  }

  Future<void> _generate() async {
    setState(() => _loading = true);
    try {
      final items = await _gemini.generateGroceryList(
        breakfast: _breakfast,
        lunch: _lunch,
        dinner: _dinner,
        snack: _snack,
        days: _dayNames,
        weekKey: _weekKey,
      );
      final list = WeeklyGroceryList(weekKey: _weekKey, items: items);
      await _storage.saveGroceryList(list);
      if (mounted) setState(() => _groceryList = list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleItem(int index) async {
    if (_groceryList == null) return;
    setState(() =>
        _groceryList!.items[index].bought = !_groceryList!.items[index].bought);
    await _storage.saveGroceryList(_groceryList!);
  }

  int get _boughtCount =>
      _groceryList?.items.where((i) => i.bought).length ?? 0;
  int get _totalCount => _groceryList?.items.length ?? 0;

  void _shiftWeek(int direction) {
    _initWeek(_weekStart.add(Duration(days: 7 * direction)));
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<MapEntry<int, GroceryItem>>>{};
    for (var i = 0; i < (_groceryList?.items.length ?? 0); i++) {
      final item = _groceryList!.items[i];
      if (_selectedDay == 'All' || item.forDay == _selectedDay) {
        grouped.putIfAbsent(item.category, () => []);
        grouped[item.category]!.add(MapEntry(i, item));
      }
    }
    final hasItems = grouped.isNotEmpty;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Groceries',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
                if (_totalCount > 0)
                  Text(
                    '$_boughtCount/$_totalCount',
                    style: const TextStyle(
                      color: AppColors.primaryPurple,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Week nav
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _shiftWeek(-1),
                  child: const Icon(Icons.chevron_left,
                      color: AppColors.textSecondary, size: 20),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      _weekLabel,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _shiftWeek(1),
                  child: const Icon(Icons.chevron_right,
                      color: AppColors.textSecondary, size: 20),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 4 meal dropdowns
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _mealDropdown(
                          'Breakfast', _breakfast, _breakfastDishes,
                          (v) => setState(() => _breakfast = v)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _mealDropdown('Lunch', _lunch, _lunchDishes,
                          (v) => setState(() => _lunch = v)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _mealDropdown('Dinner', _dinner, _dinnerDishes,
                          (v) => setState(() => _dinner = v)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _mealDropdown('Snack', _snack, _snackDishes,
                          (v) => setState(() => _snack = v)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Generate button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GestureDetector(
              onTap: _loading ? null : _generate,
              child: Container(
                height: 44,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.primaryPurple.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primaryPurple),
                        )
                      : const Text(
                          'Generate grocery list',
                          style: TextStyle(
                            color: AppColors.primaryPurple,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Day filter
          if (_groceryList != null)
            SizedBox(
              height: 30,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _dayChip('All'),
                  ..._dayNames
                      .map((d) => _dayChip(d, label: d.substring(0, 3))),
                ],
              ),
            ),

          if (_groceryList != null) const SizedBox(height: 8),

          // List
          Expanded(
            child: _groceryList == null
                ? const Center(
                    child: Text(
                      'Select your meals and generate',
                      style:
                          TextStyle(color: AppColors.textHint, fontSize: 13),
                    ),
                  )
                : !hasItems
                    ? const Center(
                        child: Text(
                          'No items for this day',
                          style: TextStyle(
                              color: AppColors.textHint, fontSize: 13),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        children: grouped.entries.map((entry) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 10, bottom: 4),
                                child: Text(
                                  entry.key.toUpperCase(),
                                  style: const TextStyle(
                                    color: AppColors.textHint,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              ...entry.value
                                  .map((e) => _buildItemRow(e.key, e.value)),
                            ],
                          );
                        }).toList(),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _mealDropdown(
      String label, String value, List<String> options, ValueChanged<String> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textHint,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: AppColors.backgroundSecondary,
              style:
                  const TextStyle(color: AppColors.textPrimary, fontSize: 12),
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: AppColors.textHint, size: 16),
              items: options
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _dayChip(String day, {String? label}) {
    final sel = _selectedDay == day;
    return GestureDetector(
      onTap: () => setState(() => _selectedDay = day),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: sel
              ? AppColors.primaryPurple.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: sel
                ? AppColors.primaryPurple.withValues(alpha: 0.4)
                : AppColors.border,
          ),
        ),
        child: Center(
          child: Text(
            label ?? day,
            style: TextStyle(
              color: sel ? AppColors.primaryPurple : AppColors.textHint,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemRow(int index, GroceryItem item) {
    return GestureDetector(
      onTap: () => _toggleItem(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: item.bought
                    ? AppColors.primaryPurple.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color:
                      item.bought ? AppColors.primaryPurple : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: item.bought
                  ? const Icon(Icons.check,
                      size: 12, color: AppColors.primaryPurple)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.name,
                style: TextStyle(
                  color:
                      item.bought ? AppColors.textHint : AppColors.textPrimary,
                  fontSize: 14,
                  decoration: item.bought ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            Text(
              item.quantity,
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
