import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/security.dart';
import '../core/supabase.dart';
import '../models/app_user.dart';

class AuthService {
  static const _sessionKey = 'iqra_session_v1';

  Future<AppUser?> login({required String phone, required String pin}) async {
    final res = await db
        .from('users')
        .select()
        .eq('phone', SecureAuth.normalizePhone(phone))
        .eq('is_active', true)
        .order('created_at', ascending: true)
        .limit(1)
        .maybeSingle();
    if (res == null) return null;
    if (res['pin_hash'] != SecureAuth.hashPin(pin)) return null;

    final user = AppUser.fromJson(res);
    await _save(user);
    return user;
  }

  Future<AppUser?> currentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null) return null;
    AppUser session;
    try {
      session = AppUser.fromSession(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
    try {
      final res = await db
          .from('users')
          .select()
          .eq('id', session.id)
          .maybeSingle();
      if (res == null) return null;
      final user = AppUser.fromJson(res);
      if (!user.isActive) return null;
      await _save(user);
      return user;
    } catch (_) {
      return session;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  Future<void> _save(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(user.toSession()));
  }
}