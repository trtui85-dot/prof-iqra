import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      final status = r['status'] as String;
      final lateMin = r['lateMinutes'] as int?;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppCard(
          padding: const EdgeInsets.all(13),
          child: Column(
            children: [
              Row(
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
                        Text(
                            '${r['className']} • ${r['startTime']} – ${r['endTime']}',
                            style: AppText.muted(12)),
                        const SizedBox(height: 4),
                        Row(children: W(r['checkIn'])..addAll(W(r['checkOut']))),
                        if (status == 'late' && lateMin != null) ...[
                          const SizedBox(height: 4),
                          Text('متأخراً بـ $lateMin دقيقة',
                              style: AppText.bold(12)
                                  .copyWith(color: AppColors.late)),
                        ],
                      ],
                    ),
                  ),
                  StatusChip(status),
                ],
              ),
              if (status == 'absent' || status == 'upcoming') ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: _markButton(
                      label: 'حاضر',
                      icon: Icons.check_circle_outline,
                      fg: AppColors.present,
                      bg: AppColors.presentSoft,
                      onTap: () => _mark(
                        r,
                        status: 'present',
                        lateMinutes: null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _markButton(
                      label: 'غائب',
                      icon: Icons.cancel_outlined,
                      fg: AppColors.absent,
                      bg: AppColors.absentSoft,
                      onTap: () => _mark(
                        r,
                        status: 'absent',
                        lateMinutes: null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _markButton(
                      label: 'متأخر',
                      icon: Icons.schedule,
                      fg: AppColors.late,
                      bg: AppColors.lateSoft,
                      onTap: () => _markLate(r),
                    ),
                  ),
                ]),
              ],
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _markButton({
    required String label,
    required IconData icon,
    required Color fg,
    required Color bg,
    required VoidCallback onTap,
  }) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 5),
              Flexible(
                child: Text(label,
                    style: AppText.bold(12.5).copyWith(color: fg),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _mark(
    Map<String, dynamic> r, {
    required String status,
    required int? lateMinutes,
  }) async {
    final teacher = r['teacher'] as AppUser;
    try {
      await _service.mark(
        teacherId: teacher.id,
        scheduleId: r['scheduleId'],
        className: r['className'],
        startTime: r['startTime'],
        status: status,
        lateMinutes: lateMinutes,
      );
      if (!mounted) return;
      showSuccess(context, 'تم تسجيل الحالة: ${statusChipLabel(status)}.');
      _load(silent: true);
    } catch (_) {
      if (!mounted) return;
      showError(context, 'فشل تسجيل الحالة.');
    }
  }

  Future<void> _markLate(Map<String, dynamic> r) async {
    final controller = TextEditingController(text: '5');
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حضر متأخراً'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${(r['teacher'] as AppUser).name} — ${r['className']}',
              style: AppText.muted(13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'عدد دقائق التأخير',
                suffixText: 'دقيقة',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حفظ')),
        ],
      ),
    );
    if (submitted != true) {
      controller.dispose();
      return;
    }
    final minutes = int.tryParse(controller.text.trim()) ?? 0;
    controller.dispose();
    if (minutes <= 0) {
      if (mounted) showError(context, 'أدخل عدد دقائق صحيح.');
      return;
    }
    await _mark(r, status: 'late', lateMinutes: minutes);
  }

  static const Map<String, String> _labels = {
    'present': 'حاضر',
    'absent': 'غائب',
    'late': 'متأخر',
  };
  static String statusChipLabel(String s) => _labels[s] ?? s;

  static String _fmt(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}