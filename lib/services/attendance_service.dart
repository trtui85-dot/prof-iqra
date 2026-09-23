import 'package:intl/intl.dart';

import '../core/supabase.dart';
import '../models/app_user.dart';
import '../models/attendance_log.dart';
import '../models/schedule_entry.dart';
import 'notification_service.dart';
import 'schedule_service.dart';

enum ScanKind { checkIn, checkOut }

class ScanResult {
  final ScanKind kind;
  final ScheduleEntry entry;
  final String status; // 'present' | 'late'
  final DateTime when;

  const ScanResult({
    required this.kind,
    required this.entry,
    required this.status,
    required this.when,
  });
}

class AttendanceService {
  static const qrPrefix = 'IQRA1:';
  static const lateGraceMinutes = 15;

  /// التحقق من أن رمز QR الممسوح هو رمز الإدارة الحالي
  Future<bool> verifyQr(String payload) async {
    if (!payload.startsWith(qrPrefix)) return false;
    final scannedSecret = payload.substring(qrPrefix.length).trim();
    final res = await db
        .from('app_settings')
        .select('value')
        .eq('key', 'qr_secret')
        .limit(1)
        .maybeSingle();
    return res != null && res['value'] == scannedSecret;
  }

  /// مسح واحد: إن وُجدت جلسة مفتوحة → انصراف، وإلا → حضور
  /// يُرمى AttendanceException مع رسالة واضحة إن لم تكن حصة مجدولة.
  Future<ScanResult> scan(AppUser teacher) async {
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);

    // 1) جلسة مفتوحة اليوم (حضور بلا انصراف) → انصراف
    final open = await db
        .from('attendance_logs')
        .select('id, schedule_id, class_name, status')
        .eq('teacher_id', teacher.id)
        .eq('entry_date', today)
        .isFilter('check_out_time', null)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (open != null) {
      final log = AttendanceLog.fromJson(open);
      final entry =
          log.scheduleId != null ? await _entryById(log.scheduleId!) : null;
      await db
          .from('attendance_logs')
          .update({'check_out_time': now.toUtc().toIso8601String()})
          .eq('id', log.id);
      await NotificationService().notifyUser(
        teacher.id,
        'تم تسجيل انصرافك عن حصة «${log.className ?? '—'}».',
      );
      return ScanResult(
        kind: ScanKind.checkOut,
        entry: entry ?? _emptyEntry(log.className),
        status: log.status,
        when: now,
      );
    }

    // 2) لا جلسة مفتوحة → تسجيل حضور، بشرط وجود حصة حالية
    final entries = await ScheduleService().listForTeacher(teacher.id);
    final candidate = _currentEntry(entries, now);
    if (candidate == null) {
      throw AttendanceException(
        'لا توجد حصة مجدولة لك الآن ضمن جدولك.',
      );
    }

    final start = candidate.startToday();
    final isLate = now.isAfter(start.add(Duration(minutes: lateGraceMinutes)));
    final status = isLate ? 'late' : 'present';
    final lateMinutes = isLate ? now.difference(start).inMinutes : null;

    await db.from('attendance_logs').insert({
      'teacher_id': teacher.id,
      'schedule_id': candidate.id,
      'class_name': candidate.className,
      'entry_date': today,
      'check_in_time': now.toUtc().toIso8601String(),
      'check_out_time': null,
      'status': status,
      'late_minutes': lateMinutes,
    });

    final time = DateFormat('HH:mm').format(now);
    await NotificationService().notifyUser(
      teacher.id,
      isLate
          ? 'تم تسجيل حضورك لحصة «${candidate.className}» الساعة $time (متأخر).'
          : 'تم تسجيل حضورك لحصة «${candidate.className}» الساعة $time.',
    );
    if (isLate) {
      await NotificationService().notifyAdmins(
        'تأخر الأستاذ ${teacher.name} عن حصة «${candidate.className}» الساعة $time.',
      );
    }

