# توقيع نسخة النشر (Android — Google Play)

## الحالة الحالية: ✅ تم التوقيع
- مفتاح التوقيع التجاري **موجود**: `android/app/key.jks` (alias: `iqra`، RSA 4096، صلاحية 30 سنة).
- `android/app/key.properties` موجود ويقرأه Gradle، ويجعل بناء `release` موقّعاً بالمفتاح التجاري تلقائياً.
- كلمة المرور **غير موجودة في Git** (كلاهما في `.gitignore`)، وموثّقة في ملف نسخة احتياطية على جهازك.
- آخر بناء موقّع ومُتحقَّق منه بـ `apksigner`:
  `Signer #1 certificate DN: CN=Prof Iqra, OU=Mobile, O=Iqra Education Platform, L=Casablanca, ST=Casablanca, C=MA`
- الملفات الجاهزة للرفع على سطح المكتب:
  - `C:\Users\dell\Desktop\prof-iqra-release.aab` (69.8MB) — هذا ما يُرفع إلى Play Console.
  - `C:\Users\dell\Desktop\prof-iqra-release.apk` (80.8MB) — للتجربة المباشرة على الأجهزة.

## ⚠️ أولوية قصوى: نسخ احتياطي للمفتاح
انسخ `android/app/key.jks` وملف كلمة المرور (الموجودان في `key.properties`) إلى وسيطين آمنين منفصلين.
فقدانهما = استحالة نشر أي تحديث لاحق للتطبيق.

## الأوامر (لإعادة البناء أو عند التحديث لاحقاً)

### 1) البناء الموقّع
```
flutter build appbundle --release
flutter build apk --release
```
الناتج: `build/app/outputs/bundle/release/app-release.aab` و `build/app/outputs/flutter-apk/app-release.apk`

### 2) الرفع إلى Play Console
1. Google Play Console → Releases → Production → Upload.
2. ارفع ملف الـ AAB فقط (لا ترفع APK).
3. عند طلب مفتاح توقيع التطبيق (Play App Signing): اختر **Upload** وارفع نفس `key.jks` باسم
   `upload_key_prof_iqra` — سيطلب keystore password / key alias (`iqra`) / key password.
   بعد نجاح ذلك ينشئ Google **مفتاح توقيع التطبيق** الخاص به ولا تحتاج uploaded key مجدداً.
4. كل تحديث لاحق: غيّر `version: 1.0.0+2` في `pubspec.yaml` (أعلى رقم = versionCode) ثم أعد البناء.

## إنشاء مفتاح جديد (فقط لو ضاع القديم ولا بد من البدء من الصفر)
```
keytool -genkeypair -v -keystore key.jks -alias iqra -keyalg RSA -keysize 4096 -validity 10950
```

## ملاحظات أمان
- لا ترفع `key.jks` أو `key.properties` إلى أي مستودع (مستثناة في `.gitignore`).
- احفظ نسخة من keystore وكلمة المرور في مكان آمن منفصل؛ ضياعها يعني ضياع القدرة على تحديث التطبيق.