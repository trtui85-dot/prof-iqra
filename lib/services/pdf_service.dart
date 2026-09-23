import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

import '../core/supabase.dart';
import '../core/theme.dart';
import '../models/app_user.dart';
import '../models/attendance_log.dart';
import '../models/schedule_entry.dart';
import 'schedule_service.dart';

/// توليد بطاقة الأستاذ كملف PDF (المعلومات + جدول الحصص الكامل).
/// تُرسم البطاقة بمحرك Flutter نفسه فتظهر العربية مكوّنةً بشكل صحيح،
/// ثم تُلتقط كصورة عالية الدقة وتُدمج في صفحة PDF.
class PdfService {
  static const double _cardWidth = 540;
  static const double _dpr = 3.0;

  Future<Uint8List> teacherProfilePdf(
    BuildContext context,
    AppUser teacher,
  ) async {
    await GoogleFonts.pendingFonts();
    if (!context.mounted) throw Exception('context disposed');
    final schedule = await ScheduleService().listForTeacher(teacher.id);
    if (!context.mounted) throw Exception('context disposed');
    final card = _buildTeacherCard(teacher, schedule);
    return _toPdf(context, card, '${teacher.name} — بطاقة الأستاذ');
  }

  /// تقرير أسبوعي للأستاذ (ورقة A4): ملخص الحضور والغياب
  /// وعددها + ساعات حضور الحصص ومجموعها + ساعات الغياب ومجموعها.
  Future<Uint8List> teacherWeeklyReportPdf(
    BuildContext context,
    AppUser teacher, {
    DateTime? date,
  }) async {
    await GoogleFonts.pendingFonts();
    if (!context.mounted) throw Exception('context disposed');
    final data = await _weeklyData(teacher, date ?? DateTime.now());
    if (!context.mounted) throw Exception('context disposed');
    final card = _buildWeeklyReport(teacher, data);
    return _toPdf(context, card, '${teacher.name} — تقرير الحضور الأسبوعي');
  }

