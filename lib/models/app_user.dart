class AppUser {
  final String id;
  final String role; // 'admin' | 'teacher'
  final String name;
  final String phone;
  final String? subject;
  final String? section;
  final bool isActive;

  const AppUser({
    required this.id,
    required this.role,
    required this.name,
    required this.phone,
    this.subject,
    this.section,
    this.isActive = true,
  });

  bool get isAdmin => role == 'admin';

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        role: j['role'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String,
        subject: j['subject'] as String?,
        section: j['section'] as String?,
        isActive: (j['is_active'] as bool?) ?? true,
      );

  Map<String, dynamic> toSession() => {
        'id': id,
        'role': role,
        'name': name,
        'phone': phone,
        'subject': subject,
        'section': section,
      };

  factory AppUser.fromSession(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        role: j['role'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String,
        subject: j['subject'] as String?,
        section: j['section'] as String?,
      );
}