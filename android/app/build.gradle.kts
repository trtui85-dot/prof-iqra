import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// يطبَّق مكوّن google-services تلقائياً فقط عند وجود google-services.json
// من مشروع Firebase (وإلا يقف البناء ويعمل التطبيق دون إشعارات).
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// تفعيل توقيع النسخة النهائية عبر key.properties عند ضبط releaseSigningEnabled=true
val keyProps: Properties? = run {
    val f = file("key.properties")
    if (!f.exists()) null
    else Properties().apply { f.inputStream().use { load(it) } }
}
val releaseSigningEnabled =
    keyProps != null && keyProps.getProperty("releaseSigningEnabled", "false").toBoolean()

android {
    namespace = "com.iqra.prof_iqra"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.iqra.prof_iqra"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // إعداد التوقيع للنسخة النهائية (Play Store):
        // ضع ملف key.jks داخل android/app وأنشئ ملف key.properties بجانبه ثم
        // فعّل خاصية releaseSigningEnabled في key.properties . التفاصيل في store/release_signing.md
        if (releaseSigningEnabled) {
            create("release") {
                val p = keyProps!!
                storeFile = file(p.getProperty("storeFile", "key.jks"))
                storePassword = p.getProperty("storePassword")
                keyAlias = p.getProperty("keyAlias")
                keyPassword = p.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (releaseSigningEnabled) signingConfigs.getByName("release")
                else signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
