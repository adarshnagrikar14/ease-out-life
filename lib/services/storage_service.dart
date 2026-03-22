import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/timetable_model.dart';
import '../models/meal_model.dart';
import '../models/grocery_model.dart';
import '../models/task_model.dart';

class StorageService {
  static const _timetablePrefix = 'timetable_';
  static const _feedbackKey = 'feedback_history';
  static const _energyKey = 'energy_level';

  Future<void> saveTimetable(DailyTimetable timetable) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        '$_timetablePrefix${timetable.date}', timetable.encode());
  }

  Future<DailyTimetable?> getTimetable(String date) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('$_timetablePrefix$date');
    if (data == null) return null;
    try {
      return DailyTimetable.decode(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveFeedback(DayFeedback feedback) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getFeedbackHistory();
    history.add(feedback);
    // Keep last 30 entries
    final trimmed = history.length > 30
        ? history.sublist(history.length - 30)
        : history;
    final encoded = jsonEncode(trimmed.map((f) => f.toJson()).toList());
    await prefs.setString(_feedbackKey, encoded);
  }

  Future<List<DayFeedback>> getFeedbackHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_feedbackKey);
    if (data == null) return [];
    try {
      final list = jsonDecode(data) as List<dynamic>;
      return list
          .map((e) => DayFeedback.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveEnergyLevel(int level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_energyKey, level);
  }

  Future<int> getEnergyLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_energyKey) ?? 3;
  }

  static const _mealsPrefix = 'meals_';

  Future<void> addMeal(String dateKey, MealEntry meal) async {
    final meals = await getMeals(dateKey);
    meals.add(meal);
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(meals.map((m) => m.toJson()).toList());
    await prefs.setString('$_mealsPrefix$dateKey', encoded);
  }

  Future<void> removeMeal(String dateKey, String mealId) async {
    final meals = await getMeals(dateKey);
    meals.removeWhere((m) => m.id == mealId);
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(meals.map((m) => m.toJson()).toList());
    await prefs.setString('$_mealsPrefix$dateKey', encoded);
  }

  Future<List<MealEntry>> getMeals(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('$_mealsPrefix$dateKey');
    if (data == null) return [];
    try {
      final list = jsonDecode(data) as List<dynamic>;
      return list
          .map((e) => MealEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static const _groceryPrefix = 'grocery_';

  Future<void> saveGroceryList(WeeklyGroceryList list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_groceryPrefix${list.weekKey}', list.encode());
  }

  Future<WeeklyGroceryList?> getGroceryList(String weekKey) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('$_groceryPrefix$weekKey');
    if (data == null) return null;
    try {
      return WeeklyGroceryList.decode(data);
    } catch (_) {
      return null;
    }
  }

  // --- Tasks ---

  static const _tasksKey = 'user_tasks';
  static const _smartPlanPrefix = 'smart_plan_';

  Future<void> saveTasks(List<TaskItem> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(tasks.map((t) => t.toJson()).toList());
    await prefs.setString(_tasksKey, encoded);
  }

  Future<List<TaskItem>> getTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_tasksKey);
    if (data == null) return [];
    try {
      final list = jsonDecode(data) as List<dynamic>;
      return list
          .map((e) => TaskItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSmartPlan(SmartPlan plan, String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        '$_smartPlanPrefix$dateKey', jsonEncode(plan.toJson()));
  }

  Future<SmartPlan?> getSmartPlan(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('$_smartPlanPrefix$dateKey');
    if (data == null) return null;
    try {
      return SmartPlan.fromJson(jsonDecode(data) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
