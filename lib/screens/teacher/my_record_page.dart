import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/supabase.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/app_user.dart';
import '../../models/attendance_log.dart';

class MyRecordPage extends StatefulWidget {
  final AppUser teacher;
  const MyRecordPage({super.key, required this.teacher});

  @override
  State<MyRecordPage> createState() => _MyRecordPageState();
}

class _MyRecordPageState extends State<MyRecordPage> {
  bool _loading = true;
  List<AttendanceLog> _logs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await db
          .from('attendance_logs')
          .select()
          .eq('teacher_id', widget.teacher.id)
          .order('created_at', ascending: false)
          .limit(150);
      final logs = res
          .map((j) => AttendanceLog.fromJson(j))
          .toList();
      if (mounted) {
        setState(() {
          _logs = logs;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (_logs.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: EmptyState(
                'لا توجد حصص مسجّلة بعد.\nامسح رمز الإدارة لتسجيل حضورك.',
                icon: Icons.history,
              ),
            )
          else
            ..._grouped(),
        ],
      ),
    );
  }

  List<Widget> _grouped() {
    final groups = <String, List<AttendanceLog>>{};
    for (final l in _logs) {
      groups.putIfAbsent(l.entryDate, () => []).add(l);
    }
    final widgets = <Widget>[];
    groups.forEach((date, logs) {
      final d = DateTime.parse(date);
      final label = _isToday(d)
          ? 'اليوم'
          : _isYesterday(d)
              ? 'أمس'
              : DateFormat('EEEE، d MMMM yyyy', 'ar').format(d);
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 8),
        child: Text(label, style: AppText.bold(15).copyWith(color: AppColors.primary)),
      ));
      for (final l in logs) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.className ?? 'حصة',
                          style: AppText.bold(14.5)),
                      const SizedBox(height: 4),
                      Text(
                        'دخول ${l.checkIn != null ? _fmt(l.checkIn!) : '—'}${l.checkOut != null ? ' • خروج ${_fmt(l.checkOut!)}' : ''}',
                        style: AppText.muted(12.5),
                      ),
                    ],
                  ),
                ),
                StatusChip(l.status),
              ],
            ),
          ),
        ));
      }
    });
    return widgets;
  }

  static String _fmt(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  static bool _isYesterday(DateTime d) {
    final y = DateTime.now().subtract(const Duration(days: 1));
    return d.year == y.year && d.month == y.month && d.day == y.day;
  }
}