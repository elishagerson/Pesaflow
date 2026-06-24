# Flutter Engine
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.app.** { *; }

# Play Core — referenced by Flutter's deferred components code path (not used in this app)
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Dart VM
-keep class dart.** { *; }

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Another Telephony
-keep class com.jaredrummler.android.shell.** { *; }
-keep class com.mr.flutter.plugin.** { *; }

# file_picker
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# share_plus
-keep class net.goderbauer.flutter.share.** { *; }

# Drift / SQLite
-keep class org.sqlite.** { *; }
-keep class com.almworks.sqlite4java.** { *; }

# Keep all native method classes (JNI)
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep generic signatures and attributes for reflection
-keepattributes Signature, InnerClasses, EnclosingMethod, RuntimeVisibleAnnotations, RuntimeInvisibleAnnotations
-keepattributes *Annotation*
