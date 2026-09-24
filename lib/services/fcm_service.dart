import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../core/supabase.dart';
import 'local_notif_service.dart';

/// معالج الرسائل عند وصول إشعار والتطبيق مغلق تماماً (isolate منفصل)
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  final n = message.notification;
  if (n == null) return;
  // تهيئة الإشعارات المحلية داخل هذا الـ isolate ثم عرض الإشعار
  try {
    await LocalNotifService.init();
    await LocalNotifService.showNow(title: n.title ?? '', body: n.body ?? '');
  } catch (_) {}
}

class FcmService {
  static bool _ready = false;
  static String _defaultUserId = '';

  /// تهيئة Firebase والإشعارات المحلية بأمان:
  /// بدون ملفات google-services يكتفي بالسكوت (سلامة android build).
  static Future<void> init() async {
    if (_ready) return;
    try {
      await Firebase.initializeApp();
    } catch (_) {
      return;
    }
    final messaging = FirebaseMessaging.instance;
    try {
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}
    messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
    // وصول إشعار والتطبيق مفتوح/في الخلفية → إشعار محلي فوري
    // ignore: discarded_futures
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final n = message.notification;
      if (n == null) return;
      try {
        await LocalNotifService.showNow(
          title: n.title ?? '',
          body: n.body ?? '',
        );
      } catch (_) {}
    });
    // إعادة الإرسال عند تحديث الرمز
    // ignore: discarded_futures
    messaging.onTokenRefresh.listen(_saveToken);
    _ready = true;
  }

  /// يسجّل رمز الجهاز الحالي لدى المستخدم [userId]
  static Future<void> registerToken(String userId) async {
    if (!_ready) {
      await init();
      if (!_ready) return;
    }
    _defaultUserId = userId;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _saveToken(token);
    } catch (_) {}
  }

  static Future<void> _saveToken(String token) async {
    if (_defaultUserId.isEmpty) return;
    try {
      await db.from('users').update({'fcm_token': token}).eq('id', _defaultUserId);
    } catch (_) {}
  }
}