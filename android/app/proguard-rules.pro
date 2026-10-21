# Keep the Play Billing classes, the release build talks to them over a binder.
-keep class com.android.vending.billing.** { *; }
-dontwarn com.android.vending.billing.**

# Flutter engine and the plugin registration.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# The app is written in Dart, so only the platform channels need to survive.
-keep class com.sherawali.tet.** { *; }

# Keep the annotation and the generic signatures of the Play library.
-keepattributes *Annotation*
-keepattributes Signature
