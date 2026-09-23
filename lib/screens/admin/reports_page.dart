import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/app_user.dart';
import '../../services/report_service.dart';

enum _Range { day, week, month }

class ReportsPage extends StatefulWidget {
  final AppUser admin;
  const ReportsPage({super.key, required this.admin});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final _service = ReportService();
  _Range _range = _Range.day;
  bool _loading = true;
  List<ReportRow> _dayRows = [];
  List<TeacherSummary> _summaries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    try {
      if (_range == _Range.day) {
        final rows = await _service.dailyReport(now);
        _summaries = [];
        _dayRows = rows;
      } else {
        final end = now;
        final start = _range == _Range.week
            ? now.subtract(const Duration(days: 6))
            : now.subtract(const Duration(days: 29));
        _dayRows = [];
        _summaries = await _service.rangeReport(start, end);
      }
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _count(String s) =>
      _dayRows.where((r) => r.status == s).length;
  String get _daysLabel => DateFormat('d MMMM yyyy', 'ar')
      .format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<_Range>(
            segments: const [
              ButtonSegment(value: _Range.day, label: Text('اليوم')),
              ButtonSegment(value: _Range.week, label: Text('أسبوع')),
              ButtonSegment(value: _Range.month, label: Text('شهر')),
            ],
            selected: {_range},
            showSelectedIcon: false,
            onSelectionChanged: (s) {
              setState(() => _range = s.first);
              _load();
            },
            style: ButtonStyle(
              backgroundColor:
                  WidgetStateProperty.resolveWith((states) =>
                      states.contains(WidgetState.selected)
                          ? AppColors.primary
                          : AppColors.surface),
              foregroundColor:
                  WidgetStateProperty.resolveWith((states) =>
                      states.contains(WidgetState.selected)
                          ? Colors.white
                          : AppColors.textMuted),
              side: const WidgetStatePropertyAll(
                  BorderSide(color: AppColors.border)),
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (_range == _Range.day)
            ..._buildToday()
          else
            ..._buildRange(),
        ],
      ),
    );
  }

  List<Widget> _buildToday() {
    if (_dayRows.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 30),
          child: EmptyState('لا توجد حصص في هذا اليوم.',
              icon: Icons.receipt_long_outlined),
        ),
      ];
    }
    final done =
        _dayRows.where((r) => r.status != 'upcoming').toList();
    return [
      Row(children: [
        Expanded(
          child: StatCard(
            label: 'حاضر',
            value: '${_count('present')}',
            color: AppColors.present,
            icon: Icons.check_circle_outline,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatCard(
            label: 'متأخر',
            value: '${_count('late')}',
            color: AppColors.late,
            icon: Icons.schedule,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatCard(
            label: 'غائب',
            value: '${_count('absent')}',
            color: AppColors.absent,
            icon: Icons.cancel_outlined,
          ),
        ),
      ]),
      const SizedBox(height: 18),
      Text('تقرير $_daysLabel — ${done.length} حصة منجزة',
          style: AppText.heading(16)),
      const SizedBox(height: 10),
      ..._dayRows.map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.teacher.name, style: AppText.bold(14.5)),
                        const SizedBox(height: 2),
                        Text(
                          '${r.className} • ${r.startTime}–${r.endTime}',
                          style: AppText.muted(12),
                        ),
                      ],
                    ),
                  ),
                  StatusChip(r.status),
                ],
              ),
            ),
          )),
    ];
  }

  List<Widget> _buildRange() {
    if (_summaries.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 30),
          child: EmptyState('لا يوجد أساتذة أو حصص في هذه الفترة.',
              icon: Icons.receipt_long_outlined),
        ),
      ];
    }
    return [
      SectionHeader(_range == _Range.week ? 'آخر 7 أيام' : 'آخر 30 يوماً'),
      const SizedBox(height: 10),
      ..._summaries.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(s.teacher.name, style: AppText.bold(15)),
                    ),
                    Text('نسبة الحضور ${s.attendanceRate.toStringAsFixed(0)}%',
                        style: AppText.bold(13)
                            .copyWith(color: AppColors.primary)),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    _mini(s.scheduled, 'مقررة', AppColors.textDark),
                    _mini(s.present, 'حاضر', AppColors.present),
                    _mini(s.late, 'متأخر', AppColors.late),
                    _mini(s.absent, 'غائب', AppColors.absent),
                  ]),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: s.attendanceRate / 100,
                      minHeight: 8,
                      backgroundColor: AppColors.border,
                      color: AppColors.present,
                    ),
                  ),
                ],
              ),
            ),
          )),
    ];
  }

  Widget _mini(int v, String label, Color c) {
    return Expanded(
      child: Column(children: [
        Text('$v', style: AppText.heading(16).copyWith(color: c)),
        const SizedBox(height: 2),
        Text(label, style: AppText.muted(11.5)),
      ]),
    );
  }
}