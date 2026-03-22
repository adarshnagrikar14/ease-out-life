import 'dart:convert';

class MealEntry {
  final String id;
  final String name;
  final String mealType;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double sodium;
  final String servingSize;
  final String source;
  final DateTime timestamp;

  const MealEntry({
    required this.id,
    required this.name,
    required this.mealType,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.sugar,
    required this.sodium,
    required this.servingSize,
    required this.source,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mealType': mealType,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
        'sugar': sugar,
        'sodium': sodium,
        'servingSize': servingSize,
        'source': source,
        'timestamp': timestamp.toIso8601String(),
      };

  factory MealEntry.fromJson(Map<String, dynamic> j) => MealEntry(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? 'Unknown',
        mealType: j['mealType'] as String? ?? 'snack',
        calories: (j['calories'] as num?)?.toDouble() ?? 0,
        protein: (j['protein'] as num?)?.toDouble() ?? 0,
        carbs: (j['carbs'] as num?)?.toDouble() ?? 0,
        fat: (j['fat'] as num?)?.toDouble() ?? 0,
        fiber: (j['fiber'] as num?)?.toDouble() ?? 0,
        sugar: (j['sugar'] as num?)?.toDouble() ?? 0,
        sodium: (j['sodium'] as num?)?.toDouble() ?? 0,
        servingSize: j['servingSize'] as String? ?? '1 serving',
        source: j['source'] as String? ?? 'manual',
        timestamp: DateTime.tryParse(j['timestamp'] as String? ?? '') ??
            DateTime.now(),
      );

  String encode() => jsonEncode(toJson());
  factory MealEntry.decode(String data) =>
      MealEntry.fromJson(jsonDecode(data) as Map<String, dynamic>);
}
