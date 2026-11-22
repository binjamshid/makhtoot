# Build and test Makhtoot

Start from the root of a local clone. The iPhone and iPad editor lives in `Makhtoot.xcodeproj`. Android is a port in progress under `android/`. Use the Android configuration and module test commands below to start contributing to it.

## iPhone and iPad

Install Xcode with a Swift 6 toolchain and an iOS Simulator runtime. The project targets iOS and iPadOS 18.0 and later. The app links the local Swift package and has no external Swift package dependencies. [Xcode project](../Makhtoot.xcodeproj/project.pbxproj) · [Swift package manifest](../MakhtootKit/Package.swift)

```sh
xcodebuild -version
xcodebuild -project Makhtoot.xcodeproj -scheme Makhtoot -configuration Debug \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

This command compiles the simulator app without signing. To try the editor, open `Makhtoot.xcodeproj` in Xcode, select the shared `Makhtoot` scheme and an installed iPhone or iPad simulator, then choose **Run**. The app's bundle identifier is `net.binjamshid.makhtoot`. [Shared scheme](../Makhtoot.xcodeproj/xcshareddata/xcschemes/Makhtoot.xcscheme)

### Focused Swift check

Run the right-to-left utilities tests on your Mac. They cover digit conversion, direction detection for mixed Arabic and Latin text, and bidirectional isolation.

```sh
swift test --package-path MakhtootKit --filter RTLUtilitiesTests
```

For changes to onboarding or initial project creation, run the app's focused UI test on an installed simulator. Copy the simulator ID from the destination list and replace `SIMULATOR_UUID`.

```sh
xcodebuild -project Makhtoot.xcodeproj -scheme Makhtoot -showdestinations

xcodebuild -project Makhtoot.xcodeproj -scheme Makhtoot \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UUID' \
  -only-testing:MakhtootUITests/OnboardingFirstProjectUITests test
```

The app scheme runs `MakhtootUITests`. To run a package suite against iOS, open the package in Xcode and use its `MakhtootKit-Package` scheme with a simulator destination. [MakhtootKit guide](../MakhtootKit/README.md) · [UI test source](../MakhtootUITests/OnboardingFirstProjectUITests.swift)

## Android

Open the `android/` directory in Android Studio, or use a shell with JDK 17, the Android SDK command-line tools and SDK Platform 36. Set `JAVA_HOME` to your JDK 17 and `ANDROID_HOME` to your SDK, or set `sdk.dir` in `android/local.properties` for SDK discovery. For the native module, install NDK `28.2.13676358` and CMake `3.22.1` through SDK Manager. The checked-in wrapper uses Gradle 8.11.1. The project's minimum Android API level is 29. [Version catalog](../android/gradle/libs.versions.toml) · [Gradle wrapper](../android/gradle/wrapper/gradle-wrapper.properties) · [SDK settings](../android/build-logic/convention/src/main/kotlin/ConfigureKotlinAndroid.kt)

Run from `android/`. The `-D` option overrides the checkout's machine-specific Gradle JDK path. The wrapper and Gradle dependencies may need network access on first use. [Gradle properties](../android/gradle.properties)

```sh
cd android
./gradlew -Dorg.gradle.java.home="$JAVA_HOME" help
./gradlew -Dorg.gradle.java.home="$JAVA_HOME" projects
```

### Focused Kotlin check

Run the foundation module's local JVM smoke test from `android/`. It checks serialization and exercises an unported API's placeholder behavior. It needs no emulator.

```sh
./gradlew -Dorg.gradle.java.home="$JAVA_HOME" :mk-foundation:testDebugUnitTest \
  --tests net.binjamshid.makhtoot.mk.foundation.MkFoundationStubTest
```

From the same directory, use the following command to investigate APK assembly. The port still contains unimplemented code and the manifest has no launcher activity. The recorded full debug build encountered compile failures. [Android manifest](../android/app/src/main/AndroidManifest.xml) · [Android build record](../android/docs/impl-log/BATCH-1.4-repair.md) · [JVM test source](../android/mk-foundation/src/test/kotlin/net/binjamshid/makhtoot/mk/foundation/MkFoundationStubTest.kt)

```sh
./gradlew -Dorg.gradle.java.home="$JAVA_HOME" :app:assembleDebug
```

## Accounts and hosted services

- The local package and Android module checks require no store or cloud accounts. The shared Xcode scheme references a checked-in StoreKit configuration for local purchase testing.
- Physical Apple device signing and live CloudKit testing require appropriate signing and capabilities. To test live purchases or sync in a fork, use your own project identifiers, signing setup, and corresponding App Store Connect and iCloud configuration.
- The premium font downloader takes a catalog URL. A hosted catalog requires its own endpoint, while local work can exercise bundled fonts.
- The Android port plans to use Play Billing and Google Drive. Live testing of those integrations requires your own service setup once the app has those paths implemented.

[Local StoreKit configuration](../Makhtoot/Config/Makhtoot.storekit) · [iOS entitlements](../Makhtoot/Config/Makhtoot.entitlements) · [Premium font delivery](../MakhtootKit/Sources/MKFonts/MKPremiumDelivery.swift) · [Platform decisions](../FOUNDATION.md)

## Export fixture checks

From `MakhtootKit/`, run `swift run MKGoldenExport` to refresh Android's tracked PNG, JPEG, SVG, and other parity fixtures. The [determinism manifest](../android/fixtures/DETERMINISM_EXCLUSIONS.json) records the JPEG exclusion for byte comparisons.

Run `swift run MKGoldenExport --local-pdf` from the same directory for the four vector RGB reference PDFs. The command writes only to the ignored `MakhtootKit/.build/mk-golden-export/pdf/` directory. Use them for local structural comparison, since Core Graphics can embed system font subsets and color profiles in the output.

The following tests generate PDFs in temporary storage and check page structure, text embedding, raster content, and CMYK output intents. [PDF exporter tests](../MakhtootKit/Tests/MKExportTests/)

```sh
swift test --filter PDFVectorExporterTests
swift test --filter PDFRasterExporterTests
swift test --filter PDFPrintCMYKExporterTests
```

## CI and verification limits

| Check | Coverage |
| --- | --- |
| [iOS workflow](../.github/workflows/ci.yml) | Repository hygiene scripts and a host `swift build` of MakhtootKit. |
| [Android workflow](../.github/workflows/android-ci.yml) | Android hygiene scripts, a parity checklist gate, and Gradle `help` and `projects`. |
| App and device verification | Run the iOS simulator checks separately. Android still needs APK assembly and a launchable activity before editor walkthroughs. Hosted service behavior requires a configured environment. |

Commands here are based on the checked-in project and test definitions. Fresh-checkout builds, test results, and device launches were not verified for this edition of the guide. Use the [test matrix](../TEST_MATRIX.md) for coverage beyond these focused checks and the [Android parity matrix](../android/PARITY_MATRIX.md) for port progress.

## Traceability

The setup covers the platform and offline-development requirements in the brief. The focused checks cover Arabic text direction and first-project creation on iOS, and foundation contract coverage on Android. [Foundation decisions](../FOUNDATION.md) · [Test matrix](../TEST_MATRIX.md)
