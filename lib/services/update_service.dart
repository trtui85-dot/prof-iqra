import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

/// فحص تحديث تلقائي من المتجر:
/// - الإدارة: تحديث فوري إجباري (يعيق الاستخدام حتى الاكتمال)
/// - الأستاذ: تحديث مرن في الخلفية (يبقى يستخدم التطبيق حتى إعادة التشغيل)
class UpdateService {
  static Future<void> checkAndUpdate(
    BuildContext context, {
    required bool force,
  }) async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) return;
      if (force) {
        if (info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        } else {
          await InAppUpdate.startFlexibleUpdate();
        }
      } else {
        if (info.flexibleUpdateAllowed) {
          final result = await InAppUpdate.startFlexibleUpdate();
          if (result == AppUpdateResult.success) {
            // اكتمل التنزيل؛ سيسري بعد إعادة تشغيل التطبيق
          }
        }
      }
    } catch (_) {
      // عند عدم توفر الإصدار في المتجر حتى الآن، نتجاهل بهدوء
    }
  }
}