    return ScanResult(
      kind: ScanKind.checkIn,
      entry: candidate,
      status: status,
      when: now,
    );
  }

  static ScheduleEntry? _currentEntry(List<ScheduleEntry> entries, DateTime now) {
    final weekday = now.weekday;
    final todays = entries.where((e) => e.dayOfWeek == weekday).toList();
    if (todays.isEmpty) return null;

    ScheduleEntry? best;
    for (final e in todays) {
      final start = e.startToday();
      final end = e.endToday();
      final windowStart = start.subtract(const Duration(minutes: 30));
      final inWindow = !now.isBefore(windowStart) && now.isBefore(end);
      if (!inWindow) continue;
      if (best == null || start.isBefore(best.startToday())) best = e;
    }
    return best;
  }

  Future<ScheduleEntry?> _entryById(String id) async {
    final res = await db.from('schedule').select().eq('id', id).maybeSingle();
    if (res == null) return null;
    return ScheduleEntry.fromJson(res);
  }

  ScheduleEntry _emptyEntry(String? className) => ScheduleEntry(
        id: '',
        teacherId: '',
        dayOfWeek: DateTime.now().weekday,
        startTime: '00:00',
        endTime: '00:00',
        className: className ?? '—',
      );

  /// حضور اليوم لكل الأساتذة النشطين (لوحة الإدارة)
  Future<List<dynamic>> todaySummary() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final weekday = DateTime.now().weekday;

    final teachers = await db
        .from('users')
        .select()
        .eq('role', 'teacher')
        .eq('is_active', true);
    final logs = await db
        .from('attendance_logs')
        .select('*, users(name)')
        .eq('entry_date', today);
    final sched = await db
        .from('schedule')
        .select()
        .eq('day_of_week', weekday);

    final logsByTeacher = <String, List<Map<String, dynamic>>>{};
    for (final l in logs) {
      final t = l['teacher_id'] as String;
      logsByTeacher.putIfAbsent(t, () => []).add(l);
    }
    final schedByTeacher = <String, List<Map<String, dynamic>>>{};
    for (final s in sched) {
      final t = s['teacher_id'] as String;
      schedByTeacher.putIfAbsent(t, () => []).add(s);
    }

    final rows = <Map<String, dynamic>>[];
    final now = DateTime.now();
    for (final t in teachers) {
      final teacher = AppUser.fromJson(t);
      final teacherLogs = logsByTeacher[teacher.id] ?? [];
      final teacherSched = schedByTeacher[teacher.id] ?? <Map<String, dynamic>>[];
      for (final s in teacherSched) {
        final entry = ScheduleEntry.fromJson(s);
        final log = teacherLogs.where((l) =>
            l['schedule_id'] == entry.id ||
            (l['schedule_id'] == null && l['class_name'] == entry.className));
        if (log.isNotEmpty) {
          final att = AttendanceLog.fromJson(log.first);
          rows.add({
            'teacher': teacher,
            'scheduleId': entry.id,
            'className': entry.className,
            'startTime': entry.startTime,
            'endTime': entry.endTime,
            'status': att.status,
            'checkIn': att.checkIn,
            'checkOut': att.checkOut,
            'lateMinutes': att.lateMinutes,
          });
        } else if (now.isAfter(entry.endToday())) {
          rows.add({
            'teacher': teacher,
            'scheduleId': entry.id,
            'className': entry.className,
            'startTime': entry.startTime,
            'endTime': entry.endTime,
            'status': 'absent',
            'checkIn': null,
            'checkOut': null,
            'lateMinutes': null,
          });
        } else {
          rows.add({
            'teacher': teacher,
            'scheduleId': entry.id,
            'className': entry.className,
            'startTime': entry.startTime,
            'endTime': entry.endTime,
            'status': 'upcoming',
            'checkIn': null,
            'checkOut': null,
            'lateMinutes': null,
          });
        }
      }
      // حضور مسجّل لحصص لا تزال معرّفة بلا جدول؟ (نادر)
    }
    rows.sort((a, b) => a['startTime'].compareTo(b['startTime']));
    return rows;
  }

  /// تسجيل يدوي من الإدارة: حضر / لم يحضر / حضر متأخراً
  /// [startTime] بصيغة 'HH:mm' لاحتساب وقت الدخول الفعلي عند التأخير.
  Future<void> mark({
    required String teacherId,
    required String scheduleId,
    required String className,
    required String startTime,
    required String status, // 'present' | 'absent' | 'late'
    int? lateMinutes,
  }) async {
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    DateTime? checkIn;
    if (status == 'present') {
      checkIn = _timeOnToday(startTime);
    } else if (status == 'late') {
      checkIn =
          _timeOnToday(startTime).add(Duration(minutes: lateMinutes ?? 0));
    }

    final existing = await db
        .from('attendance_logs')
        .select('id, check_out_time')
        .eq('teacher_id', teacherId)
        .eq('schedule_id', scheduleId)
        .eq('entry_date', today)
        .order('created_at', ascending: false)
        .limit(10);

    final data = <String, dynamic>{
      'status': status,
      'check_in_time': checkIn?.toUtc().toIso8601String(),
      'late_minutes': status == 'late' ? lateMinutes : null,
    };

    // إن وُجدت سجلات متعددة (جلسات متكررة) نُحدّث الجلسة المفتوحة
    // (بلا انصراف) أو الأحدث، بدلاً من الاستعلام single الذي يفشل عند التكرار.
    Map<String, dynamic>? target;
    if (existing.isNotEmpty) {
      target = existing.firstWhere(
            (r) => r['check_out_time'] == null,
            orElse: () => existing.first,
          );
    }
    if (target != null) {
      await db.from('attendance_logs').update(data).eq('id', target['id']);
    } else {
      await db.from('attendance_logs').insert({
        'teacher_id': teacherId,
        'schedule_id': scheduleId,
        'class_name': className,
        'entry_date': today,
        ...data,
      });
    }
  }

  static DateTime _timeOnToday(String hhmm) {
    final now = DateTime.now();
    final p = hhmm.split(':');
    return DateTime(
        now.year, now.month, now.day, int.parse(p[0]), int.parse(p[1]));
  }
}

class AttendanceException implements Exception {
  final String message;
  const AttendanceException(this.message);
  @override
  String toString() => message;
}