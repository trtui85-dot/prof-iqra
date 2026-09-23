import 'package:flutter/material.dart';

import '../core/env.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import 'admin/admin_home.dart';
import 'login_screen.dart';
import 'teacher/teacher_home.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    if (!AppEnv.isConfigured) {
      _showConfigError();
      return;
    }
    try {
      final user = await AuthService().currentUser();
      _go(user);
    } catch (e) {
      _go(null);
    }
  }

  void _showConfigError() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => const _ConfigErrorScreen(),
    ));
  }

  void _go(AppUser? user) {
    if (user == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else if (user.isAdmin) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => AdminHome(user: user)),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => TeacherHome(user: user)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.school_outlined,
                  size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Text('أساتذة اقرأ', style: AppText.title(context)),
            const SizedBox(height: 8),
            Text('متابعة الحضور والجدول', style: AppText.muted(14)),
            const SizedBox(height: 32),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfigErrorScreen extends StatelessWidget {
  const _ConfigErrorScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: AppCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    color: AppColors.absent, size: 48),
                const SizedBox(height: 16),
                Text('Supabase غير مُهيأ', style: AppText.heading(18)),
                const SizedBox(height: 8),
                Text(
                  'ضع SUPABASE_URL و SUPABASE_ANON_KEY في ملف .env '
                  '(من Settings > API Keys في مشروعك على Supabase) ثم أعد تشغيل التطبيق.',
                  style: AppText.normal(14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}