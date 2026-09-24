# جاهزية النشر على Google Play + App Store

## 1) الروابط القانونية المطلوبة (تسجيلها في كلا المتجرين)
- **سياسة الخصوصية**: ارفع/انشر `store/privacy_policy.md` على صفحة (GitHub Pages / Notion / موقع مؤسسة) ثم الصق الرابط.
- **شروط الاستخدام**: انشر `store/terms_of_service.md` بنفس الطريقة.
- لا يفتح التطبيقان أو يظهران قبل إدخال هذين الرابطين.

## 2) مشروع Firebase (لتشغيل الإشعارات الكاملة)
1. قم بإنشاء مشروع في console.firebase.google.com.
2. أضف تطبيق Android بمعرّف الحزمة `com.iqra.prof_iqra` وحمّل `google-services.json` إلى
   `android/app/google-services.json` (البناء سيطبّق المكوّن تلقائياً إذا وُجد).
3. أضف تطبيق iOS بمعرّف الباندل `com.iqra.profIqra` (أو المعرّف الفعلي) وضع
   `GoogleService-Info.plist` في `ios/Runner/` وأدرجه في Xcode → Runner.
4. من Firebase → Cloud Messaging → iOS Apps: ارفع ملف **APNs** (من Apple) أو استخدم مفتاح **APNs Auth Key**.
5. بعد النشر على Supabase (أدناه) ضع الأسرار التالية في Supabase → Edge Functions → Settings:
   - `GOOGLE_APPLICATION_CREDENTIALS` = محتوى JSON لحساب خدمة Firebase (Firebase → Project Settings → Service accounts → Generate new private key).
   - `FIREBASE_PROJECT_ID` = معرف مشروع Firebase.

## 3) نشر دالة الإشعارات وترحيلات Supabase (OF Edge)
```
supabase functions deploy fcm-notify --no-verify-jwt
```
ثم في SQL Editor شغّل بالترتيب:
1. `supabase/migration_003_fcm.sql`
2. `supabase/server_sql/admin_fcm_setup.sql` (بدّل سطر `https://vyokks...` إلى مرجع مشروعك الحقيقي إن اختلف)
3. شغّل أيضاً أي ترحيلات سابقة لم تُشغَّل بعد (`migration_001`, `migration_002`).

## 4) التوقيع (Android – Google Play)
انظر `store/release_signing.md` خطوة بخطوة مع keystore.

## 5) التوقيع (iOS – App Store)
- الاشتراك في Apple Developer Program (99$/سنة).
- عبر Xcode: Signing & Capabilities → Team → إنشاء Certificate + Provisioning.
- أدرج دعائم **Push Notifications** و**Camera** في Runner.
- رفع: Xcode → Product → Archive ثم صمّم الشاشات في App Store Connect.

## 6) نصوص المتجر الجاهزة
`store/play_listing.md` (عنوان + وصف + لقطات + ملاحظات مراجعة App Store).

## 7) قائمة فحص ما قبل الإطلاق
- [ ] شغّلت migration_003 + admin_fcm_setup
- [ ] google-services.json موجود و build النهائي وُقّع بـ keystore حقيقي
- [ ] تفعيل FCM في Firebase و APNs للـ iOS
- [ ] روابط السياسة والشروط حيّة (HTTPS) وأُدخلت في لوحتي المتجر
- [ ] تسليم صلاحيات الكاميرا + Push في وصف المتجر (بخصوصية)
- [ ] رفع الـ AAB الموقّع واختباره في Play Console (Internal Testing) قبل الإطلاق