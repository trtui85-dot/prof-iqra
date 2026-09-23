import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/supabase.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/app_user.dart';
import '../../services/attendance_service.dart';

class LiveAttendancePage extends StatefulWidget {
  final AppUser admin;
  const LiveAttendancePage({super.key, required this.admin});

  @override
  State<LiveAttendancePage> createState() => _LiveAttendancePageState();
}

class _LiveAttendancePageState extends State<LiveAttendancePage> {
  final _service = AttendanceService();
  bool _loading = true;
  List<dynamic> _rows = [];
  sb.RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribe();
  }

  void _subscribe() {
    _channel = db
        .channel('admin-live-attendance')
        .onPostgresChanges(
          event: sb.PostgresChangeEvent.all,
          schema: 'public',
          table: 'attendance_logs',
          callback: (_) => _load(silent: true),
        )
        .subscribe();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    // فكّ تسوية batching التابع لـ Realtime بتأخير صغير
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      final rows = await _service.todaySummary();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  int get _present => _rows.where((r) => r['status'] == 'present').length;
  int get _late => _rows.where((r) => r['status'] == 'late').length;
  int get _absent => _rows.where((r) => r['status'] == 'absent').length;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _buildStats(),
          const SizedBox(height: 20),
          _buildTitle(),
          const SizedBox(height: 8),
          if (_loading && _rows.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (_rows.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 30),
              child: EmptyState('لا توجد حصص مجدولة اليوم.',
                  icon: Icons.today_outlined),
            )
          else
            ..._buildRows(),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Row(children: [
      Expanded(
        child: StatCard(
          label: 'حاضر',
          value: '$_present',
          color: AppColors.present,
          icon: Icons.check_circle_outline,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: StatCard(
          label: 'متأخر',
          value: '$_late',
          color: AppColors.late,
          icon: Icons.schedule,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: StatCard(
          label: 'غائب',
          value: '$_absent',
          color: AppColors.absent,
          icon: Icons.cancel_outlined,
        ),
      ),
    ]);
  }

  Widget _buildTitle() {
    return SectionHeader('حضور اليوم — ${_rows.length} حصة',
        actionLabel: 'تحديث',
        onAction: () => _load());
  }

  List<Widget> _buildRows() {
    List<Widget> W(DateTime? t) => [
          if (t != null) Text(_fmt(t), style: AppText.muted(12.5)),
        ];
    return _rows.map((r) {
      final teacher = r['teacher'] as AppUser;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppCard(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  teacher.name.isNotEmpty ? teacher.name[0] : '?',
                  style: AppText.bold(16).copyWith(color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(teacher.name, style: AppText.bold(14.5)),
                    const SizedBox(height: 2),
                    Text('${r['className']} • ${r['startTime']} – ${r['endTime']}',
                        style: AppText.muted(12)),
                    const SizedBox(height: 4),
                    Row(children: W(r['checkIn'])..addAll(W(r['checkOut']))),
                  ],
                ),
              ),
              StatusChip(r['status'] as String),
            ],
          ),
        ),
      );
    }).toList();
  }

  static String _fmt(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}