class ScheduleEntry {
  final String id;
  final String teacherId;
  final int dayOfWeek; // 1 = الاثنين .. 7 = الأحد
  final String startTime; // 'HH:mm'
  final String endTime; // 'HH:mm'
  final String className;

  const ScheduleEntry({
    required this.id,
    required this.teacherId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.className,
  });

  factory ScheduleEntry.fromJson(Map<String, dynamic> j) {
    String fmt(String? t) {
      if (t == null) return '00:00';
      final s = t.length >= 5 ? t.substring(0, 5) : t;
      return s;
    }

    return ScheduleEntry(
      id: j['id'] as String,
      teacherId: j['teacher_id'] as String,
      dayOfWeek: (j['day_of_week'] as num?)?.toInt() ?? 1,
      startTime: fmt(j['start_time'] as String?),
      endTime: fmt(j['end_time'] as String?),
      className: j['class_name'] as String,
    );
  }

  static const dayNames = {
    1: 'الاثنين',
    2: 'الثلاثاء',
    3: 'الأربعاء',
    4: 'الخميس',
    5: 'الجمعة',
    6: 'السبت',
    7: 'الأحد',
  };

  String get dayName => dayNames[dayOfWeek] ?? '';

  DateTime startToday() {
    final now = DateTime.now();
    final p = startTime.split(':');
    return DateTime(now.year, now.month, now.day, int.parse(p[0]), int.parse(p[1]));
  }

  DateTime endToday() {
    final now = DateTime.now();
    final p = endTime.split(':');
    return DateTime(now.year, now.month, now.day, int.parse(p[0]), int.parse(p[1]));
  }
}