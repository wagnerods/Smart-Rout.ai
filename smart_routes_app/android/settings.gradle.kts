pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        requireNotNull(flutterSdkPath) { "flutter.sdk not set in local.properties" }
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
        //maven { url = uri("https://maven.google.com") }
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()

        // Permitir dependências Flutter (repositório de artefatos do Flutter)
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }

        // (Exemplo) MapLibre caso precise depois
        maven { url = uri("https://maven.pkg.jetbrains.space/public/p/compose/dev") }

        // (Exemplo) Mapbox (caso decida manter algo misto)
        // maven {
        //     url = uri("https://api.mapbox.com/downloads/v2/releases/maven")
        //     credentials {
        //         username = "mapbox"
        //         password = providers.gradleProperty("MAPBOX_DOWNLOADS_TOKEN").get()
        //     }
        // }
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.0" apply false
    id("org.jetbrains.kotlin.android") version "2.1.10" apply false
}

include(":app")
