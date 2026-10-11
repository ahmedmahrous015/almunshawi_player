# Flutter ProGuard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# audio_service rules
-keep class com.ryanheise.audioservice.** { *; }
-keep class androidx.media.** { *; }

# audioplayers rules
-keep class xyz.luan.audioplayers.** { *; }

# Keep Flutter method channel and reflection calls
-keepattributes *Annotation*
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes Signature

# Google Play Core dontwarn
-dontwarn com.google.android.play.core.**
