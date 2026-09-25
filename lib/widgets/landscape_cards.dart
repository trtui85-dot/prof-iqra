import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../models/app_user.dart';
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('أساتذة اقرأ',
              style: AppText.heading(22).copyWith(color: AppColors.primary)),
          Text(subtitle, style: AppText.muted(12)),
        ],
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
      color: AppColors.surface.withValues(alpha: 0.9),
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

Widget _statTile(String label, String value, Color bg, Color fg, IconData icon) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(icon, color: fg, size: 22),
            const Spacer(),
            Text(label, style: AppText.bold(14).copyWith(color: fg)),
          ]),
          const SizedBox(height: 10),
          Text(value,
              style: AppText.heading(30)
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
      padding: const EdgeInsets.fromLTRB(38, 30, 38, 28),
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

/// بطاقة الأستاذ — ملخص جانبي أنيق.
Widget teacherSummaryCard(TeacherSummary s, {DateTime? on}) {
  final t = s.teacher;
  final today = DateFormat('yyyy/MM/dd').format(on ?? DateTime.now());
  final active = t.isActive;
  return _shell(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _brandRow('بطاقة الأستاذ', 'الملف التعريفي — $today'),
        const SizedBox(height: 16),
        _ornament(),
        const SizedBox(height: 20),
        Row(children: [
          Container(
            width: 92,
            height: 92,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              t.name.isNotEmpty ? t.name[0] : '؟',
              style: const TextStyle(
                  fontFamily: 'ThmanyahSerif',
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w400),
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.name, style: AppText.heading(30)),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.phone_outlined,
                      color: AppColors.textMuted, size: 17),
                  const SizedBox(width: 6),
                  Text(t.phone, style: AppText.normal(15)),
                ]),
                const SizedBox(height: 12),
                Wrap(spacing: 10, runSpacing: 8, children: [
                  _infoChip(Icons.menu_book_outlined, 'المادة',
                      t.subject ?? '—'),
                  _infoChip(Icons.class_outlined, 'الأقسام', t.section ?? '—'),
                ]),
              ],
            ),
          ),
          Column(children: [
            Icon(
              active ? Icons.check_circle : Icons.cancel,
              color: active ? AppColors.present : AppColors.absent,
              size: 34,
            ),
            const SizedBox(height: 4),
            Text(active ? 'نشط' : 'موقوف',
                style: AppText.bold(14)
                    .copyWith(color: active ? AppColors.present : AppColors.absent)),
          ]),
        ]),
        const Spacer(),
        Row(children: [
          _statTile('إجمالي الحصص الأسبوعية', '${s.scheduleCount}',
              AppColors.primarySoft, AppColors.primary,
              Icons.event_available_outlined),
          const SizedBox(width: 14),
          _statTile('مجموع ساعات الجدول',
              SummaryService.fmtHoursShort(s.totalMinutes),
              AppColors.presentSoft, AppColors.present,
              Icons.schedule_rounded),
        ]),
        const SizedBox(height: 18),
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

/// تقرير الحضور الأسبوعي — ملخص بأرقام واضحة.
Widget weeklySummaryCard(AppUser teacher, WeeklySummary s) {
  final dateFmt = DateFormat('yyyy/MM/dd');
  return _shell(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _brandRow('تقرير الحضور الأسبوعي',
            'من ${dateFmt.format(s.start)} إلى ${dateFmt.format(s.end)}'),
        const SizedBox(height: 14),
        _ornament(),
        const SizedBox(height: 18),
        Row(children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              teacher.name.isNotEmpty ? teacher.name[0] : '؟',
              style: const TextStyle(
                  fontFamily: 'ThmanyahSerif',
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w400),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(teacher.name, style: AppText.heading(26)),
                const SizedBox(height: 4),
                Text(
                  '${teacher.subject ?? '—'}   |   ${teacher.section ?? '—'}',
                  style: AppText.muted(14),
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
        const SizedBox(height: 16),
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