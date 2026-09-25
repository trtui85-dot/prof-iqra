import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../models/app_user.dart';
import '../models/schedule_entry.dart';
import '../services/summary_service.dart';

/// المقاسات: صورة أفقية (Landscape) مريحة ومشبعة.
const double kSummaryWidth = 960;
const double kSummaryHeight = 600;

Widget _brandRow(String title, String subtitle) {
  return Row(children: [
    Container(
      width: 54,
      height: 54,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: const Text('أ',
          style: TextStyle(
              fontFamily: 'ThmanyahSerif',
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w400)),
    ),
    const SizedBox(width: 14),
    Expanded(
      child: Text(
        'أساتذة اقرأ  |  $subtitle',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.muted(12),
      ),
    ),
    Text(title,
        style: AppText.heading(30).copyWith(color: AppColors.textDark)),
  ]);
}

Widget _ornament() {
  return const Row(children: [
    Expanded(child: Divider(color: AppColors.border, thickness: 1.4)),
    Padding(
      padding: EdgeInsets.symmetric(horizontal: 10),
      child: Icon(Icons.star_rounded, color: AppColors.primary, size: 16),
    ),
    Expanded(child: Divider(color: AppColors.border, thickness: 1.4)),
  ]);
}

Widget _infoChip(IconData icon, String label, String value) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: AppColors.primaryLight, size: 18),
      const SizedBox(width: 8),
      Text('$label: ', style: AppText.bold(14)),
      Text(value, style: AppText.normal(14)),
    ]),
  );
}

Widget _statTile(String label, String value, Color bg, Color fg, IconData icon,
    {bool compact = false}) {
  return Expanded(
    child: Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: compact ? 10 : 18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: fg, size: compact ? 20 : 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: AppText.bold(compact ? 12.5 : 14).copyWith(color: fg)),
          ),
          Text(value,
              style: AppText.heading(compact ? 24 : 30)
                  .copyWith(color: fg, height: 1.1)),
        ],
      ),
    ),
  );
}

Widget _shell({required Widget child}) {
  return Directionality(
    textDirection: ui.TextDirection.rtl,
    child: Container(
      width: kSummaryWidth,
      height: kSummaryHeight,
      padding: const EdgeInsets.fromLTRB(38, 26, 38, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, AppColors.primarySoft],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.primary, width: 1.6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    ),
  );
}

// ---------------------------------------------------------------------------
// بطاقة الأستاذ + جدوله (صفحات)
// ---------------------------------------------------------------------------

/// بطاقة الأستاذ: معلوماته + إحصاءات + جدوله الأسبوعي كاملاً (على صفحات).
List<Widget> teacherSummaryPages(TeacherSummary s, {DateTime? on}) {
  final today = DateFormat('yyyy/MM/dd').format(on ?? DateTime.now());
  final rows = <Widget>[];
  if (s.schedule.isEmpty) {
    rows.add(Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text('لا توجد حصص مجدولة بعد.', style: AppText.muted(14)),
    ));
  } else {
    rows.addAll(_scheduleRows(s.schedule));
  }
  final chunks = _chunkRows(rows, 6, 12);
  if (chunks.isEmpty) {
    return [
      _teacherPage(s, today: today, scheduleRows: rows, isFirst: true),
    ];
  }
  return [
    for (var i = 0; i < chunks.length; i++)
      _teacherPage(s, today: today, scheduleRows: chunks[i], isFirst: i == 0),
  ];
}

List<Widget> _scheduleRows(List<ScheduleEntry> schedule) {
  final byDay = <int, List<ScheduleEntry>>{};
  for (final e in schedule) {
    byDay.putIfAbsent(e.dayOfWeek, () => []).add(e);
  }
  const order = {1: 0, 2: 1, 3: 2, 4: 3, 5: 4, 6: 5, 7: 6};
  final days = byDay.keys.toList()..sort((a, b) => order[a]!.compareTo(order[b]!));
  final rows = <Widget>[];
  for (final d in days) {
    final dayName = ScheduleEntry.dayNames[d] ?? '';
    for (final e in byDay[d]!) {
      rows.add(Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Container(
            width: 62,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(dayName,
                style: AppText.bold(12).copyWith(color: AppColors.primary)),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${e.startTime} – ${e.endTime}',
                style: AppText.white(11.5)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(e.className,
                style: AppText.bold(13), overflow: TextOverflow.ellipsis),
          ),
        ]),
      ));
    }
  }
  return rows;
}

