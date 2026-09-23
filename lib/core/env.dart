import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  static bool get _loaded => dotenv.isInitialized;

  static String get supabaseUrl =>
      _loaded ? dotenv.env['SUPABASE_URL'] ?? '' : '';
  static String get supabaseAnonKey =>
      _loaded ? dotenv.env['SUPABASE_ANON_KEY'] ?? '' : '';

  static bool get isConfigured => _loaded && 
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}