import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

Future<void> initSupabase() async {
  await dotenv.load();
  if (!AppEnv.isConfigured) {
    throw StateError(
      'Supabase غير مُهيّأ. ضع SUPABASE_ANON_KEY في ملف .env '
      'من مشروعك على Supabase (Settings > API Keys > anon public).',
    );
  }
  await Supabase.initialize(
    url: AppEnv.supabaseUrl,
    publishableKey: AppEnv.supabaseAnonKey,
  );
}

SupabaseClient get db => Supabase.instance.client;