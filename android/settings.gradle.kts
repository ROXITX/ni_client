pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }

    plugins {
        id("dev.flutter.flutter-plugin-loader") version "1.0.0"
        id("com.android.application") version "8.7.2"
        id("com.google.gms.google-services") version "4.4.1"
        id("org.jetbrains.kotlin.android") version "2.1.0"
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader")
    id("com.android.application") apply false
    id("com.google.gms.google-services") apply false
    id("org.jetbrains.kotlin.android") apply false
}

if (System.getenv("FORCE_GRADLE_REFRESH") == "1") {
    println("[settings.gradle] FORCE_GRADLE_REFRESH=1 detected. Re-run with --refresh-dependencies to force resolution.")
}

include(":app")
