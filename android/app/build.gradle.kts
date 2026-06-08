// android/app/build.gradle.kts (Kotlin DSL)
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services") version "4.3.15"
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "pm.rr.soupmrr"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true  // Habilita desugaring
    }
    kotlinOptions {
        jvmTarget = "17"
    }

    signingConfigs {
        create("release") {
            val keystoreProperties = gradle.rootProject.file("key.properties")
            if (keystoreProperties.exists()) {
                val keystore = Properties()
                keystore.load(keystoreProperties.inputStream())

                storeFile = if (keystore["storeFile"] != null) 
                    file(keystore["storeFile"] as String) 
                else null
                storePassword = keystore["storePassword"] as String?
                keyAlias = keystore["keyAlias"] as String?
                keyPassword = keystore["keyPassword"] as String?
            }
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
        }
    }

    defaultConfig {
        applicationId = "pm.rr.soupmrr"
        minSdk = 21
        targetSdk = 35
        versionCode = 39
        versionName = "1.0.39"
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.google.android.material:material:1.9.0")
    implementation("com.google.firebase:firebase-analytics:21.1.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:1.2.2")
}

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(17)
    }
}
