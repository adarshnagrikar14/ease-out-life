class TaskItem {
  final String id;
  final String name;
  final DateTime? deadline;
  final String priority;
  final int estimatedMinutes;
  final String category;
  final String status;
  final DateTime createdAt;
  final DateTime? completedAt;

  TaskItem({
    required this.id,
    required this.name,
    this.deadline,
    this.priority = 'auto',
    this.estimatedMinutes = 30,
    this.category = 'work',
    this.status = 'pending',
    required this.createdAt,
    this.completedAt,
  });

  bool get isOverdue =>
      deadline != null &&
      deadline!.isBefore(DateTime.now()) &&
      status == 'pending';

  TaskItem copyWith({
    String? id,
    String? name,
    DateTime? deadline,
    bool clearDeadline = false,
    String? priority,
    int? estimatedMinutes,
    String? category,
    String? status,
    DateTime? createdAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return TaskItem(
      id: id ?? this.id,
      name: name ?? this.name,
      deadline: clearDeadline ? null : (deadline ?? this.deadline),
      priority: priority ?? this.priority,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      category: category ?? this.category,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt:
          clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'deadline': deadline?.toIso8601String(),
        'priority': priority,
        'estimatedMinutes': estimatedMinutes,
        'category': category,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };

  factory TaskItem.fromJson(Map<String, dynamic> j) => TaskItem(
        id: j['id'] as String,
        name: j['name'] as String,
        deadline: j['deadline'] != null
            ? DateTime.parse(j['deadline'] as String)
            : null,
        priority: j['priority'] as String? ?? 'auto',
        estimatedMinutes: j['estimatedMinutes'] as int? ?? 30,
        category: j['category'] as String? ?? 'work',
        status: j['status'] as String? ?? 'pending',
        createdAt: DateTime.parse(j['createdAt'] as String),
        completedAt: j['completedAt'] != null
            ? DateTime.parse(j['completedAt'] as String)
            : null,
      );
}

class SmartPlan {
  final List<SmartTask> tasks;
  final List<String> suggestions;
  final PlanInsights insights;

  SmartPlan({
    required this.tasks,
    required this.suggestions,
    required this.insights,
  });

  factory SmartPlan.fromJson(Map<String, dynamic> json) {
    final tasksJson = json['tasks'] as List<dynamic>? ?? [];
    final suggestionsJson = json['suggestions'] as List<dynamic>? ?? [];
    return SmartPlan(
      tasks: tasksJson
          .map((t) => SmartTask.fromJson(t as Map<String, dynamic>))
          .toList(),
      suggestions: suggestionsJson.map((s) => s.toString()).toList(),
      insights: PlanInsights.fromJson(
          json['insights'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'suggestions': suggestions,
        'insights': insights.toJson(),
      };
}

class SmartTask {
  final String taskId;
  final String priority;
  final String reason;
  final String? suggestedTime;

  SmartTask({
    required this.taskId,
    required this.priority,
    required this.reason,
    this.suggestedTime,
  });

  factory SmartTask.fromJson(Map<String, dynamic> j) => SmartTask(
        taskId: j['taskId'] as String,
        priority: j['priority'] as String? ?? 'later',
        reason: j['reason'] as String? ?? '',
        suggestedTime: j['suggestedTime'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'taskId': taskId,
        'priority': priority,
        'reason': reason,
        'suggestedTime': suggestedTime,
      };
}

class PlanInsights {
  final int productivityScore;
  final String focusedTime;
  final String trend;
  final String topInsight;

  PlanInsights({
    this.productivityScore = 0,
    this.focusedTime = '0h',
    this.trend = 'stable',
    this.topInsight = '',
  });

  factory PlanInsights.fromJson(Map<String, dynamic> j) => PlanInsights(
        productivityScore: (j['productivityScore'] as num?)?.toInt() ?? 0,
        focusedTime: j['focusedTime'] as String? ?? '0h',
        trend: j['trend'] as String? ?? 'stable',
        topInsight: j['topInsight'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'productivityScore': productivityScore,
        'focusedTime': focusedTime,
        'trend': trend,
        'topInsight': topInsight,
      };
}
