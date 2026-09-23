import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/app_user.dart';
import '../../services/pdf_service.dart';
import '../../services/user_service.dart';
import 'schedule_builder_page.dart';
import 'teacher_form_page.dart';

class TeacherDetailPage extends StatefulWidget {
  final AppUser teacher;
  const TeacherDetailPage({super.key, required this.teacher});

  @override
  State<TeacherDetailPage> createState() => _TeacherDetailPageState();
}

class _TeacherDetailPageState extends State<TeacherDetailPage> {
  Future<void> _edit() async {
    await _go(TeacherFormPage(teacher: widget.teacher));
  }

  Future<void> _schedule() async {
    await _go(ScheduleBuilderPage(teacher: widget.teacher));
  }

  Future<void> _downloadPdf() => _sharePdfAs(
      () => PdfService().teacherProfilePdf(context, widget.teacher),
      filename: 'iqra_teacher_profile.pdf',
    );

  Future<void> _downloadWeeklyReport() => _sharePdfAs(
        () => PdfService().teacherWeeklyReportPdf(context, widget.teacher),
        filename: 'iqra_weekly_report.pdf',
      );

  Future<void> _sharePdfAs(
    Future<Uint8List> Function() generate, {
    required String filename,
  }) async {
    final busy = ValueNotifier<bool>(false);
    // نافذة انتظار أثناء توليد ملف PDF
    // ignore: unused_result
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ValueListenableBuilder<bool>(
        valueListenable: busy,
        builder: (ctx, isBusy, _) => PopScope(
          canPop: !isBusy,
          child: AlertDialog(
            content: Row(children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(width: 18),
              Expanded(
                child: Text(isBusy ? 'جارٍ التحضير...' : 'تجهيز ملف PDF...',
                    style: AppText.normal(14)),
              ),
            ]),
          ),
        ),
      ),
    );
    try {
      final bytes = await generate();
      if (!mounted) {
        busy.dispose();
        return;
      }
      busy.value = true;
      await Printing.sharePdf(
        bytes: bytes,
        filename: filename,
      );
    } catch (e) {
      if (mounted) showError(context, 'فشل إنشاء ملف PDF.');
    } finally {
      if (mounted) Navigator.of(context).pop();
      busy.dispose();
    }
  }

  Future<void> _go(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() {});
  }

  Future<void> _resetPin() async {
    final controller = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إعادة تعيين كود PIN'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'PIN الجديد',
            counterText: '',
            hintText: '4 أرقام على الأقل',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حفظ')),
        ],
      ),
    );
    if (submitted != true) return;
    if (controller.text.trim().length < 4) {
      if (mounted) showError(context, 'PIN يجب أن يكون 4 أرقام على الأقل.');
      return;
    }
    try {
      await UserService().resetPin(widget.teacher.id, controller.text.trim());
      if (mounted) showSuccess(context, 'تم تغيير كود PIN.');
    } catch (e) {
      if (mounted) showError(context, 'فشل التغيير.');
    }
    controller.dispose();
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'حذف الأستاذ',
      message: 'سيُحذف الحساب وجدوله وسجلاته نهائياً. هل أنت متأكد؟',
      confirmLabel: 'حذف',
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      await UserService().deleteTeacher(widget.teacher.id);
      if (!mounted) return;
      showSuccess(context, 'تم حذف الأستاذ.');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showError(context, 'فشل الحذف.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.teacher;
    return Scaffold(
      appBar: AppBar(title: Text(t.name)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: Text(t.name.isNotEmpty ? t.name[0] : '?',
                        style: AppText.heading(22).copyWith(color: AppColors.primary)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.name, style: AppText.heading(18)),
                        const SizedBox(height: 2),
                        Text(t.phone, style: AppText.muted(13)),
                      ],
                    ),
                  ),
                  Spacer(),
                  if (!t.isActive) StatusChip('absent'),
                ]),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 6),
                _infoRow(Icons.menu_book_outlined, 'المادة',
                    t.subject ?? '—'),
                _infoRow(Icons.class_outlined, 'الأقسام', t.section ?? '—'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _action(Icons.edit_outlined, 'تعديل البيانات', AppColors.primary, _edit),
          const SizedBox(height: 10),
          _action(Icons.calendar_month_outlined, 'بناء الجدول الأسبوعي',
              AppColors.primary, _schedule),
          const SizedBox(height: 10),
          _action(Icons.picture_as_pdf_outlined, 'تحميل بطاقة الأستاذ (PDF)',
              AppColors.primary, _downloadPdf),
          const SizedBox(height: 10),
          _action(Icons.assignment_outlined, 'تحميل تقرير الحضور الأسبوعي (PDF)',
              AppColors.primary, _downloadWeeklyReport),
          const SizedBox(height: 10),
          _action(Icons.pin_outlined, 'إعادة تعيين كود PIN', AppColors.late,
              _resetPin),
          const SizedBox(height: 10),
          _action(Icons.delete_outline, 'حذف الأستاذ', AppColors.absent,
              _delete),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Text('$label: ', style: AppText.bold(13.5)),
          Expanded(
              child: Text(value,
                  style: AppText.normal(13.5), textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Widget _action(IconData icon, String label, Color color, VoidCallback onTap) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Text(label, style: AppText.bold(14.5)),
        const Spacer(),
        const Icon(Icons.chevron_left, color: AppColors.textMuted),
      ]),
    );
  }
}