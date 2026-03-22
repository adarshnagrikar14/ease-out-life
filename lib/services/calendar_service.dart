import 'package:googleapis/calendar/v3.dart' as gcal;
import '../models/timetable_model.dart';
import 'auth_service.dart';

class CalendarService {
  static const _tag = '[EOL] ';

  final AuthService _auth;

  CalendarService(this._auth);

  /// Syncs the full timetable as 1-hour calendar events.
  /// Returns the number of events created, or -1 on failure.
  Future<int> syncTimetable(DailyTimetable timetable) async {
    final api = await _auth.ensureCalendarAccess();
    if (api == null) return -1;

    final date = DateTime.parse(timetable.date);

    await _clearTaggedEvents(api, date);

    int created = 0;
    for (final slot in timetable.slots) {
      final parts = slot.time.split(':');
      final hour = int.parse(parts[0]);
      final minute = parts.length > 1 ? int.parse(parts[1]) : 0;

      final start = DateTime(date.year, date.month, date.day, hour, minute);
      final end = start.add(const Duration(hours: 1));

      final event = gcal.Event()
        ..summary = '$_tag${slot.activity}'
        ..description = slot.category
        ..colorId = _colorId(slot.category)
        ..start = (gcal.EventDateTime()
          ..dateTime = start.toUtc()
          ..timeZone = 'Asia/Kolkata')
        ..end = (gcal.EventDateTime()
          ..dateTime = end.toUtc()
          ..timeZone = 'Asia/Kolkata');

      await api.events.insert(event, 'primary');
      created++;
    }

    return created;
  }

  Future<void> _clearTaggedEvents(gcal.CalendarApi api, DateTime date) async {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    try {
      final existing = await api.events.list(
        'primary',
        timeMin: dayStart.toUtc(),
        timeMax: dayEnd.toUtc(),
        q: _tag.trim(),
        singleEvents: true,
      );

      for (final ev in existing.items ?? []) {
        if (ev.summary != null &&
            ev.summary!.startsWith(_tag) &&
            ev.id != null) {
          await api.events.delete('primary', ev.id!);
        }
      }
    } catch (_) {}
  }

  /// Google Calendar event color IDs (1-11).
  String _colorId(String category) {
    return switch (category) {
      'work' => '9',
      'meal' => '5',
      'exercise' => '10',
      'break' => '3',
      'selfcare' => '4',
      'household' => '6',
      'personal' => '7',
      'health' => '11',
      'learning' => '1',
      _ => '8',
    };
  }
}
