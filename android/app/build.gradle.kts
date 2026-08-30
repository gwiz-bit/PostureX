import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.posturex.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // Kotlin mặc định lấy JVM target theo JDK đang chạy (21), lệch với Java ở
    // trên (17) và Gradle sẽ bỏ build. Ghim Kotlin về 17 cho khớp.
    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    defaultConfig {
        // Định danh app trên Play Store. Không được để `com.example.*` —
        // Google chặn thẳng khi nộp bài. Khớp với PRODUCT_BUNDLE_IDENTIFIER
        // của iOS để hai nền tảng cùng một định danh.
        //
        // ĐỔI GIÁ TRỊ NÀY LÀ PHẢI CẬP NHẬT GOOGLE CLOUD CONSOLE: OAuth client
        // của Android gắn với cặp (package name, SHA-1). Chưa đăng ký client
        // mới cho `com.posturex.app` thì nút "Continue with Google" sẽ báo lỗi
        // dù mọi thứ khác vẫn chạy.
        applicationId = "com.posturex.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}
