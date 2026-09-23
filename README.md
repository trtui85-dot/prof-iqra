# أساتذة اقرأ (prof-iqra)

تطبيق Flutter لمتابعة حضور الأساتذة وجدولهم الزمني عبر مسح رمز QR، مربوط بقاعدة بيانات **Supabase**.

## البنية

- **تطبيق واحد بواجهتين**: لوحة الإدارة + تطبيق الأستاذ (يُحدَّد الدور تلقائياً عند الدخول).
- تسجيل الدخول: رقم الهاتف + كود PIN (تنشئ الإدارة حسابات الأساتذة).
- مسح QR ثابت لدى الإدارة لتسجيل الحضور والانصراف تلقائياً حسب الجدول.
- بثّ حيّ (Supabase Realtime) لحضور اليوم والإشعارات.

## الإعداد

1. في مشروعك على Supabase نفّذ محتوى `supabase/schema.sql` من **SQL Editor**.
2. انسخ `.env.example` إلى `.env` واملأ المفتاح:
   - `SUPABASE_URL` = `https://<مرجع-المشروع>.supabase.co`
   - `SUPABASE_ANON_KEY` = مفتاح anon/public من **Settings → API Keys**
3. شغّل التطبيق:
   ```bash
   flutter pub get
   flutter run
   ```
4. حساب الأدمن الافتراضي: الهاتف `0660000000` وكود PIN `1234` (غيّره من لوحة الإدارة).

## بنية قاعدة البيانات

| الجدول | الوصف |
| --- | --- |
| `users` | الأدمن والأساتذة (name, phone, pin_hash, subject, section) |
| `schedule` | الجدول الأسبوعي لكل أستاذ (يوم، بداية، نهاية، اسم الحصة) |
| `attendance_logs` | سجل الحضور (دخول/خروج، الحالة: present/late/absent) |
| `notifications` | الإشعارات داخل التطبيق |
| `app_settings` | السر الحالي لرمز QR (يتجدد من لوحة الإدارة) |

> ملاحظة أمان: المصادقة تتم على مستوى التطبيق (هاتف + PIN)، لذلك تستخدم الجداول سياسات RLS مفتوحة حالياً — يُنصح بتضييقها في الإنتاج.

## البناء

```bash
flutter build apk --release
```

## المخطط الفني

```
lib/
  core/        الثيم، إعداد Supabase، أدوات مشتركة
  models/      AppUser, ScheduleEntry, AttendanceLog, AppNotification
  services/    auth, users, schedule, attendance, reports, notifications
  screens/
    teacher/   الجدول، المسح، سجلّي، الإشعارات
    admin/     الأساتذة، الجدول، QR، الحضور الحي، التقارير
```