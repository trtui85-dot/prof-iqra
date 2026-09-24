class AttendanceLog {
  final String id;
  final String teacherId;
  final String? scheduleId;
  final String? className;
  final String entryDate; // yyyy-MM-dd
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String status; // present | late | absent
  final int? lateMinutes; // عدد دقائق التأخير إن وُجد

  const AttendanceLog({
    required this.id,
    required this.teacherId,
    this.scheduleId,
    this.className,
    required this.entryDate,
    this.checkIn,
    this.checkOut,
    required this.status,
    this.lateMinutes,
  });

  factory AttendanceLog.fromJson(Map<String, dynamic> j) {
    final rawDate = j['entry_date'] as String? ?? '';
    return AttendanceLog(
      id: j['id'] as String? ?? '',
      teacherId: j['teacher_id'] as String? ?? '',
      scheduleId: j['schedule_id'] as String?,
      className: j['class_name'] as String?,
      entryDate: rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate,
      checkIn: j['check_in_time'] != null
          ? DateTime.tryParse(j['check_in_time'] as String)?.toLocal()
          : null,
      checkOut: j['check_out_time'] != null
          ? DateTime.tryParse(j['check_out_time'] as String)?.toLocal()
          : null,
      status: (j['status'] as String?) ?? 'absent',
      lateMinutes: (j['late_minutes'] as num?)?.toInt(),
    );
  }

  String get statusLabel => switch (status) {
        'present' => 'حاضر',
        'late' => 'متأخر',
        _ => 'غائب',
      };
}