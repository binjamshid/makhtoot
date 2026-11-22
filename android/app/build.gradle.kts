// The app's free access policy comes from :mk-foundation.
// The legacy :mk-store scaffold stands alone.

plugins {
    id("mk.android.application")
}

android {
    namespace = "net.binjamshid.makhtoot"

    defaultConfig {
        applicationId = "net.binjamshid.makhtoot"
        versionCode = 1
        versionName = "1.0"
    }
}

dependencies {
    implementation(project(":mk-native"))
    implementation(project(":mk-foundation"))
    implementation(project(":mk-model"))
    implementation(project(":mk-textengine"))
    implementation(project(":mk-arrange"))
    implementation(project(":mk-pathtext"))
    implementation(project(":mk-canvas"))
    implementation(project(":mk-render"))
    implementation(project(":mk-color"))
    implementation(project(":mk-export"))
    implementation(project(":mk-fonts"))
    implementation(project(":mk-persistence"))
    implementation(project(":mk-sync"))
    implementation(project(":mk-analytics"))
    implementation(project(":mk-designsystem"))
    implementation(project(":mk-assets"))
}
