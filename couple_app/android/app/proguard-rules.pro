# flutter_local_notifications (Gson əsaslı planlanmış bildiriş saxlaması)
# generic tip məlumatına (TypeToken) ehtiyac duyur — bunları qorumaq lazımdır,
# əks halda release build-də "TypeToken must be created with a type argument" xətası baş verir.
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.google.gson.**

# Firebase Firestore/Auth - reflection əsaslı serialization üçün ehtiyat qaydalar
-keepattributes *Annotation*
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName <fields>;
}
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
