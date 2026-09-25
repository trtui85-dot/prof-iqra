import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../core/supabase.dart';
import '../models/app_user.dart';
import '../models/attendance_log.dart';
import '../models/schedule_entry.dart';
import 'schedule_service.dart';

class WeeklySummary {
  final DateTime start;
  final DateTime end;
  final int present;
  final int late;
  final int absent;
  final int upcoming;
  final int attendedMinutes;
  final int absentMinutes;
  const WeeklySummary({
    required this.start,
    required this.end,
    required this.present,
    required this.late,
    required this.absent,
    required this.upcoming,
    required this.attendedMinutes,
    required this.absentMinutes,
  });

  int get totalMinutes => attendedMinutes + absentMinutes;
}

/// بيانات ملخّص الأستاذ (معلوماته + عدد الحصص والساعات في جدوله).
class TeacherSummary {
  final AppUser teacher;
  final int scheduleCount;
  final int totalMinutes;
  const TeacherSummary({
    required this.teacher,
    required this.scheduleCount,
    required this.totalMinutes,
  });
}

/// تجميع بيانات الملخصات لحساب البطاقة والتقرير (بديل PDF).
class SummaryService {
  static int timeToMin(String hhmm) {
    final p = hhmm.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  static String fmtHoursShort(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m د';
    if (m == 0) return '$h س';
    return '$h س $m د';
  }

  static DateTime mondayOf(DateTime d) => DateTime(d.year, d.month, d.day)
      .subtract(Duration(days: d.weekday - DateTime.monday));

  Future<TeacherSummary> teacherSummary(AppUser teacher) async {
    final schedule = await ScheduleService().listForTeacher(teacher.id);
    var total = 0;
    for (final e in schedule) {
      total += timeToMin(e.endTime) - timeToMin(e.startTime);
    }
    return TeacherSummary(
      teacher: teacher,
      scheduleCount: schedule.length,
      totalMinutes: total,
    );
  }

  /// تجميع الأرقام الأسبوعية (الاثنين..الأحد) مما يخص الأستاذ.
  Future<WeeklySummary> weeklySummary(AppUser teacher, {DateTime? date}) async {
    final dateFmt = DateFormat('yyyy-MM-dd');
    final start = mondayOf(date ?? DateTime.now());
    final end = start.add(const Duration(days: 6));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final logsRes = await db
        .from('attendance_logs')
        .select()
        .eq('teacher_id', teacher.id)
        .gte('entry_date', dateFmt.format(start))
        .lte('entry_date', dateFmt.format(end));
    final schedRes =
        await db.from('schedule').select().eq('teacher_id', teacher.id);

    final logs = logsRes.map(AttendanceLog.fromJson).toList();
    final sched = schedRes.map(ScheduleEntry.fromJson).toList();

    var present = 0, late = 0, absent = 0, upcoming = 0;
    var attendedMinutes = 0, absentMinutes = 0;

    for (var i = 0; i < 7; i++) {
      final day = start.add(Duration(days: i));
      final dayKey = dateFmt.format(day);
      final dayEntries = sched.where((e) => e.dayOfWeek == day.weekday).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      for (final e in dayEntries) {
        final minutes = timeToMin(e.endTime) - timeToMin(e.startTime);
        final log = logs.firstWhereOrNull((l) =>
            l.entryDate == dayKey &&
            (l.scheduleId == e.id ||
                (l.scheduleId == null && l.className == e.className)));
        final String status;
        if (log != null) {
          status = log.status;
        } else if (day.isAfter(today)) {
          status = 'upcoming';
        } else if (day.isAtSameMomentAs(today) && now.isBefore(e.endToday())) {
          status = 'upcoming';
        } else {
          status = 'absent';
        }
        switch (status) {
          case 'present':
            present++;
            attendedMinutes += minutes;
          case 'late':
            late++;
            attendedMinutes += minutes;
          case 'absent':
            absent++;
            absentMinutes += minutes;
          default:
            upcoming++;
        }
      }
    }

    return WeeklySummary(
      start: start,
      end: end,
      present: present,
      late: late,
      absent: absent,
      upcoming: upcoming,
      attendedMinutes: attendedMinutes,
      absentMinutes: absentMinutes,
    );
  }
}

extension _FirstOrNullX<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}

/// التقاط عنصر مرسوم خارج الشاشة كصورة PNG عالية الدقة (دقة 3x).
Future<Uint8List> captureWidget(GlobalKey key) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 3);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}