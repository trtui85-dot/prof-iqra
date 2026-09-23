import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/schedule_entry.dart';

/// تذكيرات محلية قبل موعد كل حصة (تُبرمَج عند الدخول وتتكرر أسبوعياً)
class LocalNotifService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Africa/Nouakchott'));
    }
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );
    await _plugin.initialize(settings: settings);
    _ready = true;
  }

  static Future<void> scheduleForWeek(List<ScheduleEntry> entries) async {
    await _plugin.cancelAllPendingNotifications();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'iqra_reminders',
        'تذكيرات الحصص',
        channelDescription: 'تذكير قبل بداية كل حصة',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: DarwinNotificationDetails(),
    );

    int id = 0;
    for (final e in entries) {
      id++;
      final when = nextOccurrence(e);
      await _plugin.zonedSchedule(
        id: id,
        title: 'حصة اليوم',
        body: 'ستبدأ حصة «${e.className}» قريباً — الساعة ${e.startTime}.',
        scheduledDate: when,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  /// أول موعد قادم لبداية الحصة من الآن، ثم نُطرح منه 10 دقائق
  static tz.TZDateTime nextOccurrence(ScheduleEntry e) {
    final now = tz.TZDateTime.now(tz.local);
    final p = e.startTime.split(':');
    for (int i = 0; i < 7; i++) {
      final day = now.add(Duration(days: i));
      final candidate = tz.TZDateTime(
        tz.local,
        day.year,
        day.month,
        day.day,
        int.parse(p[0]),
        int.parse(p[1]),
      );
      if (candidate.weekday == e.dayOfWeek && candidate.isAfter(now)) {
        return candidate.subtract(const Duration(minutes: 10));
      }
    }
    return now.add(const Duration(minutes: 1));
  }
}