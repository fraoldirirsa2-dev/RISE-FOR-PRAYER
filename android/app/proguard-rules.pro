# Keep flutter_local_notifications — it uses reflection internally.
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Keep resource lookups done by name (getIdentifier).
-keepclassmembers class **.R$* {
    public static <fields>;
}