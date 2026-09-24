import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// يحوّل أي خطأ يصل من النظام إلى رسالة عربية واضحة للمستخدم.
/// التفاصيل التقنية تُسجَّل في سجل التطبيق فقط (وليس أمام المستخدم).
String arabicErrorMessage(Object e) {
  debugPrint('iqra-error: $e');
  final s = e.toString().toLowerCase();
  if (e is PostgrestException ||
      s.contains('network') ||
      s.contains('socket') ||
      s.contains('timeout')) {
    return 'تعذّر الاتصال بالخادم. تحقق من اتصالك بالإنترنت ثم حاول مجدداً.';
  }
  if (s.contains('is not a subtype of type')) {
    return 'تعذّرت قراءة البيانات بشكل صحيح. حدّث الصفحة أو أعد تشغيل التطبيق.';
  }
  if (s.contains('permission denied') || s.contains('access denied')) {
    return 'ليست لديك صلاحية لإجراء هذا الإجراء.';
  }
  return 'حدث خطأ غير متوقع. أعد المحاولة.';
}