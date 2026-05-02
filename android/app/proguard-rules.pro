# Add project specific ProGuard rules here.

# Keep Flutter runtime and plugin entry points.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep app classes used from Flutter/plugin registrants.
-keep class it.denv.tripviewer.** { *; }

# Keep enum helpers used by JSON and platform libraries.
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Flutter references Play Core deferred component APIs even when unused.
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
