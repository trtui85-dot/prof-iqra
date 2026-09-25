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

/// عنصر داخل نطاق التقرير (حصة واحدة بحالتها).
class ReportItem {
  final DateTime day;
  final String startTime;
  final String endTime;
  final String className;
  final String status; // present | late | absent | upcoming
  final int minutes;
  const ReportItem({
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.className,
    required this.status,
    required this.minutes,
  });
}

/// ملخّص نطاق زمني (يومي / أسبوعي / شهري) مع الحصص الكاملة.
class RangeSummary {
  final DateTime start;
  final DateTime end;
  final List<ReportItem> items;
  final int present;
  final int late;
  final int absent;
  final int upcoming;
  final int attendedMinutes;
  final int absentMinutes;
  const RangeSummary({
    required this.start,
    required this.end,
    required this.items,
    required this.present,
    required this.late,
    required this.absent,
    required this.upcoming,
    required this.attendedMinutes,
    required this.absentMinutes,
  });

  int get totalMinutes => attendedMinutes + absentMinutes;
  int get totalClasses => items.length;
}

/// بيانات بطاقة الأستاذ: معلوماته + جدوله الكامل.
class TeacherSummary {
  final AppUser teacher;
  final List<ScheduleEntry> schedule;
  const TeacherSummary({required this.teacher, required this.schedule});

  int get scheduleCount => schedule.length;
  int get totalMinutes {
    var t = 0;
    for (final e in schedule) {
      t += SummaryService.timeToMin(e.endTime) - SummaryService.timeToMin(e.startTime);
    }
    return t;
  }
}

/// أنواع التقارير المتاحة.
enum ReportRange { daily, weekly, monthly }

extension ReportRangeX on ReportRange {
  String get label => switch (this) {
        ReportRange.daily => 'التقرير اليومي',
        ReportRange.weekly => 'التقرير الأسبوعي',
        ReportRange.monthly => 'التقرير الشهري',
      };
  String get fileName => switch (this) {
        ReportRange.daily => 'iqra-daily-report',
        ReportRange.weekly => 'iqra-weekly-report',
        ReportRange.monthly => 'iqra-monthly-report',
      };
}

/// تجميع بيانات الملخصات (البطاقة والتقارير).
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

  /// نطاق اليوم الحالي.
  static (DateTime, DateTime) todayRange() {
    final n = DateTime.now();
    final d = DateTime(n.year, n.month, n.day);
    return (d, d);
  }

  /// نطاق الأسبوع الحالي (الاثنين..الأحد).
  static (DateTime, DateTime) weekRange() {
    final n = DateTime.now();
    final monday = mondayOf(n);
    return (monday, monday.add(const Duration(days: 6)));
  }

  /// نطاق الشهر الحالي.
  static (DateTime, DateTime) monthRange() {
    final n = DateTime.now();
    final first = DateTime(n.year, n.month, 1);
    final last = DateTime(n.year, n.month + 1, 0);
    return (first, last);
  }

  Future<TeacherSummary> teacherSummary(AppUser teacher) async {
    final schedule = await ScheduleService().listForTeacher(teacher.id);
    return TeacherSummary(teacher: teacher, schedule: schedule);
  }

  /// تجميع حصص ونطاق زمني مع حالتها (حضور/تأخر/غياب/قادمة).
  Future<RangeSummary> rangeSummary(AppUser teacher, DateTime start, DateTime end) async {
    final dateFmt = DateFormat('yyyy-MM-dd');
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

    final items = <ReportItem>[];
    for (var i = 0; i <= end.difference(start).inDays; i++) {
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
        items.add(ReportItem(
          day: day,
          startTime: e.startTime,
          endTime: e.endTime,
          className: e.className,
          status: status,
          minutes: minutes,
        ));
      }
    }

    var present = 0, late = 0, absent = 0, upcoming = 0;
    var attendedMinutes = 0, absentMinutes = 0;
    for (final it in items) {
      switch (it.status) {
        case 'present':
          present++;
          attendedMinutes += it.minutes;
        case 'late':
          late++;
          attendedMinutes += it.minutes;
        case 'absent':
          absent++;
          absentMinutes += it.minutes;
        default:
          upcoming++;
      }
    }
    return RangeSummary(
      start: start,
      end: end,
      items: items,
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

/// التقاط عنصر كصورة PNG عالية الدقة (دقة 3x).
Future<Uint8List> captureWidget(GlobalKey key) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 3);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}