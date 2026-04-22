import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
}

/**
 * Load the upload-key credentials from `keystore.properties`, which lives next
 * to the `app/` module and is git-ignored. Never commit keystore paths or
 * passwords. Play App Signing keeps the *app* signing key; we only hold an
 * *upload* key on the local machine.
 *
 * Example keystore.properties:
 *     storeFile=../keystore/claudescope-upload.jks
 *     storePassword=...
 *     keyAlias=claudescope
 *     keyPassword=...
 */
val keystorePropertiesFile = rootProject.file("keystore.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}
val hasUploadKey = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "io.sandwichlab.claudescope"
    compileSdk = 35

    defaultConfig {
        applicationId = "io.sandwichlab.claudescope"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"

        resourceConfigurations += listOf("en", "zh-rCN")

        // Shared cross-platform AppsFlyer dev key — mirrors iOS
        // AnalyticsService.swift. Rotate in one place if Anthropic ever revokes it.
        buildConfigField(
            "String",
            "APPSFLYER_DEV_KEY",
            "\"eyJhbGciOiJBMjU2S1ciLCJjdHkiOiJKV1QiLCJlbmMiOiJBMjU2R0NNIiwidHlwIjoiSldUIiwiemlwIjoiREVGIn0.FBaODeELtryydtiKyDGHHtz9QcDLl2juHqhNBf_hnz7iG9Xi0VJ0AA.L5fKWf0otHir7hmt.1IRUevn_P4It9Y89vokteK8tWq8wDBaUNvJf9KeYQ1m5hQ-5D09BhEtzrFVukPTjvAEGNr3dtetYIt2BgxE8V-mD3dfDYRKiYir0lVB11Ty0mLRvgl2xAr8g-9tf2N-tZ04uFn9v2Vs16-TCeUL5zF0I_JTR0y58rzuqPrdJ-NXIvvyLkVtQMJncDjgRFLXziCPSAwgnmZk7CwRYwg81Uu92bO7cv9sxhu4bYzSXKCaTXHcqDz6kJ03EHIRFEEpoN1Mln01o2MBHRISABUaOYRGbGMBouIExwTPoondDg5J5z3ZpqHlHmGkyM6kQrNx5PWgSM4122SvTfTpTeZKMISs.DtbOg9GlkxzQ1IzWmYxaTw\"",
        )
    }

    signingConfigs {
        if (hasUploadKey) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            if (hasUploadKey) {
                signingConfig = signingConfigs.getByName("release")
            }
            // When keystore.properties is missing we skip signingConfig so
            // local dev builds still succeed — the output AAB/APK just won't
            // be signed with the real upload key.
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }

    sourceSets {
        getByName("main") {
            kotlin.srcDirs("src/main/kotlin")
        }
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.material.icons.extended)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.androidx.browser)
    implementation(libs.androidx.security.crypto)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.okhttp)
    debugImplementation(libs.okhttp.logging)
    implementation(libs.androidx.datastore.preferences)
    implementation(libs.androidx.work.runtime.ktx)
    implementation(libs.androidx.glance.appwidget)
    implementation(libs.androidx.glance.material3)
    implementation(libs.appsflyer.sdk)
    implementation(libs.install.referrer)
    implementation(libs.play.services.ads.identifier)
    implementation(libs.facebook.core)

    debugImplementation(libs.androidx.compose.ui.tooling)
}
