import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/errors.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/app_user.dart';
import '../../services/user_service.dart';

class TeacherFormPage extends StatefulWidget {
  final AppUser? teacher;
  const TeacherFormPage({super.key, this.teacher});

  @override
  State<TeacherFormPage> createState() => _TeacherFormPageState();
}

class _TeacherFormPageState extends State<TeacherFormPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _pin;
  late final TextEditingController _subject;
  late final TextEditingController _section;
  late bool _active;
  bool _loading = false;

  bool get _isNew => widget.teacher == null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.teacher?.name ?? '');
    _phone = TextEditingController(text: widget.teacher?.phone ?? '');
    _pin = TextEditingController();
    _subject = TextEditingController(text: widget.teacher?.subject ?? '');
    _section = TextEditingController(text: widget.teacher?.section ?? '');
    _active = widget.teacher?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _pin.dispose();
    _subject.dispose();
    _section.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_isNew && _pin.text.trim().length < 4) {
      showError(context, 'كود PIN يجب أن يكون 4 أرقام على الأقل.');
      return;
    }
    setState(() => _loading = true);
    try {
      final service = UserService();
      if (_isNew) {
        await service.createTeacher(
          name: _name.text,
          phone: _phone.text,
          pin: _pin.text,
          subject: _subject.text,
          section: _section.text,
        );
        if (mounted) showSuccess(context, 'تم إنشاء حساب الأستاذ.');
      } else {
        await service.updateTeacher(
          widget.teacher!.id,
          name: _name.text,
          phone: _phone.text,
          subject: _subject.text,
          section: _section.text,
          isActive: _active,
        );
        if (mounted) showSuccess(context, 'تم حفظ التعديلات.');
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        showError(context, arabicErrorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? 'إضافة أستاذ جديد' : 'تعديل الأستاذ')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'أدخل الاسم' : null,
                decoration: const InputDecoration(
                  labelText: 'الاسم الكامل',
                  prefixIcon: Icon(Icons.person_outline, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().length < 6) ? 'أدخل رقم هاتف صحيح' : null,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  prefixIcon: Icon(Icons.phone_android, color: AppColors.textMuted),
                ),
              ),
              if (_isNew) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _pin,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) => (v == null || v.trim().length < 4)
                      ? 'PIN من 4 أرقام على الأقل'
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'كود PIN (للتسجيل)',
                    counterText: '',
                    prefixIcon: Icon(Icons.pin_outlined, color: AppColors.textMuted),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _subject,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'المادة (اختياري)',
                  prefixIcon: Icon(Icons.menu_book_outlined, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _section,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'الأقسام التي يدرّسها (اختياري)',
                  prefixIcon: Icon(Icons.class_outlined, color: AppColors.textMuted),
                ),
              ),
              if (!_isNew) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('حساب نشط', style: AppText.normal(14)),
                  subtitle: Text(
                    'عند الإيقاف لا يستطيع الأستاذ تسجيل الدخول',
                    style: AppText.muted(12),
                  ),
                  value: _active,
                  activeTrackColor: AppColors.primary.withValues(alpha: .4),
                  onChanged: (v) => setState(() => _active = v),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text(_isNew ? 'إنشاء الحساب' : 'حفظ التعديلات'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}