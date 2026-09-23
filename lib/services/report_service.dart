import 'package:intl/intl.dart';

import '../core/supabase.dart';
import '../models/app_user.dart';
import '../models/attendance_log.dart';
import '../models/schedule_entry.dart';

class ReportRow {
  final AppUser teacher;
  final String className;
  final String startTime;
  final String endTime;
  final String status; // present | late | absent | upcoming
  final DateTime? checkIn;
  final DateTime? checkOut;

  const ReportRow({
    required this.teacher,
    required this.className,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.checkIn,
    this.checkOut,
  });
}

class TeacherSummary {
  final AppUser teacher;
  int scheduled = 0;
  int present = 0;
  int late = 0;
  int absent = 0;

  TeacherSummary(this.teacher);

  double get attendanceRate =>
      scheduled == 0 ? 0 : ((present + late) / scheduled) * 100;
}

class ReportService {
  Future<List<ReportRow>> dailyReport(DateTime date) async {
    final day = DateFormat('yyyy-MM-dd').format(date);
    final weekday = date.weekday;
    final now = DateTime.now();
    final isToday = DateFormat('yyyy-MM-dd').format(now) == day;

    final teachers = await db
        .from('users')
        .select()
        .eq('role', 'teacher')
        .eq('is_active', true);
    final logs = await db
        .from('attendance_logs')
        .select('*, users(name)')
        .eq('entry_date', day);
    final sched =
        await db.from('schedule').select().eq('day_of_week', weekday);

    final rows = <ReportRow>[];
    for (final t in teachers) {
      final teacher = AppUser.fromJson(t);
      final teacherSched =
          sched.where((s) => s['teacher_id'] == teacher.id).cast<Map<String, dynamic>>();
      for (final s in teacherSched) {
        final entry = ScheduleEntry.fromJson(s);
        final log = logs.firstWhereOrNull(
          (l) =>
              l['teacher_id'] == teacher.id &&
              (l['schedule_id'] == entry.id ||
                  (l['schedule_id'] == null && l['class_name'] == entry.className)),
        );
        if (log != null) {
          final att = AttendanceLog.fromJson(log);
          rows.add(ReportRow(
            teacher: teacher,
            className: entry.className,
            startTime: entry.startTime,
            endTime: entry.endTime,
            status: att.status,
            checkIn: att.checkIn,
            checkOut: att.checkOut,
          ));
        } else {
          final timePassed = isToday
              ? now.isAfter(entry.endToday())
              : true;
          rows.add(ReportRow(
            teacher: teacher,
            className: entry.className,
            startTime: entry.startTime,
            endTime: entry.endTime,
            status: timePassed ? 'absent' : 'upcoming',
          ));
        }
      }
    }
    rows.sort((a, b) => (a.startTime).compareTo(b.startTime));
    return rows;
  }

  Future<List<TeacherSummary>> rangeReport(
    DateTime start,
    DateTime end,
  ) async {
    final teachers = await db
        .from('users')
        .select()
        .eq('role', 'teacher')
        .eq('is_active', true);

    final summaries = <String, TeacherSummary>{};
    for (final t in teachers) {
      final teacher = AppUser.fromJson(t);
      summaries[teacher.id] = TeacherSummary(teacher);
    }

    var cursor = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    final now = DateTime.now();
    while (!cursor.isAfter(last)) {
      // فتح الجدول في نفس اليوم مرة واحدة لكل يوم
      final sched = await db
          .from('schedule')
          .select()
          .eq('day_of_week', cursor.weekday);
      if (sched.isNotEmpty) {
        final logs = await db
            .from('attendance_logs')
            .select()
            .eq('entry_date', DateFormat('yyyy-MM-dd').format(cursor));
        final isToday =
            DateFormat('yyyy-MM-dd').format(now) == DateFormat('yyyy-MM-dd').format(cursor);

        for (final s in sched) {
          final tId = s['teacher_id'] as String;
          final summary = summaries[tId];
          if (summary == null) continue;
          summary.scheduled++;
          final entry = ScheduleEntry.fromJson(s);
          final log = logs.firstWhereOrNull(
            (l) =>
                l['teacher_id'] == tId &&
                (l['schedule_id'] == entry.id ||
                    (l['schedule_id'] == null && l['class_name'] == entry.className)),
          );
          if (log != null) {
            final att = AttendanceLog.fromJson(log);
            switch (att.status) {
              case 'present':
                summary.present++;
              case 'late':
                summary.late++;
              default:
                summary.absent++;
            }
          } else {
            final timePassed = isToday ? now.isAfter(entry.endToday()) : true;
            if (timePassed) summary.absent++;
          }
        }
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    final list = summaries.values.toList();
    list.sort((a, b) => a.teacher.name.compareTo(b.teacher.name));
    return list;
  }
}

extension _ListExt<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}