Widget _teacherPage(
  TeacherSummary s, {
  required String today,
  required List<Widget> scheduleRows,
  required bool isFirst,
}) {
  final t = s.teacher;
  final active = t.isActive;
  return _shell(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isFirst) ...[
          _brandRow('بطاقة الأستاذ', 'الملف التعريفي — $today'),
          const SizedBox(height: 10),
          _ornament(),
          const SizedBox(height: 12),
          Row(children: [
            Container(
              width: 74,
              height: 74,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                t.name.isNotEmpty ? t.name[0] : '؟',
                style: const TextStyle(
                    fontFamily: 'ThmanyahSerif',
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w400),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(t.name,
                          style: AppText.heading(26),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      active ? Icons.check_circle : Icons.cancel,
                      color: active ? AppColors.present : AppColors.absent,
                      size: 24,
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text('الهاتف: ${t.phone}', style: AppText.normal(14)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    _infoChip(Icons.menu_book_outlined, 'المادة', t.subject ?? '—'),
                    _infoChip(Icons.class_outlined, 'الأقسام', t.section ?? '—'),
                  ]),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _statTile('إجمالي الحصص الأسبوعية', '${s.scheduleCount}',
                AppColors.primarySoft, AppColors.primary,
                Icons.event_available_outlined,
                compact: true),
            const SizedBox(width: 10),
            _statTile('مجموع ساعات الجدول',
                SummaryService.fmtHoursShort(s.totalMinutes),
                AppColors.presentSoft, AppColors.present,
                Icons.schedule_rounded,
                compact: true),
          ]),
          const SizedBox(height: 10),
          Divider(color: AppColors.border),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.calendar_view_week_outlined,
                color: AppColors.primary, size: 16),
            const SizedBox(width: 6),
            Text('جدول الحصص الأسبوعي',
                style: AppText.bold(14).copyWith(color: AppColors.primary)),
          ]),
          const SizedBox(height: 8),
        ] else ...[
          _brandRow('بطاقة الأستاذ', 'استمرار الجدول — $today'),
          const SizedBox(height: 10),
          _ornament(),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.calendar_view_week_outlined,
                color: AppColors.primary, size: 16),
            const SizedBox(width: 6),
            Text('استمرار جدول الحصص الأسبوعي',
                style: AppText.bold(14).copyWith(color: AppColors.primary)),
          ]),
          const SizedBox(height: 8),
        ],
        ...scheduleRows,
        const Spacer(),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.verified_outlined,
              color: AppColors.primaryLight, size: 15),
          const SizedBox(width: 6),
          Text('ملخّص موثّق من منصة إقرأ التعليمية',
              style: AppText.muted(12)),
        ]),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// التقارير (يومي / أسبوعي / شهري)
// ---------------------------------------------------------------------------

/// صفحات التقرير: صفحة الملخص +(لليومي) صفحة تفاصيل الحصص.
List<Widget> reportPages(AppUser teacher, RangeSummary s, ReportRange range) {
  final pages = <Widget>[reportSummaryCard(teacher, s, range)];
  if (range == ReportRange.daily && s.items.isNotEmpty) {
    final rows = <Widget>[];
    for (final it in s.items) {
      final (bg, fg, label) = _statusOf(it.status);
      rows.add(Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${it.startTime} – ${it.endTime}',
                style: AppText.white(11.5)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(it.className,
                style: AppText.bold(13), overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(label, style: AppText.bold(12).copyWith(color: fg)),
          ),
        ]),
      ));
    }
    final chunks = _chunkRows(rows, 12, 12);
    for (var i = 0; i < chunks.length; i++) {
      pages.add(_detailsPage(teacher, range, chunks[i]));
    }
  }
  return pages;
}

