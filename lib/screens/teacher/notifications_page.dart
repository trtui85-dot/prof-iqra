import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/app_notification.dart';
import '../../models/app_user.dart';
import '../../services/notification_service.dart';

class NotificationsPage extends StatefulWidget {
  final AppUser teacher;
  const NotificationsPage({super.key, required this.teacher});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _service = NotificationService();
  bool _loading = true;
  List<AppNotification> _list = [];
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = _service.subscribeUser(widget.teacher.id, (_) {
      _load(silent: true);
    });
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final list = await _service.listFor(widget.teacher.id);
    if (!mounted) return;
    setState(() {
      _list = list;
      _loading = false;
    });
    await _service.markAllRead(widget.teacher.id);
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading && _list.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _list.isEmpty
              ? const EmptyState(
                  'لا توجد إشعارات بعد.\nكل مسحة سيظهر تأكيدها هنا.',
                  icon: Icons.notifications_none,
                )
              : RefreshIndicator(
                  onRefresh: () => _load(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _list.length,
                    itemBuilder: (context, i) {
                      final n = _list[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.notifications_outlined,
                                    color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(n.message,
                                        style: AppText.normal(13.5)),
                                    const SizedBox(height: 6),
                                    Text(n.timeAgo, style: AppText.muted(11.5)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}