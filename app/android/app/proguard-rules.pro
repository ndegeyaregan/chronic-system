# Flutter / Dart
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-dontwarn io.flutter.embedding.**

# Health Connect & related
-keep class androidx.health.** { *; }
-dontwarn androidx.health.**

# Firebase Messaging
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Pedometer / sensors
-keep class com.dariusneagoe.pedometer.** { *; }
-dontwarn com.dariusneagoe.pedometer.**

# Pdf / printing
-keep class com.shockwave.** { *; }
-dontwarn com.shockwave.**

# Google Play Core (deferred components / split-install) — required by R8
# even though we don't use deferred components.
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Keep model classes annotated with @Keep
-keep @androidx.annotation.Keep class * { *; }
-keepclassmembers class * {
    @androidx.annotation.Keep <fields>;
    @androidx.annotation.Keep <methods>;
}

# JSON serialization with reflection
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
