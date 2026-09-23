import '../core/supabase.dart';
import '../models/schedule_entry.dart';

class ScheduleService {
  Future<List<ScheduleEntry>> listForTeacher(String teacherId) async {
    final res = await db
        .from('schedule')
        .select()
        .eq('teacher_id', teacherId)
        .order('day_of_week')
        .order('start_time');
    final entries = res.map(ScheduleEntry.fromJson).toList();
    const order = {1: 0, 2: 1, 3: 2, 4: 3, 5: 4, 6: 5, 7: 6};
    entries.sort((a, b) => order[a.dayOfWeek]!.compareTo(order[b.dayOfWeek]!));
    return entries;
  }

  Future<void> add({
    required String teacherId,
    required int dayOfWeek,
    required String startTime, // 'HH:mm'
    required String endTime,
    required String className,
  }) async {
    await db.from('schedule').insert({
      'teacher_id': teacherId,
      'day_of_week': dayOfWeek,
      'start_time': '$startTime:00',
      'end_time': '$endTime:00',
      'class_name': className.trim(),
    });
  }

  Future<void> update(
    String id, {
    int? dayOfWeek,
    String? startTime,
    String? endTime,
    String? className,
  }) async {
final data = <String, dynamic>{
      'day_of_week': ?dayOfWeek,
      'start_time': ?(startTime != null ? '$startTime:00' : null),
      'end_time': ?(endTime != null ? '$endTime:00' : null),
      'class_name': ?className?.trim(),
    };
    await db.from('schedule').update(data).eq('id', id);
  }

  Future<void> delete(String id) async {
    await db.from('schedule').delete().eq('id', id);
  }
}