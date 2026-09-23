import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/app_user.dart';
import '../../services/user_service.dart';
import 'teacher_detail_page.dart';
import 'teacher_form_page.dart';

class TeachersPage extends StatefulWidget {
  final AppUser admin;
  const TeachersPage({super.key, required this.admin});

  @override
  State<TeachersPage> createState() => _TeachersPageState();
}

class _TeachersPageState extends State<TeachersPage> {
  final _service = UserService();
  bool _loading = true;
  List<AppUser> _all = [];
  final _query = TextEditingController();
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _service.listTeachers();
      if (mounted) {
        setState(() {
          _all = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<AppUser> get _visible => _all
      .where((t) =>
          _filter.isEmpty ||
          t.name.contains(_filter) ||
          t.phone.contains(_filter))
      .toList();

  Future<void> _openDetail(AppUser teacher) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TeacherDetailPage(teacher: teacher),
    ));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: _create,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('إضافة أستاذ'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _query,
              onChanged: (v) => setState(() => _filter = v.trim()),
              decoration: const InputDecoration(
                hintText: 'بحث بالاسم أو الهاتف…',
                prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _visible.isEmpty
                    ? EmptyState(_filter.isEmpty
                        ? 'لا يوجد أساتذة بعد.\nاضغط "إضافة أستاذ" لإنشاء حساب.'
                        : 'لا توجد نتائج مطابقة.')
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                          itemCount: _visible.length,
                          itemBuilder: (context, i) {
                            final t = _visible[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: AppCard(
                                onTap: () => _openDetail(t),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: t.isActive
                                            ? AppColors.primarySoft
                                            : AppColors.border,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        t.name.isNotEmpty ? t.name[0] : '?',
                                        style: AppText.bold(16).copyWith(
                                          color: t.isActive
                                              ? AppColors.primary
                                              : AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            t.name,
                                            style: AppText.bold(14.5).copyWith(
                                              color: t.isActive
                                                  ? AppColors.textDark
                                                  : AppColors.textMuted,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            [
                                              if (t.subject != null)
                                                t.subject!,
                                              if (t.section != null)
                                                t.section!,
                                              t.phone,
                                            ].join(' • '),
                                            style: AppText.muted(12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!t.isActive)
                                      StatusChip('absent')
                                    else
                                      const Icon(Icons.chevron_left,
                                          color: AppColors.textMuted),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TeacherFormPage(),
    ));
    _load();
  }
}