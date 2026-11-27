import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releasePropertiesFile = rootProject.file("key.properties")
val releaseProperties = Properties().apply {
    if (releasePropertiesFile.isFile) releasePropertiesFile.inputStream().use { load(it) }
}

android {
    namespace = "com.example.balamandian"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        manifestPlaceholders["communityLinksHost"] = providers.gradleProperty("communityLinksHost").getOrElse("links.balamandian.invalid")
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.balamandian"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    if (releasePropertiesFile.isFile) {
        signingConfigs.create("production") {
            fun property(name: String): String = requireNotNull(releaseProperties.getProperty(name)) {
                "Set $name in android/key.properties for release signing."
            }
            storeFile = rootProject.file(property("storeFile"))
            storePassword = property("storePassword")
            keyAlias = property("keyAlias")
            keyPassword = property("keyPassword")
        }
    }

    buildTypes {
        debug {
            if (providers.environmentVariable("BALAMANDIAN_ISOLATED_VOICE_DEMO").orNull == "true") {
                applicationIdSuffix = ".voiceqa"
            }
        }
        release {
            signingConfig = signingConfigs.findByName("production")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