Widget reportSummaryCard(AppUser teacher, RangeSummary s, ReportRange range) {
  final dateFmt = DateFormat('yyyy/MM/dd');
  return _shell(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _brandRow(range.label,
            'من ${dateFmt.format(s.start)} إلى ${dateFmt.format(s.end)}'),
        const SizedBox(height: 10),
        _ornament(),
        const SizedBox(height: 14),
        Row(children: [
          Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              teacher.name.isNotEmpty ? teacher.name[0] : '؟',
              style: const TextStyle(
                  fontFamily: 'ThmanyahSerif',
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w400),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(teacher.name,
                    style: AppText.heading(24),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(
                  '${teacher.subject ?? '—'}   |   ${teacher.section ?? '—'}   |   ${s.totalClasses} حصة في النطاق',
                  style: AppText.muted(13.5),
                ),
              ],
            ),
          ),
        ]),
        const Spacer(),
        Row(children: [
          _statTile('حاضِر', '${s.present}', AppColors.presentSoft,
              AppColors.present, Icons.check_circle_outline),
          const SizedBox(width: 12),
          _statTile('متأخِر', '${s.late}', AppColors.lateSoft,
              AppColors.late, Icons.schedule),
          const SizedBox(width: 12),
          _statTile('غائب', '${s.absent}', AppColors.absentSoft,
              AppColors.absent, Icons.cancel_outlined),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          _statTile('ساعات الحضور',
              SummaryService.fmtHoursShort(s.attendedMinutes),
              AppColors.presentSoft, AppColors.present,
              Icons.timer_outlined),
          const SizedBox(width: 12),
          _statTile('ساعات الغياب',
              SummaryService.fmtHoursShort(s.absentMinutes),
              AppColors.absentSoft, AppColors.absent,
              Icons.timer_off_outlined),
          const SizedBox(width: 12),
          _statTile('مجموع الساعات',
              SummaryService.fmtHoursShort(s.totalMinutes),
              AppColors.primarySoft, AppColors.primary,
              Icons.access_time_rounded),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.verified_outlined,
              color: AppColors.primaryLight, size: 15),
          const SizedBox(width: 6),
          Text('ملخّص موثّق من منصة إقرأ التعليمية',
              style: AppText.muted(12)),
        ]),
      ],
    ),
  );
}

Widget _detailsPage(AppUser teacher, ReportRange range, List<Widget> rows) {
  return _shell(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _brandRow(range.label, 'تفاصيل الحصص'),
        const SizedBox(height: 10),
        _ornament(),
        const SizedBox(height: 14),
        Row(children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              teacher.name.isNotEmpty ? teacher.name[0] : '؟',
              style: const TextStyle(
                  fontFamily: 'ThmanyahSerif',
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w400),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('حصص ${teacher.name} المقررة',
                style: AppText.heading(20), overflow: TextOverflow.ellipsis),
          ),
        ]),
        const SizedBox(height: 12),
        Divider(color: AppColors.border),
        const SizedBox(height: 8),
        ...rows,
        const Spacer(),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.verified_outlined,
              color: AppColors.primaryLight, size: 15),
          const SizedBox(width: 6),
          Text('ملخّص موثّق من منصة إقرأ التعليمية',
              style: AppText.muted(12)),
        ]),
      ],
    ),
  );
}

(Color, Color, String) _statusOf(String status) => switch (status) {
      'present' => (AppColors.presentSoft, AppColors.present, 'حاضر'),
      'late' => (AppColors.lateSoft, AppColors.late, 'متأخر'),
      'absent' => (AppColors.absentSoft, AppColors.absent, 'غائب'),
      _ => (AppColors.primarySoft, AppColors.primary, 'قادمة'),
    };

/// تقسيم قائمة صفوف على صفحات أفقية.
List<List<Widget>> _chunkRows(List<Widget> rows, int first, int next) {
  if (rows.isEmpty) return const [];
  final out = <List<Widget>>[];
  var i = 0;
  var take = first;
  while (i < rows.length) {
    final end = (i + take < rows.length) ? i + take : rows.length;
    out.add(rows.sublist(i, end));
    i = end;
    take = next;
  }
  return out;
}