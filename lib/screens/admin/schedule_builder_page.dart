import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/app_user.dart';
import '../../models/schedule_entry.dart';
import '../../services/schedule_service.dart';

class ScheduleBuilderPage extends StatefulWidget {
  final AppUser teacher;
  const ScheduleBuilderPage({super.key, required this.teacher});

  @override
  State<ScheduleBuilderPage> createState() => _ScheduleBuilderPageState();
}

class _ScheduleBuilderPageState extends State<ScheduleBuilderPage> {
  final _service = ScheduleService();
  bool _loading = true;
  List<ScheduleEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _service.listForTeacher(widget.teacher.id);
    if (mounted) {
      setState(() {
        _entries = list;
        _loading = false;
      });
    }
  }

  Future<void> _openDialog([ScheduleEntry? entry]) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ScheduleFormDialog(
        teacherId: widget.teacher.id,
        entry: entry,
        onChanged: _load,
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _delete(ScheduleEntry entry) async {
    final ok = await confirmDialog(
      context,
      title: 'حذف الحصة',
      message: 'حذف حصة «${entry.className}» من الجدول؟',
      confirmLabel: 'حذف',
      danger: true,
    );
    if (!ok) return;
    await _service.delete(entry.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('جدول ${widget.teacher.name}')),
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _openDialog(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة حصة'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _entries.isEmpty
              ? const EmptyState(
                  'لا توجد حصص بعد.\nاضغط "إضافة حصة" لبناء الجدول الأسبوعي.',
                  icon: Icons.calendar_month_outlined,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  itemCount: _entries.length,
                  itemBuilder: (context, i) {
                    final e = _entries[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        onTap: () => _openDialog(e),
                        padding: const EdgeInsets.all(13),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(children: [
                                Text(e.dayName,
                                    style: AppText.bold(11.5)
                                        .copyWith(color: AppColors.primary)),
                                const SizedBox(height: 2),
                                Text(e.startTime,
                                    style: AppText.bold(13)
                                        .copyWith(color: AppColors.primary)),
                              ]),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.className, style: AppText.bold(14.5)),
                                  const SizedBox(height: 2),
                                  Text('إلى ${e.endTime}',
                                      style: AppText.muted(12)),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => _delete(e),
                              icon: const Icon(Icons.delete_outline,
                                  color: AppColors.absent),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _ScheduleFormDialog extends StatefulWidget {
  final String teacherId;
  final ScheduleEntry? entry;
  final VoidCallback onChanged;
  const _ScheduleFormDialog({
    required this.teacherId,
    this.entry,
    required this.onChanged,
  });

  @override
  State<_ScheduleFormDialog> createState() => _ScheduleFormDialogState();
}

class _ScheduleFormDialogState extends State<_ScheduleFormDialog> {
  late final _service = ScheduleService();
  late int _day;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late final TextEditingController _class;
  bool _saving = false;

  bool get _isNew => widget.entry == null;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _day = e?.dayOfWeek ?? DateTime.now().weekday;
    _start = e != null ? _parse(e.startTime) : const TimeOfDay(hour: 8, minute: 0);
    _end = e != null ? _parse(e.endTime) : const TimeOfDay(hour: 9, minute: 0);
    _class = TextEditingController(text: e?.className ?? '');
  }

  @override
  void dispose() {
    _class.dispose();
    super.dispose();
  }

  static TimeOfDay _parse(String s) {
    final p = s.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  Future<void> _pick(BuildContext ctx, bool isStart) async {
    final picked = await showTimePicker(
      context: ctx,
      initialTime: isStart ? _start : _end,
      helpText: isStart ? 'وقت البداية' : 'وقت النهاية',
    );
    if (picked != null) {
      setState(() => isStart ? _start = picked : _end = picked);
    }
  }

  Future<void> _save() async {
    if (_class.text.trim().isEmpty) {
      showError(context, 'أدخل اسم الحصة/القسم.');
      return;
    }
    final startMin = _start.hour * 60 + _start.minute;
    final endMin = _end.hour * 60 + _end.minute;
    if (startMin >= endMin) {
      showError(context, 'وقت النهاية يجب أن يكون بعد وقت البداية.');
      return;
    }
    setState(() => _saving = true);
    String fmt(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    try {
      if (_isNew) {
        await _service.add(
          teacherId: widget.teacherId,
          dayOfWeek: _day,
          startTime: fmt(_start),
          endTime: fmt(_end),
          className: _class.text,
        );
      } else {
        await _service.update(
          widget.entry!.id,
          dayOfWeek: _day,
          startTime: fmt(_start),
          endTime: fmt(_end),
          className: _class.text,
        );
      }
      widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        showError(context, arabicErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isNew ? 'إضافة حصة' : 'تعديل الحصة'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _day,
              decoration: const InputDecoration(labelText: 'اليوم'),
              items: ScheduleEntry.dayNames.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _day = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _class,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'اسم الحصة / القسم',
                prefixIcon: Icon(Icons.class_outlined, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _timeField('البداية', _start, () => _pick(context, true)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _timeField('النهاية', _end, () => _pick(context, false)),
              ),
            ]),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isNew ? 'إضافة' : 'حفظ'),
        ),
      ],
    );
  }

  Widget _timeField(String label, TimeOfDay value, VoidCallback onTap) {
    final s = '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(s, style: AppText.bold(15)),
            const Icon(Icons.access_time, color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}