plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// android {
//     namespace = "com.example.kontaka"
//     compileSdk = 36
//     ndkVersion = "27.0.12077973"

//     compileOptions {
//         sourceCompatibility = JavaVersion.VERSION_1_8
//         targetCompatibility = JavaVersion.VERSION_1_8
//     }

//     kotlinOptions {
//         jvmTarget = '1.8'
//     }

//     sourceSets {
//         main.java.srcDirs += 'src/main/kotlin'
//     }

//     defaultConfig {
//         applicationId = "com.example.kontaka"
//         minSdk = 24
//         targetSdk = flutter.targetSdkVersion
//         versionCode = flutterVersionCode.toInteger()
//         versionName = flutterVersionName
//     }

//     buildTypes {
//         release {
//             signingConfig = signingConfigs.debug
//         }
//     }
// }

android {
    namespace = "com.example.kontaka"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"  // Changed from '1.8' to "1.8"
    }

    defaultConfig {
        applicationId = "com.example.kontaka"
        minSdk = 24
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")  // Fixed this line
        }
    }
}

flutter {
    source = "../.."
}
