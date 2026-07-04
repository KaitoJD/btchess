import org.gradle.api.GradleException
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

val requiredKeystoreProperties = listOf(
    "storePassword",
    "keyPassword",
    "keyAlias",
    "storeFile",
)
val hasCompleteKeystoreProperties = requiredKeystoreProperties.all {
    !keystoreProperties.getProperty(it).isNullOrBlank()
}
val releaseBuildRequested = gradle.startParameter.taskNames.any { taskName ->
    val normalizedTaskName = taskName.substringAfterLast(':').lowercase()
    (normalizedTaskName.startsWith("assemble") || normalizedTaskName.startsWith("bundle")) &&
        normalizedTaskName.endsWith("release")
}

if (releaseBuildRequested) {
    if (!keystorePropertiesFile.exists()) {
        throw GradleException(
            """
            Release signing is not configured.

            Create android/key.properties from android/key.properties.example and
            make sure android/keystores/btchess-release.jks exists. Release APKs
            must be signed before Android can install them.
            """.trimIndent(),
        )
    }

    if (!hasCompleteKeystoreProperties) {
        val missingProperties = requiredKeystoreProperties
            .filter { keystoreProperties.getProperty(it).isNullOrBlank() }
            .joinToString(", ")

        throw GradleException(
            """
            Release signing is incomplete.

            Missing key.properties value(s): $missingProperties.
            Use android/key.properties.example as the template.
            """.trimIndent(),
        )
    }

    val configuredKeystoreFile = file(keystoreProperties.getProperty("storeFile"))
    if (!configuredKeystoreFile.exists()) {
        throw GradleException(
            """
            Release signing keystore was not found.

            Expected: ${configuredKeystoreFile.absolutePath}
            Create or restore the sideload release keystore before building.
            """.trimIndent(),
        )
    }
}

android {
    namespace = "me.kaitojd.btchess"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "me.kaitojd.btchess"
        // Minimum SDK 21 required for BLE support
        minSdk = 21
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        setProperty("archivesBaseName", "btchess-$versionName-$versionCode")
    }

    signingConfigs {
        if (keystorePropertiesFile.exists() && hasCompleteKeystoreProperties) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (keystorePropertiesFile.exists() && hasCompleteKeystoreProperties) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}
