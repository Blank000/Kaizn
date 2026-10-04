# flutter_local_notifications stores scheduled reminders as JSON via Gson
# and reads them back with a generic TypeToken. R8's shrinking strips the
# generic signature, so reloading them threw "Missing type parameter" and
# crashed release builds (e.g. its boot receiver right after an update).
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class com.dexterous.** { *; }