  Future<Uint8List> _toPdf(BuildContext context, Widget card, String title) async {
    if (!context.mounted) throw Exception('context disposed');
    final rendered = await _capture(context, card);

    final bytes = rendered.bytes;
    final logical = rendered.logicalSize;
    final wPt = logical.width * _dpr;
    final hPt = logical.height * _dpr;

    const margin = 24.0;
    final pageW = PdfPageFormat.a4.width - margin * 2;
    final pageH = PdfPageFormat.a4.height - margin * 2;
    final scale = (pageW / wPt < pageH / hPt)
        ? pageW / wPt
        : pageH / hPt;
    final w = wPt * scale;
    final h = hPt * scale;

    final doc = pw.Document(title: title);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(margin),
        build: (_) => pw.Center(
          child: pw.Image(pw.MemoryImage(bytes), width: w, height: h),
        ),
      ),
    );
    return doc.save();
  }

  Widget _buildTeacherCard(AppUser teacher, List<ScheduleEntry> schedule) {
    final totalMinutes =
        schedule.fold<int>(0, (sum, e) => sum + _timeToMin(e.endTime) - _timeToMin(e.startTime));

    final today = DateFormat('yyyy/MM/dd').format(DateTime.now());

    Row headerLine(IconData icon, String label, String value) => Row(children: [
          Icon(icon, size: 15, color: AppColors.primaryLight),
          const SizedBox(width: 8),
          Text('$label: ', style: AppText.bold(13).copyWith(color: AppColors.textDark)),
          Expanded(
            child: Text(value,
                style: AppText.normal(13),
                textAlign: TextAlign.end),
          ),
        ]);

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Material(
        color: Colors.white,
        child: Container(
          width: _cardWidth,
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.primary, width: 1.5),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Text('أ',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('أساتذة اقرأ',
                          style: AppText.bold(15).copyWith(color: AppColors.primary)),
                      Text('بطاقة الأستاذ — $today',
                          style: AppText.muted(11)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(color: AppColors.border),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      teacher.name.isNotEmpty ? teacher.name[0] : '?',
                      style: AppText.heading(24).copyWith(color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(teacher.name, style: AppText.heading(19)),
                        const SizedBox(height: 4),
                        Text(teacher.phone, style: AppText.muted(13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              headerLine(Icons.menu_book_outlined, 'المادة', teacher.subject ?? '—'),
              const SizedBox(height: 8),
              headerLine(Icons.class_outlined, 'الأقسام', teacher.section ?? '—'),
              const SizedBox(height: 16),
              Divider(color: AppColors.border),
              const SizedBox(height: 8),
              Text('الجدول الأسبوعي للحصص',
                  style: AppText.bold(15).copyWith(color: AppColors.primary)),
              const SizedBox(height: 10),
              if (schedule.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('لا توجد حصص مجدولة بعد.',
                      style: AppText.muted(13)),
                )
              else
                ..._scheduleTable(schedule),
              const SizedBox(height: 12),
              Divider(color: AppColors.border),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('إجمالي الحصص الأسبوعية: ${schedule.length} حصة',
                      style: AppText.bold(13)),
                  Text(_fmtDuration(totalMinutes),
                      style: AppText.muted(12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _scheduleTable(List<ScheduleEntry> schedule) {
    final byDay = <int, List<ScheduleEntry>>{};
    for (final e in schedule) {
      byDay.putIfAbsent(e.dayOfWeek, () => []).add(e);
    }
    const order = {1: 0, 2: 1, 3: 2, 4: 3, 5: 4, 6: 5, 7: 6};
    final days = byDay.keys.toList()
      ..sort((a, b) => order[a]!.compareTo(order[b]!));

    final rows = <Widget>[];
    for (final d in days) {
      rows.add(Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(ScheduleEntry.dayNames[d] ?? '',
                style: AppText.bold(12.5).copyWith(color: AppColors.primary)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(color: AppColors.border),
          ),
        ]),
      ));
      final dayEntries = byDay[d]!;
      for (final e in dayEntries) {
        rows.add(Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          margin: const EdgeInsets.only(bottom: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text('${e.startTime} – ${e.endTime}',
                  style: AppText.white(11.5)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(e.className, style: AppText.bold(13)),
            ),
          ]),
        ));
      }
    }
    return rows;
  }

  static int _timeToMin(String hhmm) {
    final p = hhmm.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  static String _fmtDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final parts = <String>[];
    if (h > 0) parts.add('$h ساعة');
    if (m > 0) parts.add('$m دقيقة');
    return parts.isEmpty ? '0 دقيقة' : parts.join(' و');
  }

  static String _fmtHoursShort(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m د';
    if (m == 0) return '$h س';
    return '$h س $m د';
  }

  static DateTime _mondayOf(DateTime d) => DateTime(d.year, d.month, d.day)
      .subtract(Duration(days: d.weekday - DateTime.monday));

  /// جمع بيانات الأسبوع (الاثنين..الأحد) للأستاذ: كل حصة وحالتها وساعاتها.
  Future<_WeekReport> _weeklyData(AppUser teacher, DateTime date) async {
    final start = _mondayOf(date);
    final end = start.add(const Duration(days: 6));
    final dayFmt = DateFormat('yyyy-MM-dd');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final logsRes = await db
        .from('attendance_logs')
        .select()
        .eq('teacher_id', teacher.id)
        .gte('entry_date', dayFmt.format(start))
        .lte('entry_date', dayFmt.format(end));
    final schedRes =
        await db.from('schedule').select().eq('teacher_id', teacher.id);

    final logs = logsRes.map(AttendanceLog.fromJson).toList();
    final sched = schedRes.map(ScheduleEntry.fromJson).toList();

    final items = <_WeekItem>[];
    for (var i = 0; i < 7; i++) {
      final day = start.add(Duration(days: i));
      final wd = day.weekday;
      final dayEntries = sched.where((e) => e.dayOfWeek == wd).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      for (final e in dayEntries) {
        final dayKey = dayFmt.format(day);
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
        items.add(_WeekItem(
          day: wd,
          startTime: e.startTime,
          endTime: e.endTime,
          className: e.className,
          status: status,
          minutes: _timeToMin(e.endTime) - _timeToMin(e.startTime),
        ));
      }
    }

    var present = 0, late = 0, absent = 0, upcoming = 0;
    var attendedMin = 0, absentMin = 0;
    for (final it in items) {
      switch (it.status) {
        case 'present':
          present++;
          attendedMin += it.minutes;
        case 'late':
          late++;
          attendedMin += it.minutes;
        case 'absent':
          absent++;
          absentMin += it.minutes;
        default:
          upcoming++;
      }
    }
    return _WeekReport(start, end, items, present, late, absent, upcoming,
        attendedMin, absentMin);
  }

  Widget _buildWeeklyReport(AppUser teacher, _WeekReport r) {
    final dateFmt = DateFormat('yyyy/MM/dd');
    final byDay = <int, List<_WeekItem>>{};
    for (final it in r.items) {
      byDay.putIfAbsent(it.day, () => []).add(it);
    }
    final days = byDay.keys.toList()..sort();

    final bgGreen = AppColors.presentSoft;
    final fgGreen = AppColors.present;
    final bgAmber = AppColors.lateSoft;
    final fgAmber = AppColors.late;
    final bgRed = AppColors.absentSoft;
    final fgRed = AppColors.absent;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Material(
        color: Colors.white,
        child: Container(
          width: _cardWidth,
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.primary, width: 1.5),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Text('أ',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('أساتذة اقرأ',
                        style: AppText.bold(15)
                            .copyWith(color: AppColors.primary)),
                    Text(
                      'الأسبوع من ${dateFmt.format(r.start)} إلى ${dateFmt.format(r.end)}',
                      style: AppText.muted(11),
                    ),
                  ],
                ),
              ]),
              const SizedBox(height: 10),
              Divider(color: AppColors.border),
              const SizedBox(height: 10),
              Text('تقرير الحضور الأسبوعي',
                  style: AppText.heading(17)
                      .copyWith(color: AppColors.primary)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Text('الأستاذ: ${teacher.name}',
                    style: AppText.bold(14))),
                Text(teacher.phone, style: AppText.muted(13)),
              ]),
              const SizedBox(height: 4),
              Text(
                'المادة: ${teacher.subject ?? '—'}   |   الأقسام: ${teacher.section ?? '—'}',
                style: AppText.muted(13),
              ),
              const SizedBox(height: 14),
              Text('ملخص الحضور والغياب',
                  style: AppText.bold(14).copyWith(color: AppColors.primary)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: _statBox(
                        'حاضِر', '${r.present}', bgGreen, fgGreen, Icons.check_circle_outline)),
                const SizedBox(width: 8),
                Expanded(
                    child: _statBox(
                        'متأخِر', '${r.late}', bgAmber, fgAmber, Icons.schedule)),
                const SizedBox(width: 8),
                Expanded(
                    child: _statBox('غائب', '${r.absent}', bgRed, fgRed,
                        Icons.cancel_outlined)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: _statBox(
                        'ساعات الحضور',
                        _fmtHoursShort(r.attendedMinutes),
                        bgGreen,
                        fgGreen,
                        Icons.timer_outlined)),
                const SizedBox(width: 8),
                Expanded(
                    child: _statBox(
                        'ساعات الغياب',
                        _fmtHoursShort(r.absentMinutes),
                        bgRed,
                        fgRed,
                        Icons.timer_off_outlined)),
                const SizedBox(width: 8),
                Expanded(
                    child: _statBox(
                        'إجمالي الساعات',
                        _fmtHoursShort(r.totalMinutes),
                        AppColors.primarySoft,
                        AppColors.primary,
                        Icons.access_time_rounded)),
              ]),
              const SizedBox(height: 14),
              Divider(color: AppColors.border),
              const SizedBox(height: 6),
              Text('تفاصيل الحصص',
                  style: AppText.bold(14).copyWith(color: AppColors.primary)),
              if (r.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('لا توجد حصص مجدولة هذا الأسبوع.',
                      style: AppText.muted(13)),
                )
              else
                ..._weeklyDetails(days, byDay),
              const SizedBox(height: 8),
              Divider(color: AppColors.border),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'إجمالي حصص الحضور: ${r.present + r.late}   |   حصص الغياب: ${r.absent}',
                    style: AppText.bold(12.5),
                  ),
                  Text('مجموع الساعات: ${_fmtHoursShort(r.totalMinutes)}',
                      style: AppText.muted(12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statBox(
      String label, String value, Color bg, Color fg, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: .35)),
      ),
      child: Column(
        children: [
          Icon(icon, color: fg, size: 17),
          const SizedBox(height: 5),
          Text(value, style: AppText.heading(16).copyWith(color: fg)),
          const SizedBox(height: 2),
          Text(label, style: AppText.muted(10.5)),
        ],
      ),
    );
  }

  List<Widget> _weeklyDetails(
      List<int> days, Map<int, List<_WeekItem>> byDay) {
    final rows = <Widget>[];
    for (final d in days) {
      final items = byDay[d]!;
      rows.add(Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(ScheduleEntry.dayNames[d] ?? '',
                style: AppText.bold(12.5).copyWith(color: AppColors.primary)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: AppColors.border)),
        ]),
      ));
      for (final it in items) {
        final (bg, fg, label) = switch (it.status) {
          'present' => (AppColors.presentSoft, AppColors.present, 'حاضر'),
          'late' => (AppColors.lateSoft, AppColors.late, 'متأخر'),
          'absent' => (AppColors.absentSoft, AppColors.absent, 'غائب'),
          _ => (AppColors.primarySoft, AppColors.primary, 'قادمة'),
        };
        rows.add(Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          margin: const EdgeInsets.only(bottom: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text('${it.startTime} – ${it.endTime}',
                  style: AppText.white(11.5)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(it.className, style: AppText.bold(13))),
            Text(_fmtHoursShort(it.minutes),
                style: AppText.muted(11.5)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(label, style: AppText.bold(11).copyWith(color: fg)),
            ),
          ]),
        ));
      }
    }
    return rows;
  }

  /// التقط محتوى الـ Widget كصورة PNG عبر عرضه خارج الشاشة في الـ Overlay.
  Future<_Rendered> _capture(BuildContext context, Widget child) async {
    final key = GlobalKey();
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -100000,
        top: 0,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 0,
          minHeight: 0,
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: RepaintBoundary(key: key, child: child),
        ),
      ),
    );
    overlay.insert(entry);
    try {
      await Future.delayed(const Duration(milliseconds: 150));
      await WidgetsBinding.instance.endOfFrame;
      final boundary = key.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final size = boundary.size;
      final image = await boundary.toImage(pixelRatio: _dpr);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return _Rendered(data!.buffer.asUint8List(), size);
    } finally {
      entry.remove();
    }
  }
}

class _Rendered {
  final Uint8List bytes;
  final Size logicalSize;
  const _Rendered(this.bytes, this.logicalSize);
}

class _WeekItem {
  final int day; // 1 = الاثنين .. 7 = الأحد
  final String startTime;
  final String endTime;
  final String className;
  final String status; // present | late | absent | upcoming
  final int minutes;

  const _WeekItem({
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.className,
    required this.status,
    required this.minutes,
  });
}

class _WeekReport {
  final DateTime start;
  final DateTime end;
  final List<_WeekItem> items;
  final int present;
  final int late;
  final int absent;
  final int upcoming;
  final int attendedMinutes;
  final int absentMinutes;

  const _WeekReport(
    this.start,
    this.end,
    this.items,
    this.present,
    this.late,
    this.absent,
    this.upcoming,
    this.attendedMinutes,
    this.absentMinutes,
  );

  int get totalMinutes => attendedMinutes + absentMinutes;
}

extension _FirstOrNullX<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}