import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/fcm_service.dart';
import '../../services/update_service.dart';
import 'live_attendance_page.dart';
import 'qr_page.dart';
import 'reports_page.dart';
import 'teachers_page.dart';

class AdminHome extends StatefulWidget {
  final AppUser user;
  const AdminHome({super.key, required this.user});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _index = 0;
  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      LiveAttendancePage(admin: widget.user),
      TeachersPage(admin: widget.user),
      ReportsPage(admin: widget.user),
      QrPage(admin: widget.user),
    ];
    // إشعارات Firebase + تحديث فوري إجباري عند توفر نسخة جديدة
    // ignore: discarded_futures
    FcmService.registerToken(widget.user.id);
    // ignore: discarded_futures
    UpdateService.checkAndUpdate(context, force: true);
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
        title: Text('لوحة الإدارة'),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: AppColors.textMuted),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        indicatorColor: AppColors.primarySoft,
        backgroundColor: AppColors.surface,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.groups_outlined, color: AppColors.textMuted),
            selectedIcon: Icon(Icons.groups, color: AppColors.primary),
            label: 'اليوم',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline, color: AppColors.textMuted),
            selectedIcon: Icon(Icons.people, color: AppColors.primary),
            label: 'الأساتذة',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined, color: AppColors.textMuted),
            selectedIcon: Icon(Icons.bar_chart, color: AppColors.primary),
            label: 'التقارير',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_2_outlined, color: AppColors.textMuted),
            selectedIcon: Icon(Icons.qr_code_2, color: AppColors.primary),
            label: 'كود الدخول',
          ),
        ],
      ),
    );
  }
}