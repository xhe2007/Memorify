plugins {
    id("com.android.application")
    id("kotlin-android")
    // 必须放在最后（Flutter 官方要求）
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.zephyr.memorify"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973" // 统一为所有插件兼容的 NDK 版本

    defaultConfig {
        applicationId = "com.zephyr.memorify"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // 添加 OpenGL ES 版本配置
        renderscriptTargetApi = 21
        renderscriptSupportModeEnabled = true
        
        // 添加图形渲染优化
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
        }
    }

    signingConfigs {
        create("release") {
            storeFile = file("memorify.keystore")
            storePassword = "YYILG@jh1999"
            keyAlias = "memorify"
            keyPassword = "YYILG@jh1999"
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isShrinkResources = false
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }
}

flutter {
    source = "../.."
}