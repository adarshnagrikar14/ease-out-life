import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../services/auth_service.dart';
import '../services/gemini_service.dart';
import '../services/storage_service.dart';
import '../services/calendar_service.dart';
import '../models/timetable_model.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _geminiService = GeminiService();
  final _storageService = StorageService();
  late final CalendarService _calendarService;

  DateTime _selectedDate = DateTime.now();
  int _energyLevel = 3;
  DailyTimetable? _timetable;
  bool _loading = false;
  bool _feedbackSubmitted = false;
  bool _syncing = false;

  int _feedbackRating = 3;
  final _feedbackController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _calendarService = CalendarService(_authService);
    _init();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    _editActivityController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _energyLevel = await _storageService.getEnergyLevel();
    await _loadTimetable();
  }

  String get _dateKey => DateFormat('yyyy-MM-dd').format(_selectedDate);
  String get _dayOfWeek => DateFormat('EEEE').format(_selectedDate);
  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  Future<void> _loadTimetable() async {
    setState(() => _loading = true);
    _feedbackSubmitted = false;

    final cached = await _storageService.getTimetable(_dateKey);
    if (cached != null) {
      setState(() {
        _timetable = cached;
        _energyLevel = cached.energyLevel;
        _loading = false;
      });
      return;
    }

    await _generateTimetable();
  }

  Future<void> _generateTimetable() async {
    setState(() => _loading = true);

    final feedback = await _storageService.getFeedbackHistory();
    final timetable = await _geminiService.generateTimetable(
      date: _dateKey,
      dayOfWeek: _dayOfWeek,
      energyLevel: _energyLevel,
      feedbackHistory: feedback,
    );

    await _storageService.saveTimetable(timetable);

    if (mounted) {
      setState(() {
        _timetable = timetable;
        _loading = false;
      });
    }
  }

  Future<void> _onEnergyChanged(int level) async {
    setState(() => _energyLevel = level);
    await _storageService.saveEnergyLevel(level);
    await _generateTimetable();
  }

  Future<void> _submitFeedback() async {
    final feedback = DayFeedback(
      date: _dateKey,
      rating: _feedbackRating,
      comment: _feedbackController.text.trim(),
      createdAt: DateTime.now(),
    );
    await _storageService.saveFeedback(feedback);
    _feedbackController.clear();
    setState(() => _feedbackSubmitted = true);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
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
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      await _loadTimetable();
    }
  }

  Future<void> _syncToCalendar() async {
    if (_timetable == null || _syncing) return;
    setState(() => _syncing = true);

    try {
      final count = await _calendarService.syncTimetable(_timetable!);
      if (!mounted) return;

      if (count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count events synced to Google Calendar'),
            backgroundColor: const Color(0xFF34D399),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (count == -1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Calendar access not granted. Sign in with Google first.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: ${e.toString().length > 60 ? '${e.toString().substring(0, 60)}...' : e}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isToday
                              ? 'Today'
                              : DateFormat('EEE, MMM d').format(_selectedDate),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.displayName != null
                              ? 'Hey ${user!.displayName!.split(' ').first}, you\'ve got this'
                              : 'Hey, you\'ve got this',
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
                      _iconButton(
                        Icons.calendar_today_outlined,
                        onTap: _pickDate,
                      ),
                      const SizedBox(width: 10),
                      _syncing
                          ? Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primaryPurple
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.primaryPurple
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: AppColors.primaryPurple,
                                  ),
                                ),
                              ),
                            )
                          : _iconButton(
                              Icons.sync_outlined,
                              onTap: _timetable != null
                                  ? _syncToCalendar
                                  : () {},
                            ),
                      const SizedBox(width: 10),
                      _iconButton(
                        Icons.logout_outlined,
                        onTap: () =>
                            _showLogoutDialog(context, _authService),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Energy level selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildEnergySelector(),
            ),

            const SizedBox(height: 16),

            // Timetable
            Expanded(
              child: _loading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryPurple,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Crafting your day...',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _buildTimetableList(),
            ),
          ],
        ),
    );
  }

  Widget _iconButton(IconData icon, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, color: AppColors.textSecondary, size: 18),
      ),
    );
  }

  Widget _buildEnergySelector() {
    const labels = ['1', '2', '3', '4', '5'];
    const descriptions = [
      'Drained',
      'Tired',
      'Steady',
      'Energised',
      'Supercharged',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Energy level',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              descriptions[_energyLevel - 1],
              style: const TextStyle(
                color: AppColors.primaryPurple,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(5, (i) {
            final level = i + 1;
            final selected = level <= _energyLevel;
            return Expanded(
              child: GestureDetector(
                onTap: _loading ? null : () => _onEnergyChanged(level),
                child: Container(
                  height: 36,
                  margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primaryPurple.withValues(alpha: 0.15)
                        : AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected
                          ? AppColors.primaryPurple.withValues(alpha: 0.4)
                          : AppColors.border,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        color: selected
                            ? AppColors.primaryPurple
                            : AppColors.textHint,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  int? _editingIndex;
  final _editActivityController = TextEditingController();
  String _editCategory = 'general';

  Future<void> _saveSlotEdit(int index) async {
    if (_timetable == null) return;
    final slots = List<TimeSlot>.from(_timetable!.slots);
    slots[index] = TimeSlot(
      time: slots[index].time,
      activity: _editActivityController.text.trim().isEmpty
          ? slots[index].activity
          : _editActivityController.text.trim(),
      category: _editCategory,
    );
    final updated = DailyTimetable(
      date: _timetable!.date,
      energyLevel: _timetable!.energyLevel,
      slots: slots,
    );
    await _storageService.saveTimetable(updated);
    setState(() {
      _timetable = updated;
      _editingIndex = null;
    });
  }

  void _startEditing(int index) {
    final slot = _timetable!.slots[index];
    _editActivityController.text = slot.activity;
    _editCategory = slot.category;
    setState(() => _editingIndex = index);
  }

  Widget _buildTimetableList() {
    final slots = _timetable?.slots ?? [];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: slots.length + 1,
      itemBuilder: (context, index) {
        if (index == slots.length) return _buildFeedbackSection();
        return _buildSlotRow(slots[index], index);
      },
    );
  }

  Widget _buildSlotRow(TimeSlot slot, int index) {
    final isEditing = _editingIndex == index;

    if (isEditing) {
      return _buildEditRow(slot, index);
    }

    return GestureDetector(
      onTap: () => _startEditing(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Text(
                slot.time,
                style: const TextStyle(
                  color: AppColors.textHint,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: _categoryColor(slot.category),
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Text(
                slot.activity,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditRow(TimeSlot slot, int index) {
    const categories = [
      'work', 'meal', 'exercise', 'break', 'selfcare', 'household', 'personal', 'health', 'learning'
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  slot.time,
                  style: const TextStyle(
                    color: AppColors.primaryPurple,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _editActivityController,
                  autofocus: true,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    filled: true,
                    fillColor: AppColors.backgroundSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                      borderSide:
                          BorderSide(color: AppColors.primaryPurple, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                      borderSide:
                          BorderSide(color: AppColors.primaryPurple, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                      borderSide:
                          BorderSide(color: AppColors.primaryPurple, width: 1),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 44),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: categories.map((c) {
                      final selected = _editCategory == c;
                      return GestureDetector(
                        onTap: () => setState(() => _editCategory = c),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: selected
                                ? _categoryColor(c).withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: selected
                                  ? _categoryColor(c).withValues(alpha: 0.5)
                                  : AppColors.border,
                            ),
                          ),
                          child: Text(
                            c,
                            style: TextStyle(
                              color:
                                  selected ? _categoryColor(c) : AppColors.textHint,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 44),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _editingIndex = null),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => _saveSlotEdit(index),
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      color: AppColors.primaryPurple,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Color _categoryColor(String category) {
    return switch (category) {
      'work' => const Color(0xFF60A5FA),
      'meal' => const Color(0xFFFBBF24),
      'exercise' => const Color(0xFF34D399),
      'break' => const Color(0xFFA78BFA),
      'selfcare' => const Color(0xFFF9A8D4),
      'household' => const Color(0xFFFDA4AF),
      'health' => const Color(0xFFF87171),
      'learning' => const Color(0xFF38BDF8),
      'personal' => const Color(0xFFFB923C),
      _ => AppColors.textSecondary,
    };
  }

  Widget _buildFeedbackSection() {
    if (_feedbackSubmitted) {
      return Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 40),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primaryPurple.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: AppColors.primaryPurple.withValues(alpha: 0.2)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline,
                  color: AppColors.primaryPurple, size: 18),
              SizedBox(width: 8),
              Text(
                'Noted! Tomorrow\'s plan will be even better.',
                style: TextStyle(
                  color: AppColors.primaryPurple,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 1,
            color: AppColors.border,
          ),
          const SizedBox(height: 20),
          const Text(
            'How did today feel?',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your feedback helps me plan a better tomorrow for you.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),

          // Rating
          Row(
            children: List.generate(5, (i) {
              final level = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _feedbackRating = level),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    level <= _feedbackRating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: level <= _feedbackRating
                        ? AppColors.primaryPurple
                        : AppColors.textHint,
                    size: 28,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),

          // Comment
          TextFormField(
            controller: _feedbackController,
            maxLines: 2,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
            decoration: const InputDecoration(
              hintText: 'What worked? What didn\'t?',
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 14),

          SizedBox(
            height: 42,
            child: ElevatedButton(
              onPressed: _submitFeedback,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 42),
                textStyle: const TextStyle(fontSize: 13),
              ),
              child: const Text('Submit feedback'),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Sign out',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 17),
        ),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await authService.signOut();
              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              }
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
