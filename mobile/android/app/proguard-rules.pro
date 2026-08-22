# Flutter ProGuard / R8 Rules

# Flutter Engine & Plugins
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }

# Google Play Core (referenced conditionally by Flutter Engine for deferred components)
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-dontwarn com.google.android.play.core.**

# Common annotations & desugaring
-dontwarn javax.annotation.**
-dontwarn org.checkerframework.**
-dontwarn com.google.errorprone.annotations.**
-dontwarn sun.misc.Unsafe

# Local plugins & common native dependencies
-dontwarn org.jaudiotagger.**
-keep class org.jaudiotagger.** { *; }
-dontwarn com.razorpay.**
-keep class com.razorpay.** { *; }
-dontwarn org.webrtc.**
-keep class org.webrtc.** { *; }
-dontwarn com.pichillilorenzo.flutter_inappwebview_android.**
-keep class com.pichillilorenzo.flutter_inappwebview_android.** { *; }
-dontwarn net.sqlcipher.**
-keep class net.sqlcipher.** { *; }
