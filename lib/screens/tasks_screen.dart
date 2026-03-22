import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../services/gemini_service.dart';
import '../services/storage_service.dart';
import '../models/task_model.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _gemini = GeminiService();
  final _storage = StorageService();

  List<TaskItem> _tasks = [];
  SmartPlan? _plan;
  bool _loading = false;
  bool _analyzing = false;

  String get _dateKey => DateFormat('yyyy-MM-dd').format(DateTime.now());
  String get _dayOfWeek => DateFormat('EEEE').format(DateTime.now());

  int get _completedToday => _tasks
      .where((t) =>
          t.status == 'completed' &&
          t.completedAt != null &&
          DateFormat('yyyy-MM-dd').format(t.completedAt!) == _dateKey)
      .length;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    _tasks = await _storage.getTasks();
    _plan = await _storage.getSmartPlan(_dateKey);
    if (mounted) setState(() => _loading = false);
    final hasPending = _tasks.any((t) => t.status == 'pending');
    if (hasPending && _plan == null) {
      await _analyze();
    }
  }

  Future<void> _analyze() async {
    if (!_tasks.any((t) => t.status == 'pending')) {
      setState(() => _plan = null);
      return;
    }
    setState(() => _analyzing = true);
    final energyLevel = await _storage.getEnergyLevel();
    try {
      final plan = await _gemini.generateSmartPlan(
        tasks: _tasks,
        energyLevel: energyLevel,
        dateKey: _dateKey,
        dayOfWeek: _dayOfWeek,
      );
      await _storage.saveSmartPlan(plan, _dateKey);
      if (mounted) setState(() => _plan = plan);
    } catch (_) {}
    if (mounted) setState(() => _analyzing = false);
  }

  Future<void> _addTask(TaskItem task) async {
    _tasks.add(task);
    await _storage.saveTasks(_tasks);
    if (mounted) setState(() {});
    await _analyze();
  }

  Future<void> _completeTask(String id) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    _tasks[idx] = _tasks[idx].copyWith(
      status: 'completed',
      completedAt: DateTime.now(),
    );
    await _storage.saveTasks(_tasks);
    if (mounted) setState(() {});
    await _analyze();
  }

  Future<void> _deleteTask(String id) async {
    _tasks.removeWhere((t) => t.id == id);
    await _storage.saveTasks(_tasks);
    if (mounted) setState(() {});
    if (_tasks.any((t) => t.status == 'pending')) {
      await _analyze();
    } else {
      _plan = null;
      if (mounted) setState(() {});
    }
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddTaskSheet(
        onAdd: (task) {
          Navigator.of(ctx).pop();
          _addTask(task);
        },
      ),
    );
  }

  SmartTask? _smartFor(String taskId) {
    if (_plan == null) return null;
    for (final st in _plan!.tasks) {
      if (st.taskId == taskId) return st;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final pending = _tasks.where((t) => t.status == 'pending').toList();

    final focusNow = <TaskItem>[];
    final upNext = <TaskItem>[];
    final later = <TaskItem>[];

    if (_plan != null) {
      final mapped = <String>{};
      for (final st in _plan!.tasks) {
        TaskItem? task;
        for (final t in pending) {
          if (t.id == st.taskId) {
            task = t;
            break;
          }
        }
        if (task == null) continue;
        mapped.add(task.id);
        switch (st.priority) {
          case 'focus_now':
            focusNow.add(task);
          case 'up_next':
            upNext.add(task);
          default:
            later.add(task);
        }
      }
      for (final t in pending) {
        if (!mapped.contains(t.id)) later.add(t);
      }
    } else {
      later.addAll(pending);
    }

    return Stack(
      children: [
        SafeArea(
          child: _loading
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryPurple,
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 16),
                    Expanded(
                      child: pending.isEmpty
                          ? _buildEmptyState()
                          : _buildSections(focusNow, upNext, later),
                    ),
                  ],
                ),
        ),
        Positioned(
          bottom: 16,
          right: 24,
          child: GestureDetector(
            onTap: _showAddSheet,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primaryPurple,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 24),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tasks',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _completedToday > 0
                      ? '$_completedToday done today — keep going'
                      : 'Stay on top of your goals',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              if (_analyzing)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppColors.primaryPurple,
                    ),
                  ),
                ),
              GestureDetector(
                onTap: _analyzing ? null : _analyze,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_outlined,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.checklist_rounded,
              color: AppColors.primaryPurple,
              size: 26,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No tasks yet',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap + to add what\'s on your plate',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSections(
    List<TaskItem> focusNow,
    List<TaskItem> upNext,
    List<TaskItem> later,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 80),
      children: [
        if (_plan != null && _plan!.suggestions.isNotEmpty)
          _buildSuggestionBanner(),
        if (focusNow.isNotEmpty) ...[
          _sectionLabel('Focus now'),
          ...focusNow.map(_buildTaskRow),
        ],
        if (upNext.isNotEmpty) ...[
          _sectionLabel('Up next'),
          ...upNext.map(_buildTaskRow),
        ],
        if (later.isNotEmpty) ...[
          _sectionLabel('Later'),
          ...later.map(_buildTaskRow),
        ],
        if (_plan != null) ...[
          const SizedBox(height: 24),
          _buildInsightsCard(),
        ],
      ],
    );
  }

  Widget _buildSuggestionBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryPurple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.primaryPurple.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.auto_awesome,
            color: AppColors.primaryPurple,
            size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _plan!.suggestions.first,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textHint,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildTaskRow(TaskItem task) {
    final smart = _smartFor(task.id);
    final hasReason = smart != null && smart.reason.isNotEmpty;

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete_outline,
            color: AppColors.error, size: 20),
      ),
      onDismissed: (_) => _deleteTask(task.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => _completeTask(task.id),
              child: Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(top: 2, right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: task.isOverdue
                        ? AppColors.error.withValues(alpha: 0.6)
                        : AppColors.border,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (task.deadline != null) ...[
                        Text(
                          _fmtDeadline(task.deadline!),
                          style: TextStyle(
                            color: task.isOverdue
                                ? AppColors.error
                                : AppColors.textHint,
                            fontSize: 12,
                          ),
                        ),
                        _dot(),
                      ],
                      Text(
                        _fmtDuration(task.estimatedMinutes),
                        style: const TextStyle(
                          color: AppColors.textHint,
                          fontSize: 12,
                        ),
                      ),
                      _dot(),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _catColor(task.category),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        task.category,
                        style: const TextStyle(
                          color: AppColors.textHint,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (hasReason) ...[
                    const SizedBox(height: 3),
                    Text(
                      smart.reason,
                      style: TextStyle(
                        color: AppColors.primaryPurple.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (smart?.suggestedTime != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  smart!.suggestedTime!,
                  style: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dot() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Text('·',
          style: TextStyle(color: AppColors.textHint, fontSize: 12)),
    );
  }

  String _fmtDeadline(DateTime dl) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dl.year, dl.month, dl.day);
    final diff = d.difference(today).inDays;
    if (diff < 0) return 'Overdue';
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return DateFormat('EEE, MMM d').format(dl);
  }

  String _fmtDuration(int min) {
    if (min < 60) return '${min}m';
    final h = min ~/ 60;
    final m = min % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  Color _catColor(String c) {
    return switch (c) {
      'work' => const Color(0xFF60A5FA),
      'personal' => const Color(0xFFFB923C),
      'health' => const Color(0xFFF87171),
      'learning' => const Color(0xFF38BDF8),
      'household' => const Color(0xFFFDA4AF),
      'errands' => const Color(0xFFFBBF24),
      'social' => const Color(0xFFF9A8D4),
      _ => AppColors.textSecondary,
    };
  }

  Widget _buildInsightsCard() {
    final ins = _plan!.insights;
    final trendIcon = switch (ins.trend) {
      'improving' => '↑',
      'declining' => '↓',
      _ => '→',
    };
    final trendColor = switch (ins.trend) {
      'improving' => const Color(0xFF34D399),
      'declining' => AppColors.error,
      _ => AppColors.textSecondary,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _stat('${ins.productivityScore}', 'Score'),
              const SizedBox(width: 24),
              _stat(ins.focusedTime, 'Focused'),
              const SizedBox(width: 24),
              _stat(trendIcon, 'Trend', color: trendColor),
            ],
          ),
          if (ins.topInsight.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              ins.topInsight,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String value, String label, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color ?? AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: AppColors.textHint, fontSize: 11),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Add Task Bottom Sheet
// ---------------------------------------------------------------------------

class _AddTaskSheet extends StatefulWidget {
  final void Function(TaskItem task) onAdd;
  const _AddTaskSheet({required this.onAdd});

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _nameCtrl = TextEditingController();
  DateTime? _deadline;
  int _minutes = 30;
  String _category = 'work';

  static const _durations = [15, 30, 60, 120, 180];
  static const _durLabels = ['15m', '30m', '1h', '2h', '3h+'];
  static const _categories = [
    'work',
    'personal',
    'health',
    'learning',
    'household',
    'errands',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    widget.onAdd(TaskItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      deadline: _deadline,
      estimatedMinutes: _minutes,
      category: _category,
      createdAt: DateTime.now(),
    ));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primaryPurple,
            surface: AppColors.backgroundSecondary,
            onSurface: AppColors.textPrimary,
          ),
          dialogTheme: const DialogThemeData(
            backgroundColor: AppColors.backgroundSecondary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Task name
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 16),
              decoration: const InputDecoration(
                hintText: 'What needs to get done?',
                hintStyle: TextStyle(color: AppColors.textHint),
                filled: true,
                fillColor: AppColors.background,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  borderSide: BorderSide(color: AppColors.primaryPurple),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // When
            _chipRow('When', [
              _deadlineChip('Today', DateTime.now()),
              _deadlineChip(
                  'Tomorrow', DateTime.now().add(const Duration(days: 1))),
              _deadlineChip(
                  'This week', DateTime.now().add(const Duration(days: 7))),
              GestureDetector(
                onTap: _pickDate,
                child: _chip(
                  child: const Icon(Icons.calendar_today_outlined,
                      size: 14, color: AppColors.textSecondary),
                  selected: _deadline != null && !_isPresetDate(_deadline!),
                ),
              ),
            ]),
            const SizedBox(height: 14),

            // Time
            _chipRow(
              'Time',
              List.generate(_durations.length, (i) {
                final sel = _minutes == _durations[i];
                return GestureDetector(
                  onTap: () => setState(() => _minutes = _durations[i]),
                  child: _chip(
                    child: Text(
                      _durLabels[i],
                      style: TextStyle(
                        color:
                            sel ? AppColors.primaryPurple : AppColors.textHint,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    selected: sel,
                  ),
                );
              }),
            ),
            const SizedBox(height: 14),

            // Category
            _chipRow(
              'Type',
              _categories.map((c) {
                final sel = _category == c;
                return GestureDetector(
                  onTap: () => setState(() => _category = c),
                  child: _chip(
                    child: Text(
                      c[0].toUpperCase() + c.substring(1),
                      style: TextStyle(
                        color:
                            sel ? AppColors.primaryPurple : AppColors.textHint,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    selected: sel,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _submit,
                child: const Text('Add task'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipRow(String label, List<Widget> chips) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 4),
        ...chips,
      ],
    );
  }

  Widget _chip({required Widget child, required bool selected}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primaryPurple.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: selected
              ? AppColors.primaryPurple.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: child,
    );
  }

  Widget _deadlineChip(String label, DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    final sel = _deadline != null &&
        DateTime(_deadline!.year, _deadline!.month, _deadline!.day) == target;

    return GestureDetector(
      onTap: () => setState(() => _deadline = target),
      child: _chip(
        child: Text(
          label,
          style: TextStyle(
            color: sel ? AppColors.primaryPurple : AppColors.textHint,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        selected: sel,
      ),
    );
  }

  bool _isPresetDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dd = DateTime(d.year, d.month, d.day);
    final diff = dd.difference(today).inDays;
    return diff == 0 || diff == 1 || diff == 7;
  }
}
