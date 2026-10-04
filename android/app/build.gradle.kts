import java.io.FileInputStream
import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Key ký bản release thật (không phải debug key) — cần để nộp lên Google Play,
// vốn từ chối thẳng file ký bằng debug key. Không commit key.properties/*.jks
// (đã có trong android/.gitignore) — máy nào build release cũng phải tự có
// file này, không đi kèm repo.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
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

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Dùng key release thật khi có key.properties (máy dev/CI đã tạo keystore);
            // rơi về debug key nếu chưa có, để `flutter run --release` vẫn chạy được
            // trên máy chưa từng tạo keystore (vd máy mới của thành viên khác).
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // Flutter Gradle Plugin tự bật rút gọn mã (R8) cho bản release, nhưng
            // không biết gì về các lớp bên thứ ba (vd ML Kit) nạp bằng reflection —
            // cần proguard-rules.pro để R8 không xoá/đổi tên nhầm (xem CHANGELOG
            // 24/09/2026: NoSuchMethodException khi mở app do thiếu file này).
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
