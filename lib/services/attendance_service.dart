import 'package:intl/intl.dart';

import '../core/supabase.dart';
import '../models/app_user.dart';
import '../models/attendance_log.dart';
import '../models/schedule_entry.dart';
import 'notification_service.dart';
import 'schedule_service.dart';
import 'local_notif_service.dart';

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

  /// إذا مضت 90 دقيقة على بداية الحصة دون مسح، تُعتبر غياباً تلقائياً
  /// (مثال: حصة 08:00 → عند 09:30 تُسجَّل غياب تلقائياً).
  static const autoAbsentMinutes = 90;

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

  /// مسح ذكي: يُسجّل الغياب التلقائي، ويُغلق الحصص المنتهية بلا حصة تالية،
  /// ثم يُحدّد إن كان المسح انصرافاً أو انتقاءً للحصة التالية أو حضوراً.
  /// يُرمى AttendanceException مع رسالة واضحة إن لم تكن حصة مجدولة.
  Future<ScanResult> scan(AppUser teacher) async {
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);

    // 1) تسجيل الغياب التلقائي للحصص المتجاوزة حد الـ 90 دقيقة
    await autoMarkAbsentsToday();
    // 2) إغلاق تلقائي لحصة انتهت ولا توجد بعدها حصة
    await autoCloseExpiredSessions(teacher.id, now);

    // 3) حصص اليوم والحصة الجارية حالياً
    final entries = await ScheduleService().listForTeacher(teacher.id);
    final current = _currentEntry(entries, now);

    // 4) جلسة مفتوحة (حضور بلا انصراف)؟
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
      final oEntry =
          log.scheduleId != null ? await _entryById(log.scheduleId!) : null;

      // أ) نفس الحصة ما زالت جارية → انصراف عادي
      if (current != null && log.scheduleId == current.id) {
        await _closeLog(log.id, now);
        await NotificationService().notifyUser(
          teacher.id,
          'تم تسجيل انصرافك عن حصة «${current.className}».',
        );
        return ScanResult(
          kind: ScanKind.checkOut,
          entry: current,
          status: log.status,
          when: now,
        );
      }

      // ب) الحصة المفتوحة انتهت وهناك حصة جديدة جارية → يُغلق القديمة
      //    ويُدخل الأستاذ مباشرةً إلى الحصة الجديدة (يُحتسب له حضورها)
      if (oEntry != null && now.isAfter(oEntry.endToday()) && current != null) {
        await _closeLog(log.id, oEntry.endToday());
        return _checkIn(teacher, current, now, today);
      }

      // ج) لا حصة جارية الآن (استراحة/انتهى كل شيء) → انصراف عادي
      await _closeLog(log.id, now);
      await NotificationService().notifyUser(
        teacher.id,
        'تم تسجيل انصرافك عن حصة «${oEntry?.className ?? log.className ?? '—'}».',
      );
      return ScanResult(
        kind: ScanKind.checkOut,
        entry: oEntry ?? _emptyEntry(log.className),
        status: log.status,
        when: now,
      );
    }

    // 5) لا جلسة مفتوحة → تسجيل حضور بشرط وجود حصة حالية
    if (current == null) {
      throw AttendanceException(
        'لا توجد حصة مجدولة لك الآن ضمن جدولك.',
      );
    }
    return _checkIn(teacher, current, now, today);
  }

  /// إغلاق تلقائي: إذا انتهى موعد الحصة ولا توجد حصة تالية بعدها ولم يمسح
  /// الأستاذ للانصراف، يُغلق السجل تلقائياً (حاضر) عند نهاية الحصة
  /// ويُخطَر الأستاذ: «لقد انتهت حصتك».
  Future<void> autoCloseExpiredSessions(String teacherId, DateTime now) async {
    final today = DateFormat('yyyy-MM-dd').format(now);
    final openLogs = await db
        .from('attendance_logs')
        .select('id, schedule_id, class_name, status')
        .eq('teacher_id', teacherId)
        .eq('entry_date', today)
        .isFilter('check_out_time', null);
    if (openLogs.isEmpty) return;

    final entries = await ScheduleService().listForTeacher(teacherId);
    for (final row in openLogs) {
      final log = AttendanceLog.fromJson(row);
      final sid = log.scheduleId;
      if (sid == null || sid.isEmpty) continue;
      final entry = await _entryById(sid);
      if (entry == null) continue;
      if (now.isBefore(entry.endToday())) continue; // الحصة لم تنتهِ بعد

      // هل توجد حصة تالية؟ إن نعم يُترك السجل ليُغلق عند مسح الحصة الجديدة
      final hasNext = entries.any((e) =>
          e.id != entry.id && !e.startToday().isBefore(entry.endToday()));
      if (hasNext) continue;

      await _closeLog(log.id, entry.endToday());
      await NotificationService().notifyUser(
        teacherId,
        'لقد انتهت حصتك «${entry.className}» وسُجّل حضورك.',
      );
      try {
        await LocalNotifService.showNow(
          title: 'انتهت الحصة',
          body: 'حصتك «${entry.className}» انتهت — سُجّلت حاضراً.',
        );
      } catch (_) {}
    }
  }

  Future<void> _closeLog(String id, DateTime when) async {
    await db
        .from('attendance_logs')
        .update({'check_out_time': when.toUtc().toIso8601String()})
        .eq('id', id);
  }

  /// تسجيل حضور/انصراف على سجل جديد (المسح الأول لحصة جارية/جديدة)
  Future<ScanResult> _checkIn(
    AppUser teacher,
    ScheduleEntry candidate,
    DateTime now,
    String today,
  ) async {
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
    if (isLate) {
      await NotificationService().notifyUser(
        teacher.id,
        'تم تسجيل حضورك لحصة «${candidate.className}» الساعة $time (متأخر بـ $lateMinutes دقيقة).',
      );
      await NotificationService().notifyAdmins(
        'الأستاذ ${teacher.name} حضر متأخراً لـ $lateMinutes دقيقة عن حصة «${candidate.className}» الساعة $time.',
      );
    } else {
      await NotificationService().notifyUser(
        teacher.id,
        'تم تسجيل حضورك لحصة «${candidate.className}» الساعة $time.',
      );
      await NotificationService().notifyAdmins(
        'الأستاذ ${teacher.name} سجّل حضوره لحصة «${candidate.className}» الساعة $time.',
      );
    }

    return ScanResult(
      kind: ScanKind.checkIn,
      entry: candidate,
      status: status,
      when: now,
    );
  }

  /// تسجيل الغياب التلقائي تلقائياً لكل حصة اليوم التي تجاوزت
  /// بدايتها بـ autoAbsentMinutes دون تسجيل حضور (وتطالبه الإدارة).
  Future<void> autoMarkAbsentsToday() async {
    final now = DateTime.now();
    final dayFmt = DateFormat('yyyy-MM-dd');
    final today = dayFmt.format(now);
    final weekday = now.weekday;

    final teachers = await db
        .from('users')
        .select('id, name')
        .eq('role', 'teacher')
        .eq('is_active', true);
    if (teachers.isEmpty) return;

    final logsRes = await db
        .from('attendance_logs')
        .select('teacher_id, schedule_id, class_name, entry_date')
        .eq('entry_date', today);
    final schedRes = await db
        .from('schedule')
        .select()
        .eq('day_of_week', weekday);

    final loggedKeys = <String>{
      for (final l in logsRes)
        '${l['teacher_id']}|${l['schedule_id'] ?? l['class_name']}',
    };
    final namesById = {for (final t in teachers) t['id'] as String: t['name'] as String};

    for (final s in schedRes) {
      final tId = s['teacher_id'] as String;
      final teacherName = namesById[tId] ?? '—';
      final entry = ScheduleEntry.fromJson(s);
      final key = '$tId|${entry.id}';
      if (loggedKeys.contains(key)) continue;

      final lapsedLimit =
          entry.startToday().add(const Duration(minutes: autoAbsentMinutes));
      final missed = now.isAfter(lapsedLimit) || now.isAfter(entry.endToday());
      if (!missed) continue;

      await db.from('attendance_logs').insert({
        'teacher_id': tId,
        'schedule_id': entry.id,
        'class_name': entry.className,
        'entry_date': today,
        'check_in_time': null,
        'check_out_time': null,
        'status': 'absent',
        'late_minutes': null,
      });
      await NotificationService().notifyAdmins(
        'الأستاذ $teacherName غاب عن حصة «${entry.className}» (لم يسجّل حضوره).',
      );
    }
  }

  /// تنظيف يومي شامل: غيابات تلقائية + إغلاق تلقائي للحصص المنتهية
  Future<void> runTodayHousekeeping() async {
    await autoMarkAbsentsToday();
    final now = DateTime.now();
    final res = await db
        .from('users')
        .select('id')
        .eq('role', 'teacher')
        .eq('is_active', true);
    for (final t in res) {
      await autoCloseExpiredSessions(t['id'] as String? ?? '', now);
    }
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
    final res = await db
        .from('schedule')
        .select()
        .eq('id', id)
        .limit(1)
        .maybeSingle();
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
          final lapsedLimit = entry
              .startToday()
              .add(const Duration(minutes: autoAbsentMinutes));
          if (now.isAfter(entry.endToday()) || now.isAfter(lapsedLimit)) {
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