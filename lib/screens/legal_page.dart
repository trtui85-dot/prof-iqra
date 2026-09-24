import 'package:flutter/material.dart';

import '../core/theme.dart';

class LegalSection {
  final String title;
  final String body;
  const LegalSection(this.title, this.body);
}

const List<LegalSection> kPrivacyPolicySections = [
  LegalSection('مقدمة', 'نحترم خصوصيتك ونلتزم بحماية بياناتك الشخصية. توضح هذه السياسة كيفية جمع بياناتك واستخدامها وحمايتها عند استخدامك تطبيق «أساتذة اقرأ».'),
  LegalSection('البيانات التي نجمعها', 'نسجّل رقم هاتفك، اسمك، وتوقيتات حضورك وانصرافك وجدول حصصك. تُستخدم هذه البيانات حصراً لأغراض إدارة الحضور داخل المؤسسة.'),
  LegalSection('كيفية استخدام البيانات', 'تُستخدم بياناتك لتنظيم جدول الحصص، ومتابعة الحضور، وإرسال إشعارات متعلقة بحصصك، وإصدار تقارير للإدارة. لا نبيع بياناتك أو نشاركها مع أي طرف خارجي.'),
  LegalSection('أمان البيانات', 'نطبق إجراءات تقنية وإدارية لحماية بياناتك من الوصول غير المصرّح به أو الفقدان أو التعديل. الوصول إلى سجلات الحضور مقتصر على الإدارة المصرّحة لك.'),
  LegalSection('الاحتفاظ بالبيانات', 'تحتفظ المؤسسة بسجلات الحضور للمدة التي تحددها، حسب الأغراض الإدارية والقانونية. يمكنك طلب تصحيح بياناتك أو حذف حسابك عبر الإدارة.'),
  LegalSection('حساباتك وسرية كلمة السر', 'كود PIN خاص بك ويُخزَّن بشكل مشفّر. لا تشاركه مع أحد، وأبلغ الإدارة فوراً إذا اعتقدت أن حسابك تعرّض للاختراق.'),
  LegalSection('التحديثات', 'قد نحدّث هذه السياسة من حين لآخر. سيظهر أي تحديث داخل التطبيق، وتفضّل سياسة المستخدم نفسها دائماً.'),
  LegalSection('تواصل معنا', 'لأي استفسار عن هذه السياسة أو بياناتك، تواصل مع إدارة المؤسسة من خلال قنواتها الرسمية.'),
];

const List<LegalSection> kTermsOfUseSections = [
  LegalSection('مقدمة', 'باستخدامك تطبيق «أساتذة اقرأ» فإنك توافق على هذه الشروط. يرجى قراءتها بعناية قبل استخدام التطبيق.'),
  LegalSection('وصف الخدمة', 'يوفر التطبيق خدمة متابعة حضور الأساتذة عبر مسح رمز QR، وعرض الجدول، وتلقي الإشعارات، وإصدار تقارير للمؤسسة.'),
  LegalSection('حساب المستخدم', 'حسابك شخصي ولا يجوز مشاركته مع الآخرين. أنت مسؤول عن الحفاظ على سرية كود PIN وعن كل العمليات التي تتم عبر حسابك.'),
  LegalSection('سلوك المستخدم', 'يُمنع استخدام التطبيق لأي غرض غير مشروع، أو محاولة الوصول إلى بيانات أخرى، أو العبث بسجلات الحضور.'),
  LegalSection('المسح والحضور', 'خلاف قواعد الحضور المعلنة (كتوقيت الغياب التلقائي) يخضع لتقدير إدارة المؤسسة، ولها الحق في تصحيح أي سجل غير دقيق.'),
  LegalSection('الملكية الفكرية', 'جميع حقوق التطبيق ومحتواه تعود لمؤسسته، ولا يجوز نسخها أو إعادة استخدامها دون إذن خطي.'),
  LegalSection('إخلاء المسؤولية', 'نسعى لتقديم خدمة دقيقة وموثوقة، لكن لا نضمن خلوّها من الأخطاء، ولا يتحمل التطبيق مسؤولية توقف الخدمة أو انقطاع الشبكة.'),
  LegalSection('الإنهاء', 'للمؤسسة الحق في تعليق أو إنهاء حساب أي مستخدم يخالف هذه الشروط أو قواعد العمل الداخلية.'),
  LegalSection('القانون المعمول به', 'تخضع هذه الشروط للقوانين النافذة، وأي نزاع يُحل عبر القنوات الرسمية المختصة.'),
];

class LegalPage extends StatelessWidget {
  final String title;
  final List<LegalSection> sections;
  const LegalPage({super.key, required this.title, required this.sections});

  static void show(BuildContext context,
      {required String title, required List<LegalSection> sections}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LegalPage(title: title, sections: sections),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          itemCount: sections.length,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (context, i) {
            final s = sections[i];
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title, style: AppText.bold(15)),
                  const SizedBox(height: 6),
                  Text(s.body,
                      style: AppText.normal(13).copyWith(height: 1.7)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}