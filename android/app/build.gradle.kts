import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties").takeIf { it.exists() }
    ?: file("key.properties").takeIf { it.exists() }
if (keystorePropertiesFile != null) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.elishagerson.pesaflow.pesaflow"
    compileSdk = 37
    buildToolsVersion = "37.0.0"
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.elishagerson.pesaflow.pesaflow"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val keyAliasVal = keystoreProperties.getProperty("keyAlias") ?: System.getenv("KEY_ALIAS")
            val keyPasswordVal = keystoreProperties.getProperty("keyPassword") ?: System.getenv("KEY_PASSWORD")
            val storeFileVal = keystoreProperties.getProperty("storeFile") ?: System.getenv("KEYSTORE_FILE")
            val storePasswordVal = keystoreProperties.getProperty("storePassword") ?: System.getenv("KEYSTORE_PASSWORD")

            if (storeFileVal != null) {
                val candidateFiles = listOf(
                    file(storeFileVal),
                    rootProject.file(storeFileVal),
                    file("../$storeFileVal")
                )
                val resolvedStoreFile = candidateFiles.firstOrNull { it.exists() }
                if (resolvedStoreFile != null) {
                    keyAlias = keyAliasVal
                    keyPassword = keyPasswordVal
                    storeFile = resolvedStoreFile
                    storePassword = storePasswordVal
                }
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            val releaseSigning = signingConfigs.getByName("release")
            signingConfig = if (releaseSigning.storeFile != null) {
                releaseSigning
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

