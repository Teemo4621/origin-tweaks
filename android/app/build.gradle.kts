import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val helperAssetsDir = layout.buildDirectory.dir("generated/helper_assets")
val embedHelperApk = tasks.register<Copy>("embedHelperApk") {
    dependsOn(":helper:assembleRelease")
    from(rootProject.layout.buildDirectory.dir("helper/outputs/apk/release")) {
        include("*.apk")
        rename { "helper.apk" }
    }
    into(helperAssetsDir)
}

val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

android {
    namespace = "dev.origintweaks.origin_tweaks"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        aidl = true
    }

    sourceSets {
        getByName("main") {
            assets.srcDir(helperAssetsDir.get().asFile)
        }
    }

    defaultConfig {
        applicationId = "dev.origintweaks.origin_tweaks"
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystoreProperties.isNotEmpty()) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
    }
}

tasks.named("preBuild") {
    dependsOn(embedHelperApk)
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    val shizukuVersion = "13.1.5"
    implementation("dev.rikka.shizuku:api:$shizukuVersion")
    implementation("dev.rikka.shizuku:provider:$shizukuVersion")

    testImplementation("junit:junit:4.13.2")
}

flutter {
    source = "../.."
}
