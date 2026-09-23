import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase.dart';
import '../models/app_notification.dart';
import 'user_service.dart';

class NotificationService {
  Future<void> notifyUser(String userId, String message) async {
    await db.from('notifications').insert({
      'user_id': userId,
      'message': message,
      'is_read': false,
    });
  }

  Future<void> notifyAdmins(String message) async {
    final admins = await UserService().listAdmins();
    for (final a in admins) {
      await notifyUser(a.id, message);
    }
  }

  Future<List<AppNotification>> listFor(String userId) async {
    final res = await db
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(100);
    return res.map(AppNotification.fromJson).toList();
  }

  Future<int> unreadCount(String userId) async {
    final res = await db
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);
    return res.length;
  }

  Future<void> markAllRead(String userId) async {
    await db
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  /// اشتراك بثّ حيّ للإشعارات الخاصة بمستخدم واحد
  RealtimeChannel subscribeUser(
    String userId,
    void Function(AppNotification notif) onNew,
  ) {
    return db
        .channel('my-notifs-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final data = payload.newRecord;
            onNew(AppNotification.fromJson(data));
          },
        )
        .subscribe();
  }
}