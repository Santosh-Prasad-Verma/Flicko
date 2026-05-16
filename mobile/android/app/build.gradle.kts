import java.util.Base64

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val flickoDartDefineKeys =
    listOf(
        "FLICKO_SUPABASE_URL",
        "FLICKO_SUPABASE_ANON_KEY",
        "FLICKO_LIVEKIT_URL",
        "FLICKO_STRIPE_PUBLISHABLE_KEY",
        "FLICKO_API_URL",
        "FLICKO_GIPHY_API_KEY",
        "FLICKO_APPWRITE_PROJECT_ID",
        "FLICKO_APPWRITE_PROJECT_NAME",
        "FLICKO_APPWRITE_PUBLIC_ENDPOINT",
        "FLICKO_APPWRITE_BUCKET_ID",
        "SUPABASE_URL",
        "SUPABASE_ANON_KEY",
        "LIVEKIT_URL",
        "STRIPE_PUBLISHABLE_KEY",
        "API_BASE_URL",
        "GIPHY_API_KEY",
        "APPWRITE_PROJECT_ID",
        "APPWRITE_PROJECT_NAME",
        "APPWRITE_PUBLIC_ENDPOINT",
        "APPWRITE_BUCKET_ID",
    )

fun encodeDartDefine(define: String): String =
    Base64.getEncoder().encodeToString(define.toByteArray(Charsets.UTF_8))

fun decodeDartDefine(encodedDefine: String): String? =
    runCatching {
        String(Base64.getDecoder().decode(encodedDefine), Charsets.UTF_8)
    }.getOrNull()

fun mergeFlickoEnvDartDefines(existingDartDefines: String?): String {
    val existingDefines = existingDartDefines.orEmpty().split(",").filter { it.isNotBlank() }
    val existingKeys =
        existingDefines
            .mapNotNull { decodeDartDefine(it)?.substringBefore("=") }
            .toSet()
    val envDefines =
        flickoDartDefineKeys.mapNotNull { key ->
            val value = System.getenv(key)?.trim()
            if (value.isNullOrEmpty() || key in existingKeys) {
                null
            } else {
                encodeDartDefine("$key=$value")
            }
        }

    return (existingDefines + envDefines).joinToString(",")
}

tasks.withType<com.flutter.gradle.tasks.FlutterTask>().configureEach {
    dartDefines = mergeFlickoEnvDartDefines(dartDefines)
}

android {
    namespace = "com.example.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.mobile"
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
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
