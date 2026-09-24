class AppNotification {
  final String id;
  final String userId;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String? ?? '',
        userId: j['user_id'] as String? ?? '',
        message: j['message'] as String? ?? 'إشعار جديد',
        isRead: (j['is_read'] as bool?) ?? false,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '')
                ?.toLocal() ??
            DateTime.now(),
      );

  String get timeAgo {
    final d = DateTime.now().difference(createdAt);
    if (d.inMinutes < 1) return 'الآن';
    if (d.inHours < 1) return 'منذ ${d.inMinutes} دقيقة';
    if (d.inDays < 1) return 'منذ ${d.inHours} ساعة';
    return 'منذ ${d.inDays} يوم';
  }
}