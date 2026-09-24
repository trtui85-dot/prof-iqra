import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/supabase.dart';
import 'services/fcm_service.dart';
import 'services/local_notif_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');
  await LocalNotifService.init();
  try {
    await initSupabase();
  } catch (_) {
    // عدم اكتمال الإعداد يُعالَج داخل SplashScreen
  }
  // Firebase تُهيّأ بأمان: بدون google-services.json تُتجاهَل بصمت
  try {
    await FcmService.init();
  } catch (_) {}
  runApp(const IqraApp());
}