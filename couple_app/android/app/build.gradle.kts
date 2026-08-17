plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.private_couple_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.example.private_couple_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            // proguard-rules.pro artıq flutter_local_notifications-ın Gson
            // reflection ehtiyacını qoruyur (TypeToken keep qaydaları) —
            // ona görə kod kiçiltməni TƏHLÜKƏSİZ şəkildə aktivləşdirə bilərik.
            // Bu, APK ölçüsünü xeyli azaldacaq (istifadə olunmayan kod silinir).
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // NotificationVaultListener-in Flutter mühiti olmadan birbaşa
    // Firestore-a yaza bilməsi üçün (arxa planda / tətbiq bağlıykən sync)
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    implementation("com.google.firebase:firebase-auth-ktx")
    implementation("com.google.android.gms:play-services-location:21.3.0")
    implementation("com.google.firebase:firebase-firestore-ktx")
    // UrgentCallMessagingService-in FCM mesajlarını native tutması üçün
    implementation("com.google.firebase:firebase-messaging-ktx")
}

flutter {
    source = "../.."
}
