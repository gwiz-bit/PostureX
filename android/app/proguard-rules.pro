# ML Kit nạp các lớp "ComponentRegistrar" (PoseRegistrar, CommonComponentRegistrar,
# VisionCommonRegistrar...) bằng reflection lúc app khởi động. R8 (mặc định bật kèm
# rút gọn mã cho bản release qua Flutter Gradle Plugin) đổi tên/xoá mất constructor
# không tham số của các lớp này nếu thiếu keep rule tường minh, gây crash ngay khi mở
# app: "NoSuchMethodException: PoseRegistrar.<init> []" — xem CHANGELOG 24/09/2026.
-keep class com.google.mlkit.common.internal.CommonComponentRegistrar { <init>(); }
-keep class com.google.mlkit.vision.common.internal.VisionCommonRegistrar { <init>(); }
-keep class com.google.mlkit.vision.pose.internal.PoseRegistrar { <init>(); }
-keep class * extends com.google.mlkit.common.internal.MlKitComponentRegistrar { <init>(); }
-dontwarn com.google.mlkit.**

# Cùng nguyên nhân R8 stripping reflection ở trên kéo theo WorkManager (cũng dùng
# androidx.startup.Initializer để tự khởi tạo) sập theo ngay sau ML Kit trong cùng
# một lượt InitializationProvider.onCreate() — "Failed to create an instance of
# androidx.work.impl.WorkDatabase" trên cùng log crash.
-keep class * implements androidx.startup.Initializer { <init>(); }
-keep class androidx.work.** { *; }
-keep class androidx.room.** { *; }
