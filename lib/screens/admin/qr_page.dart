import 'dart:math';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/supabase.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/app_user.dart';
import '../../services/attendance_service.dart';

class QrPage extends StatefulWidget {
  final AppUser admin;
  const QrPage({super.key, required this.admin});

  @override
  State<QrPage> createState() => _QrPageState();
}

class _QrPageState extends State<QrPage> {
  String? _secret;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await db
          .from('app_settings')
          .select('value')
          .eq('key', 'qr_secret')
          .limit(1)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _secret = res?['value'] as String? ?? '';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String get _payload => '${AttendanceService.qrPrefix}$_secret';

  Future<void> _regenerate() async {
    final ok = await confirmDialog(
      context,
      title: 'تجديد رمز QR',
      message: 'بهذا يُلغى الرمز الحالي فوراً ولا يعمل أي رمز قديم. متابعة؟',
      confirmLabel: 'تجديد',
      danger: true,
    );
    if (!ok || !mounted) return;
    final rng = Random.secure();
    final newSecret =
        List.generate(32, (_) => rng.nextInt(16).toRadixString(16)).join();
    try {
      await db
          .from('app_settings')
          .update({
            'value': newSecret,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('key', 'qr_secret');
      if (!mounted) return;
      setState(() => _secret = newSecret);
      showSuccess(context, 'تم تجديد الرمز، اطبع الرمز الجديد.');
    } catch (_) {
      if (mounted) showError(context, 'فشل تجديد الرمز.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 6),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.qr_code_2, size: 40, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 16),
        Text('رمز الدخول الموحّد',
            style: AppText.heading(18), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          'عرّض هذا الرمز في مكان الدخول. '
          'يمسحه الأستاذ لتسجيل حضوره وانصرافه، '
          'ويتعرّف التطبيق على الأستاذ من حسابه عند المسح.',
          style: AppText.normal(13.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        AppCard(
          padding: const EdgeInsets.all(20),
          child: _loading
              ? const SizedBox(
                  height: 260,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              : Column(children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: QrImageView(
                      data: _payload,
                      version: QrVersions.auto,
                      size: 240,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: AppColors.textDark,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // طباعة من بطاقة العرض
                  Text(
                    'الرمز واحد لكل الأساتذة ويُتعرّف الحساب عند المسح',
                    style: AppText.muted(12),
                    textAlign: TextAlign.center,
                  ),
                ]),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            foregroundColor: AppColors.absent,
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: _regenerate,
          icon: const Icon(Icons.refresh),
          label: const Text('تجديد الرمز'),
        ),
      ],
    );
  }
}