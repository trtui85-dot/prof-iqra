# توقيع نسخة النشر (Android — Google Play)

> بالأمر أدناه إنشاء keystore + تفعيل التوقيع. انسخه شغّله في `android/app` أو فورًا بـ Purpose من OpenCode.

## 1) توليد keystore (مرة واحدة فقط — احتفظ به سراً واحتياطياً!)
```
keytool -genkey -v -keystore android/app/key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias iqra
```
سيطلب: كلمة مرور (اكتبها مرتين)، الاسم/الجهة، ثم `yes` أخيراً.

## 2) ملف key.properties (مستثنى من Git تلقائياً)
أنشئ `android/app/key.properties` بالمحتوى التالي:
```
storeFile=key.jks
storePassword=كلمة_المرور_التي_اخترتها
keyAlias=iqra
keyPassword=كلمة_المرور_التي_اخترتها
releaseSigningEnabled=true
```

## 3) البناء الموقّع
```
flutter build appbundle --release
```
الناتج: `build/app/outputs/bundle/release/app-release.aab`

## 4) الرفع إلى Play Console
1. اذهب إلى Google Play Console → Application releases → Production.
2. ارفع ملف الـ AAB. وفّق فيه **مفتاح توقيع التطبيق** (Play App Signing) — احتفظ بكلمة مرور keystore خاصتك.
3. غيّر `versionCode`/`versionName` في `android/app/build.gradle.kts` (أو في pubspec `version:`) مع كل تحديث.
4. ادفع رسم الاشتراك (25$ مرة واحدة) — الخطوة الوحيدة المتبقية خارج الكود.

## ملاحظات أمان
- لا ترفع `key.jks` أو `key.properties` إلى أي مستودع (مستثناة في `.gitignore`).
- احفظ نسخة من keystore وكلمة المرور في مكان آمن منفصل؛ ضياعها يعني ضياع القدرة على تحديث التطبيق.