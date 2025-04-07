# Flutter Proguard Rules

# Keep Flutter wrapper classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Firebase classes
-keep class com.google.firebase.** { *; }
-keep class com.firebase.** { *; }

# Keep Agora SDK classes (for video/voice calls)
-keep class io.agora.** { *; }

# Keep Cloudinary classes
-keep class com.cloudinary.** { *; }

# Keep model classes
-keep class com.weekendmingle.app.models.** { *; }

# General Android rules
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# For native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep the R class and its fields
-keep class **.R$* {*;}