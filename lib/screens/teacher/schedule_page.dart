import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/app_user.dart';
import '../../models/schedule_entry.dart';
import '../../services/schedule_service.dart';

class SchedulePage extends StatefulWidget {
  final AppUser teacher;
  const SchedulePage({super.key, required this.teacher});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final _service = ScheduleService();
  List<ScheduleEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _service.listForTeacher(widget.teacher.id);
      if (mounted) {
        setState(() {
          _entries = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (widget.teacher.subject != null ||
              widget.teacher.section != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                [
                  if (widget.teacher.subject != null)
                    widget.teacher.subject!,
                  if (widget.teacher.section != null)
                    widget.teacher.section!,
                ].join(' • '),
                style: AppText.muted(13),
              ),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (_entries.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: EmptyState(
                'لا يوجد جدول لك بعد.\nتتواصل مع الإدارة لإضافة حصصك.',
                icon: Icons.calendar_month_outlined,
              ),
            )
          else
            ..._groupedDays(),
        ],
      ),
    );
  }

  List<Widget> _groupedDays() {
    const days = [1, 2, 3, 4, 5, 6, 7];
    final widgets = <Widget>[];
    for (final day in days) {
      final dayEntries = _entries.where((e) => e.dayOfWeek == day).toList();
      if (dayEntries.isEmpty) continue;
      final today = DateTime.now().weekday == day;
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 10),
        child: Row(children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: today ? AppColors.primary : AppColors.textMuted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            ScheduleEntry.dayNames[day]!,
            style: AppText.bold(15).copyWith(
              color: today ? AppColors.primary : AppColors.textDark,
            ),
          ),
          if (today)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: StatusChip('upcoming'),
            ),
        ]),
      ));
      for (final e in dayEntries) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(children: [
                    Text(e.startTime,
                        style: AppText.bold(14).copyWith(color: AppColors.primary)),
                    const SizedBox(height: 2),
                    Text('إلى ${e.endTime}', style: AppText.muted(11)),
                  ]),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.className, style: AppText.bold(15)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_left, color: AppColors.textMuted),
              ],
            ),
          ),
        ));
      }
    }
    return widgets;
  }
}