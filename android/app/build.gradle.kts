plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.ablecredit.manual_flutter_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.ablecredit.manual_flutter_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    dependencies {
        implementation(files("libs/ablecredit-1.0.6.aar"))

        implementation("androidx.room:room-runtime:2.6.1")
        implementation("androidx.room:room-ktx:2.6.1")
        implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.8.1")
        implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
        implementation("androidx.work:work-runtime-ktx:2.9.0")
        implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
        implementation("androidx.lifecycle:lifecycle-service:2.7.0")
        implementation("androidx.lifecycle:lifecycle-livedata-ktx:2.7.0")
        implementation("androidx.lifecycle:lifecycle-viewmodel-ktx:2.7.0")
        implementation("androidx.cardview:cardview:1.0.0")
        implementation("androidx.activity:activity-ktx:1.8.2")
        implementation("androidx.fragment:fragment-ktx:1.6.2")
        implementation("com.squareup.okhttp3:okhttp:4.12.0")
        implementation("com.squareup.okhttp3:logging-interceptor:4.12.0")
        implementation("com.squareup.retrofit2:retrofit:2.11.0")
        implementation("com.squareup.retrofit2:converter-moshi:2.11.0")
        implementation("com.squareup.retrofit2:converter-gson:2.11.0")
        implementation("com.google.android.gms:play-services-location:21.3.0")
        implementation("androidx.camera:camera-core:1.4.0")
        implementation("androidx.camera:camera-camera2:1.4.0")
        implementation("androidx.camera:camera-lifecycle:1.4.0")
        implementation("androidx.camera:camera-view:1.4.0")
        implementation("androidx.localbroadcastmanager:localbroadcastmanager:1.1.0")
        implementation("com.squareup.picasso:picasso:2.71828")
        implementation("com.github.bumptech.glide:glide:5.0.5")
        implementation("io.insert-koin:koin-core:3.5.6")
        implementation("io.insert-koin:koin-android:3.5.6")
        implementation("com.segment.analytics.kotlin:android:1.13.0")

            implementation("androidx.core:core-ktx:1.13.1")
            implementation("androidx.appcompat:appcompat:1.7.0")
            implementation("com.google.android.material:material:1.12.0")
    }
}

flutter {
    source = "../.."
}
