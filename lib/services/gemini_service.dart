import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import '../models/timetable_model.dart';
import '../models/meal_model.dart';
import '../models/grocery_model.dart';
import '../models/task_model.dart';

class GeminiService {
  static final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  late final GenerativeModel _model;
  late final GenerativeModel _visionModel;

  GeminiService() {
    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        responseMimeType: 'application/json',
      ),
    );
    _visionModel = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.4,
        responseMimeType: 'application/json',
      ),
    );
  }

  Future<DailyTimetable> generateTimetable({
    required String date,
    required String dayOfWeek,
    required int energyLevel,
    List<DayFeedback> feedbackHistory = const [],
  }) async {
    final feedbackContext = _buildFeedbackContext(feedbackHistory);

    final prompt = '''
You are a daily planner for an Indian working woman. Generate a realistic timetable for $dayOfWeek, $date.

Energy level: $energyLevel/5 (1 = drained, 5 = fully charged).

Context: She balances a professional career with household responsibilities, cooking, self-care, and personal time. The schedule should feel supportive, not overwhelming.

Rules:
- Schedule from 07:00 to 22:00 in 1-hour blocks (16 blocks total).
- Low energy (1-2): shorter work blocks, delegate or simplify meals (order in / quick cook), prioritise rest, skincare, and light movement.
- Medium energy (3): balanced office work, home-cooked meals, 30 min exercise, some personal time.
- High energy (4-5): deep focus work, meal prep, longer workout, learning or a hobby.
- Always include: morning routine (skincare, getting ready), breakfast, lunch, dinner, at least one self-care block, wind-down.
- Include realistic blocks: commute/office, household chores, cooking, family/personal time.
- Categories must be one of: work, meal, exercise, break, selfcare, household, personal, health, learning.
- Keep activities specific and practical (e.g. "Quick dal + rice prep" not "Cook food").

$feedbackContext

Return ONLY a JSON object exactly like this:
{
  "date": "$date",
  "energyLevel": $energyLevel,
  "slots": [
    {"time": "07:00", "activity": "...", "category": "..."},
    {"time": "08:00", "activity": "...", "category": "..."}
  ]
}

16 slots from 07:00 to 22:00. No extra text.
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';
      final json = jsonDecode(text) as Map<String, dynamic>;
      return DailyTimetable.fromJson(json);
    } catch (e) {
      return _fallbackTimetable(date, energyLevel);
    }
  }

  String _buildFeedbackContext(List<DayFeedback> history) {
    if (history.isEmpty) return '';

    final recent = history.length > 5
        ? history.sublist(history.length - 5)
        : history;

    final lines = recent.map((f) =>
        '- ${f.date}: rating ${f.rating}/5. "${f.comment}"');

    return '''
Past feedback from the user (use this to improve the schedule):
${lines.join('\n')}

Adjust today's schedule based on this feedback. If they rated low, change what didn't work. If rated high, keep similar patterns.
''';
  }

  static const _mealNutritionPrompt = '''
You are a nutrition expert specialising in Indian cuisine for working women.
Analyse the given food and return ONLY a JSON object:
{
  "name": "dish name",
  "calories": 0.0,
  "protein": 0.0,
  "carbs": 0.0,
  "fat": 0.0,
  "fiber": 0.0,
  "sugar": 0.0,
  "sodium": 0.0,
  "servingSize": "1 bowl (250g)"
}
All values in grams except calories (kcal) and sodium (mg).
Use typical Indian serving sizes. Be accurate. No extra text.
''';

  MealEntry _parseMealJson(Map<String, dynamic> json,
      {required String fallbackName,
      required String mealType,
      required String source}) {
    return MealEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? fallbackName,
      mealType: mealType,
      calories: (json['calories'] as num?)?.toDouble() ?? 0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0,
      fiber: (json['fiber'] as num?)?.toDouble() ?? 0,
      sugar: (json['sugar'] as num?)?.toDouble() ?? 0,
      sodium: (json['sodium'] as num?)?.toDouble() ?? 0,
      servingSize: json['servingSize'] as String? ?? '1 serving',
      source: source,
      timestamp: DateTime.now(),
    );
  }

  Future<MealEntry> analyzeMealByName(String dishName, String mealType) async {
    final prompt = '''
You are a nutrition expert specialising in Indian cuisine.
Analyse this dish and give accurate nutritional values per typical serving.

Dish: "$dishName"

Return ONLY this JSON (no markdown, no backticks, no extra text):
{"name":"dish name","calories":250.0,"protein":10.0,"carbs":30.0,"fat":8.0,"fiber":3.0,"sugar":2.0,"sodium":400.0,"servingSize":"1 bowl (250g)"}

All values: calories in kcal, sodium in mg, rest in grams.
''';

    final response = await _model.generateContent([Content.text(prompt)]);
    final text = response.text ?? '';
    final json = jsonDecode(text) as Map<String, dynamic>;
    return _parseMealJson(json,
        fallbackName: dishName, mealType: mealType, source: 'manual');
  }

  Future<MealEntry> analyzeMealByPhoto(
      Uint8List imageBytes, String mimeType, String mealType) async {
    final prompt = '''
You are a nutrition expert. Identify the food in this photo.
Give the dish name and accurate nutritional values per typical serving.
If multiple items are visible, combine them into one entry with a descriptive name.

Return ONLY this JSON (no markdown, no backticks, no extra text):
{"name":"dish name","calories":250.0,"protein":10.0,"carbs":30.0,"fat":8.0,"fiber":3.0,"sugar":2.0,"sodium":400.0,"servingSize":"1 plate (300g)"}

All values: calories in kcal, sodium in mg, rest in grams.
''';

    final content = Content.multi([
      TextPart(prompt),
      DataPart(mimeType, imageBytes),
    ]);
    final response = await _visionModel.generateContent([content]);
    final text = response.text ?? '';
    final json = jsonDecode(text) as Map<String, dynamic>;
    return _parseMealJson(json,
        fallbackName: 'Scanned meal', mealType: mealType, source: 'photo');
  }

  Future<List<GroceryItem>> generateGroceryList({
    required String breakfast,
    required String lunch,
    required String dinner,
    required String snack,
    required List<String> days,
    required String weekKey,
  }) async {
    final dayList = days.join(', ');

    final prompt = '''
You are an Indian household grocery planner.

The user has planned these meals for the week ($dayList):
- Breakfast: $breakfast (daily)
- Lunch: $lunch (daily)
- Dinner: $dinner (daily)
- Snack: $snack (daily)

Generate a complete grocery shopping list to cook all these meals for the full week for 1 person.

Rules:
- Include ALL ingredients needed: vegetables, dal, rice, atta, oil, spices, dairy, protein, etc.
- Group items by category: vegetables, fruits, grains, dairy, spices, protein, pantry, other
- Calculate realistic quantities for 7 days for 1 person
- Tag each item with which meal type it is primarily for (breakfast/lunch/dinner/snack)
- Spread items across the week — tag forDay with the day the item is first needed

Return ONLY a JSON array:
[
  {"name":"Onion","quantity":"1 kg","category":"vegetables","forMealType":"lunch","forDay":"Monday"},
  {"name":"Toor Dal","quantity":"500g","category":"grains","forMealType":"dinner","forDay":"Monday"}
]

Give 20-35 items covering everything needed. No extra text.
''';

    final response = await _model.generateContent([Content.text(prompt)]);
    final text = response.text ?? '';
    final list = jsonDecode(text) as List<dynamic>;
    int counter = DateTime.now().millisecondsSinceEpoch;
    return list.map((e) {
      final j = e as Map<String, dynamic>;
      return GroceryItem(
        id: (counter++).toString(),
        name: j['name'] as String? ?? '',
        quantity: j['quantity'] as String? ?? '',
        category: j['category'] as String? ?? 'other',
        forMealType: j['forMealType'] as String? ?? 'all',
        forDay: j['forDay'] as String? ?? days.first,
      );
    }).toList();
  }

  // --- Smart Task Planning ---

  Future<SmartPlan> generateSmartPlan({
    required List<TaskItem> tasks,
    required int energyLevel,
    required String dateKey,
    required String dayOfWeek,
  }) async {
    final pending = tasks.where((t) => t.status == 'pending').toList();
    final completed = tasks.where((t) => t.status == 'completed').toList();
    final totalOverdue = pending.where((t) => t.isOverdue).length;
    final completionRate =
        tasks.isEmpty ? 0 : (completed.length * 100 ~/ tasks.length);

    final taskLines = pending.map((t) {
      final dl = t.deadline != null
          ? DateFormat('yyyy-MM-dd').format(t.deadline!)
          : 'no deadline';
      final overdue = t.isOverdue ? ' [OVERDUE]' : '';
      return '- id:"${t.id}" | "${t.name}" | ${t.category} | ${t.estimatedMinutes}min | $dl$overdue | priority: ${t.priority}';
    }).join('\n');

    final currentTime = DateFormat('HH:mm').format(DateTime.now());

    final prompt = '''
You are a smart task planner for an Indian working woman who juggles career, household, and personal life.

Date: $dayOfWeek, $dateKey
Energy level: $energyLevel/5
Current time: $currentTime

Pending tasks:
$taskLines

Behavior summary:
- Total tasks ever: ${tasks.length}
- Completed: ${completed.length}
- Currently overdue: $totalOverdue
- Completion rate: $completionRate%

Rules:
- Categorize EVERY pending task as: focus_now (max 2-3, do immediately), up_next (do today/soon), or later (can wait).
- Consider deadlines, energy level, estimated time, and category.
- Low energy (1-2): only 1-2 small focus_now tasks, rest as up_next or later.
- Overdue tasks should be focus_now unless energy is very low.
- Provide suggestedTime in HH:mm for focus_now and up_next tasks.
- Place deep/hard work in high-energy hours (10:00-12:00), light work in afternoon.
- Give 1-2 short, supportive adaptive suggestions (context-aware, warm tone).
- Calculate realistic insights based on behavior.

Return ONLY this JSON (no extra text):
{
  "tasks": [
    {"taskId": "...", "priority": "focus_now", "reason": "Due tomorrow, fits a quick slot", "suggestedTime": "10:00"}
  ],
  "suggestions": [
    "One supportive suggestion"
  ],
  "insights": {
    "productivityScore": 72,
    "focusedTime": "3h 20m",
    "trend": "improving",
    "topInsight": "One line insight about your patterns"
  }
}
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';
      final json = jsonDecode(text) as Map<String, dynamic>;
      return SmartPlan.fromJson(json);
    } catch (e) {
      return SmartPlan(
        tasks: pending
            .map((t) => SmartTask(
                  taskId: t.id,
                  priority: t.isOverdue ? 'focus_now' : 'up_next',
                  reason: t.isOverdue ? 'Overdue' : 'Pending',
                ))
            .toList(),
        suggestions: ['Could not analyze — showing default order.'],
        insights: PlanInsights(
          productivityScore: completionRate,
          focusedTime: '—',
          trend: 'stable',
          topInsight: 'Add more tasks to see patterns.',
        ),
      );
    }
  }

  DailyTimetable _fallbackTimetable(String date, int energyLevel) {
    final isLow = energyLevel <= 2;
    return DailyTimetable(
      date: date,
      energyLevel: energyLevel,
      slots: [
        TimeSlot(time: '07:00', activity: isLow ? 'Gentle wake-up & tea' : 'Morning skincare & get ready', category: 'selfcare'),
        TimeSlot(time: '08:00', activity: isLow ? 'Light breakfast' : 'Breakfast & pack lunch', category: 'meal'),
        TimeSlot(time: '09:00', activity: 'Commute / Start work', category: 'work'),
        TimeSlot(time: '10:00', activity: isLow ? 'Light tasks & emails' : 'Deep focus work block', category: 'work'),
        TimeSlot(time: '11:00', activity: 'Work continued', category: 'work'),
        TimeSlot(time: '12:00', activity: 'Lunch break', category: 'meal'),
        TimeSlot(time: '13:00', activity: isLow ? 'Easy tasks, no meetings' : 'Meetings & collaboration', category: 'work'),
        TimeSlot(time: '14:00', activity: 'Work continued', category: 'work'),
        TimeSlot(time: '15:00', activity: 'Chai break & stretch', category: 'break'),
        TimeSlot(time: '16:00', activity: isLow ? 'Wrap up & leave early' : 'Finish pending work', category: 'work'),
        TimeSlot(time: '17:00', activity: 'Commute / Errands', category: 'personal'),
        TimeSlot(time: '18:00', activity: isLow ? '15 min walk or rest' : '30 min workout or yoga', category: 'exercise'),
        TimeSlot(time: '19:00', activity: isLow ? 'Order dinner or quick cook' : 'Cook dinner', category: isLow ? 'meal' : 'household'),
        TimeSlot(time: '20:00', activity: 'Dinner & family time', category: 'meal'),
        TimeSlot(time: '21:00', activity: isLow ? 'Rest & light scrolling' : 'Reading or hobby', category: isLow ? 'break' : 'personal'),
        TimeSlot(time: '22:00', activity: 'Night skincare & sleep prep', category: 'selfcare'),
      ],
    );
  }
}
