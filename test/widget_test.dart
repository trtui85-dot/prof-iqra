import 'package:flutter_test/flutter_test.dart';

import 'package:prof_iqra/app.dart';
import 'package:prof_iqra/core/theme.dart';

void main() {
  testWidgets('التطبيق يظهر شاشة البداية', (tester) async {
    await tester.pumpWidget(const IqraApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('أساتذة اقرأ'), findsOneWidget);
    // تمريير مؤقّت splash للوصول لشاشة التنبيه بالإعدادات
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
  });

  test('الثيم يعتمد الخط العربي وأناقة بيضاء', () {
    final theme = buildTheme();
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.colorScheme.primary, AppColors.primary);
  });
}