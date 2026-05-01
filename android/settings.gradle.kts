pluginManagement {
    val flutterSdkPath = run {
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
        maven { url = uri("https://www.arthenica.com/maven") }
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader")
    // Dùng AGP 8.5.0 ổn định, tương thích Flutter 3.29.x hơn là 8.7.0
    id("com.android.application") version "8.5.0" apply false
    id("org.jetbrains.kotlin.android") version "1.8.22" apply false
}

include(":app")
