import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../core/widgets.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import 'admin/admin_home.dart';
import 'teacher/teacher_home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _pin = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  Future<void> _submit() async {
    final phone = _phone.text.trim();
    final pin = _pin.text.trim();
    if (phone.isEmpty || pin.isEmpty) {
      showError(context, 'أدخل رقم الهاتف وكود PIN.');
      return;
    }
    setState(() => _loading = true);
    try {
      final AppUser? user = await AuthService().login(phone: phone, pin: pin);
      if (!mounted) return;
      if (user == null) {
        showError(context, 'بيانات الدخول غير صحيحة.');
        return;
      }
      final next = user.isAdmin
          ? AdminHome(user: user)
          : TeacherHome(user: user);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => next),
      );
    } catch (e) {
      if (mounted) showError(context, 'تعذّر الاتصال: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: const Image(
                      image: AssetImage('assets/icon/iqra_logo.png'),
                      width: 84,
                      height: 84,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Text('تسجيل الدخول',
                    style: AppText.heading(22), textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text('مرحباً بك في تطبيق أساتذة اقرأ',
                    style: AppText.muted(14), textAlign: TextAlign.center),
                const SizedBox(height: 32),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف',
                    hintText: 'مثال: 0660000000',
                    prefixIcon: Icon(Icons.phone_android, color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _pin,
                  obscureText: _obscure,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  maxLength: 6,
                  onSubmitted: (_) => _submit(),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'كود PIN',
                    counterText: '',
                    prefixIcon:
                        const Icon(Icons.lock_outline, color: AppColors.textMuted),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textMuted,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ))
                      : const Text('دخول'),
                ),
                const SizedBox(height: 28),
                Center(
                  child: Text(
                    'تُنشئ الإدارة حسابات الأساتذة، '
                    'تسجيل الدخول برقم الهاتف وكود PIN فقط',
                    style: AppText.muted(12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}