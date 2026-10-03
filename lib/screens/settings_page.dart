import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/widgets.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'legal_page.dart';

class SettingsPage extends StatefulWidget {
  final AppUser user;
  const SettingsPage({super.key, required this.user});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _busy = false;

  Future<void> _logout() async {
    await AuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  Future<void> _deleteAccount() async {
    final ok = await confirmDialog(
      context,
      title: 'حذف الحساب نهائياً',
      message:
          'سيُحذف حسابك وكل بياناته (الجدول، سجلات الحضور، الإشعارات) نهائياً ولا يمكن التراجع عن ذلك. هل أنت متأكد؟',
      confirmLabel: 'حذف نهائي',
      danger: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await UserService().deleteAccount(widget.user);
      await AuthService().logout();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    } catch (e) {
      if (mounted) showError(context, 'تعذّر حذف الحساب، حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _option(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color? color,
    bool danger = false,
  }) {
    final c = danger ? AppColors.absent : (color ?? AppColors.primary);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: c),
          const SizedBox(width: 12),
          Text(
            label,
            style: AppText.bold(
              14.5,
            ).copyWith(color: danger ? AppColors.absent : null),
          ),
          const Spacer(),
          const Icon(Icons.chevron_left, color: AppColors.textMuted),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
      child: Text(
        t,
        style: AppText.bold(13).copyWith(color: AppColors.textMuted),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    u.name.isNotEmpty ? u.name[0] : '؟',
                    style: AppText.heading(
                      22,
                    ).copyWith(color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.name, style: AppText.heading(17)),
                      const SizedBox(height: 2),
                      Text(
                        u.isAdmin ? 'إدارة النظام' : 'أستاذ',
                        style: AppText.muted(13),
                      ),
                      const SizedBox(height: 2),
                      Text(u.phone, style: AppText.muted(12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _sectionTitle('الحساب'),
          _option(Icons.logout, 'تسجيل الخروج', _busy ? () {} : _logout),
          const SizedBox(height: 10),
          _option(
            Icons.delete_forever_outlined,
            _busy ? 'جارٍ الحذف...' : 'حذف حسابي',
            _busy ? () {} : _deleteAccount,
            danger: true,
          ),
          _sectionTitle('التطبيق'),
          _option(Icons.privacy_tip_outlined, 'سياسة الخصوصية', () {
            LegalPage.show(
              context,
              title: 'سياسة الخصوصية',
              sections: kPrivacyPolicySections,
            );
          }),
          const SizedBox(height: 10),
          _option(Icons.description_outlined, 'شروط الاستخدام', () {
            LegalPage.show(
              context,
              title: 'شروط الاستخدام',
              sections: kTermsOfUseSections,
            );
          }),
          const SizedBox(height: 10),
          _option(Icons.info_outline, 'حول التطبيق', () {
            showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('حول التطبيق'),
                content: const Text(
                  'أساتذة اقرأ — متابعة حضور الأساتذة وجدول الحصص.\nالنسخة 1.0.0',
                  style: TextStyle(height: 1.6, fontFamily: 'Thmanyah'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('حسناً'),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
