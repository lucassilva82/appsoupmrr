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
    compileSdk = 36
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
        // Fixo de propósito, e não `flutter.minSdkVersion`.
        //
        // Aquele valor muda sozinho quando o Flutter é atualizado, sem
        // aparecer em diff nenhum. Foi o que aconteceu em 08/10: a
        // atualização para o Flutter 3.47.6 levou o minSdk de 21 para 24 em
        // silêncio, e só descobrimos no envio à Play, que avisou da perda de
        // 1.732 aparelhos — Android 5.0, 5.1 e 6.0.
        //
        // 24 é o piso real hoje: `local_auth_android` exige 24 para a
        // biometria, e o próprio Flutter adota 24. Baixar daqui significa
        // tirar o login por biometria.
        //
        // Mudar este número derruba ou devolve aparelhos. Que seja uma
        // decisão, com o número à vista — não um efeito colateral.
        minSdk = 24
        targetSdk = 36
        versionCode = 59
        versionName = "2.2.1"
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
