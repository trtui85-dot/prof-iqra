import '../core/security.dart';
import '../core/supabase.dart';
import '../models/app_user.dart';

/// إدارة الأساتذة (لوحة الإدارة)
class UserService {
  static String? _trimmed(String? s) =>
      (s == null || s.trim().isEmpty) ? null : s.trim();

  Future<List<AppUser>> listTeachers() async {
    final res = await db
        .from('users')
        .select()
        .eq('role', 'teacher')
        .order('name');
    return res.map(AppUser.fromJson).toList();
  }

  Future<AppUser> createTeacher({
    required String name,
    required String phone,
    required String pin,
    String? subject,
    String? section,
  }) async {
    final normalized = SecureAuth.normalizePhone(phone);
    final dup = await _phoneExists(normalized);
    if (dup) throw Exception('رقم الهاتف مستخدم مسبقاً من قبل أستاذ آخر.');
    final res = await db.from('users').insert({
      'role': 'teacher',
      'name': name.trim(),
      'phone': normalized,
      'pin_hash': SecureAuth.hashPin(pin),
      'subject': ?_trimmed(subject),
      'section': ?_trimmed(section),
      'is_active': true,
    }).select().single();
    return AppUser.fromJson(res);
  }

  Future<bool> _phoneExists(String phone) async {
    final res = await db
        .from('users')
        .select('id')
        .eq('phone', phone)
        .limit(1)
        .maybeSingle();
    return res != null;
  }

  Future<void> updateTeacher(
    String id, {
    String? name,
    String? phone,
    String? subject,
    String? section,
    bool? isActive,
  }) async {
    final data = <String, dynamic>{
      if (name != null) 'name': name.trim(),
      if (phone != null) 'phone': SecureAuth.normalizePhone(phone),
      'subject': ?_trimmed(subject),
      'section': ?_trimmed(section),
      'is_active': ?isActive,
    };
    await db.from('users').update(data).eq('id', id);
  }

  Future<void> resetPin(String id, String newPin) async {
    await db
        .from('users')
        .update({'pin_hash': SecureAuth.hashPin(newPin)})
        .eq('id', id);
  }

  Future<void> deleteTeacher(String id) async {
    await db.from('users').delete().eq('id', id);
  }

  Future<List<AppUser>> listAdmins() async {
    final res = await db.from('users').select().eq('role', 'admin');
    return res.map(AppUser.fromJson).toList();
  }
}