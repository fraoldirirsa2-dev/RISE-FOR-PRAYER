# ============================================================
# Rise for Prayer - ProGuard / R8 rules
# ============================================================

# Keep flutter_local_notifications.
# It uses Android classes and reflection internally.
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Keep Android generated R fields used by resource lookups.
-keepclassmembers class **.R$* {
    public static <fields>;
}

# Keep annotations and enum metadata used by Android/plugin code.
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod