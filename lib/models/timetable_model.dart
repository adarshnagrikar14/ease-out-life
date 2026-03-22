import 'dart:convert';

class TimeSlot {
  final String time;
  final String activity;
  final String category;

  const TimeSlot({
    required this.time,
    required this.activity,
    required this.category,
  });

  Map<String, dynamic> toJson() => {
        'time': time,
        'activity': activity,
        'category': category,
      };

  factory TimeSlot.fromJson(Map<String, dynamic> json) => TimeSlot(
        time: json['time'] as String? ?? '',
        activity: json['activity'] as String? ?? '',
        category: json['category'] as String? ?? 'general',
      );
}

class DailyTimetable {
  final String date;
  final int energyLevel;
  final List<TimeSlot> slots;

  const DailyTimetable({
    required this.date,
    required this.energyLevel,
    required this.slots,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'energyLevel': energyLevel,
        'slots': slots.map((s) => s.toJson()).toList(),
      };

  String encode() => jsonEncode(toJson());

  factory DailyTimetable.fromJson(Map<String, dynamic> json) =>
      DailyTimetable(
        date: json['date'] as String? ?? '',
        energyLevel: json['energyLevel'] as int? ?? 3,
        slots: (json['slots'] as List<dynamic>?)
                ?.map((s) => TimeSlot.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
      );

  factory DailyTimetable.decode(String data) =>
      DailyTimetable.fromJson(jsonDecode(data) as Map<String, dynamic>);
}

class DayFeedback {
  final String date;
  final int rating;
  final String comment;
  final DateTime createdAt;

  const DayFeedback({
    required this.date,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'rating': rating,
        'comment': comment,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DayFeedback.fromJson(Map<String, dynamic> json) => DayFeedback(
        date: json['date'] as String? ?? '',
        rating: json['rating'] as int? ?? 3,
        comment: json['comment'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
