import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/app_user.dart';
import '../../services/summary_service.dart';
import '../../services/user_service.dart';
import '../../widgets/landscape_cards.dart';
import '../summary_preview_page.dart';
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

  Future<void> _openTeacherCard() => _openSummary(
        title: 'بطاقة الأستاذ',
        fileName: 'iqra-teacher-card',
        buildCards: () async {
          final summary = await SummaryService().teacherSummary(widget.teacher);
          return teacherSummaryPages(summary);
        },
      );

  Future<void> _openWeeklyReport() => _chooseReportRange();

  Future<void> _chooseReportRange() async {
    final range = await showModalBottomSheet<ReportRange>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('اختر نوع التقرير',
                  style: AppText.heading(18), textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text('يومي أو أسبوعي أو شهري',
                  style: AppText.muted(12), textAlign: TextAlign.center),
              const SizedBox(height: 14),
              _rangeOption(ctx, ReportRange.daily, Icons.today_outlined,
                  'التقرير اليومي', 'حصص اليوم وحالتها'),
              const SizedBox(height: 8),
              _rangeOption(ctx, ReportRange.weekly, Icons.date_range_outlined,
                  'التقرير الأسبوعي', 'من الاثنين إلى الأحد'),
              const SizedBox(height: 8),
              _rangeOption(ctx, ReportRange.monthly, Icons.calendar_month_outlined,
                  'التقرير الشهري', 'الشهر الحالي كاملاً'),
            ],
          ),
        ),
      ),
    );
    if (range == null || !mounted) return;
    await _openSummary(
      title: range.label,
      fileName: range.fileName,
      buildCards: () async {
        final (start, end) = switch (range) {
          ReportRange.daily => SummaryService.todayRange(),
          ReportRange.weekly => SummaryService.weekRange(),
          ReportRange.monthly => SummaryService.monthRange(),
        };
        final data = await SummaryService().rangeSummary(widget.teacher, start, end);
        return reportPages(widget.teacher, data, range);
      },
    );
  }

  Widget _rangeOption(BuildContext ctx, ReportRange range, IconData icon,
      String title, String subtitle) {
    return InkWell(
      onTap: () => Navigator.pop(ctx, range),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.bold(15)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppText.muted(12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_left, color: AppColors.textMuted),
        ]),
      ),
    );
  }

  Future<void> _openSummary({
    required String title,
    required String fileName,
    required Future<List<Widget>> Function() buildCards,
  }) async {
    final busy = ValueNotifier<bool>(false);
    // نافذة انتظار أثناء تحضير الملخص
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
                child: Text(isBusy ? 'جارٍ التحضير...' : 'تجهيز الملخص...',
                    style: AppText.normal(14)),
              ),
            ]),
          ),
        ),
      ),
    );
    try {
      final cards = await buildCards();
      if (!mounted) {
        busy.dispose();
        return;
      }
      busy.value = true;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SummaryPreviewPage(
              title: title, fileName: fileName, cards: cards),
        ),
      );
    } catch (e) {
      if (mounted) showError(context, 'تعذّر تحضير الملخص.');
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
          _action(Icons.badge_outlined, 'بطاقة الأستاذ — عرض كصورة',
              AppColors.primary, _openTeacherCard),
          const SizedBox(height: 10),
          _action(Icons.assessment_outlined, 'تقرير الحضور — يومي/أسبوعي/شهري',
              AppColors.primary, _openWeeklyReport),
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