import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/ios_bottom_bar.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/app_notification.dart';
import '../../models/app_user.dart';
import '../../services/attendance_service.dart';
import '../../services/auth_service.dart';
import '../../services/fcm_service.dart';
import '../../services/local_notif_service.dart';
import '../../services/notification_service.dart';
import '../../services/schedule_service.dart';
import '../../services/update_service.dart';
import 'my_record_page.dart';
import 'notifications_page.dart';
import 'scan_page.dart';
import 'schedule_page.dart';

class TeacherHome extends StatefulWidget {
  final AppUser user;
  const TeacherHome({super.key, required this.user});

  @override
  State<TeacherHome> createState() => _TeacherHomeState();
}

class _TeacherHomeState extends State<TeacherHome> {
  int _index = 0;
  int _unread = 0;
  late final List<Widget> _tabs;
  sb.RealtimeChannel? _channel;
  Timer? _endingTimer;

  @override
  void initState() {
    super.initState();
    _tabs = [
      SchedulePage(teacher: widget.user),
      ScanPage(teacher: widget.user),
      MyRecordPage(teacher: widget.user),
      NotificationsPage(teacher: widget.user),
    ];
    _init();
    // فحص كل دقيقة: إن انتهت الحصة ولا توجد بعدها حصة يُغلق تلقائياً
    _endingTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      try {
        // ignore: discarded_futures
        AttendanceService()
            .autoCloseExpiredSessions(widget.user.id, DateTime.now());
      } catch (_) {}
    });
  }

  Future<void> _init() async {
    try {
      _unread = await NotificationService().unreadCount(widget.user.id);
      _channel = NotificationService()
          .subscribeUser(widget.user.id, (AppNotification n) {
        if (mounted) setState(() => _unread++);
      });
      final schedule =
          await ScheduleService().listForTeacher(widget.user.id);
      await LocalNotifService.scheduleForWeek(schedule);
    } catch (_) {}
    if (!mounted) return;
    // إشعارات Firebase + فحص التحديث (لا تعطل أي تجربة عند الفشل)
    try {
      // ignore: discarded_futures
      FcmService.registerToken(widget.user.id);
      // ignore: discarded_futures
      UpdateService.checkAndUpdate(context, force: false);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _endingTimer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _logout() async {
    if (!mounted) return;
    final ok = await confirmDialog(
      context,
      title: 'تسجيل الخروج',
      message: 'هل تريد فعلاً تسجيل الخروج؟',
    );
    if (!ok || !mounted) return;
    await AuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('أهلاً، ${widget.user.name}'),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: AppColors.textMuted),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: IosBottomBar(
        index: _index,
        onTap: (i) => setState(() => _index = i),
        items: [
          const IosTabItem(
            icon: Icon(Icons.calendar_month_outlined, color: AppColors.textMuted),
            selectedIcon: Icon(Icons.calendar_month, color: AppColors.primary),
            label: 'جدولي',
          ),
          const IosTabItem(
            icon: Icon(Icons.qr_code_scanner, color: AppColors.textMuted),
            selectedIcon: Icon(Icons.qr_code_scanner, color: AppColors.primary),
            label: 'مسح الحضور',
          ),
          const IosTabItem(
            icon: Icon(Icons.history_outlined, color: AppColors.textMuted),
            selectedIcon: Icon(Icons.history, color: AppColors.primary),
            label: 'سجلّي',
          ),
          IosTabItem(
            icon: Badge(
              isLabelVisible: _unread > 0,
              label: Text('$_unread'),
              backgroundColor: AppColors.absent,
              child: const Icon(Icons.notifications_outlined,
                  color: AppColors.textMuted),
            ),
            selectedIcon: Badge(
              isLabelVisible: _unread > 0,
              label: Text('$_unread'),
              backgroundColor: AppColors.absent,
              child:
                  const Icon(Icons.notifications, color: AppColors.primary),
            ),
            label: 'الإشعارات',
          ),
        ],
      ),
    );
  }
}