package net.binjamshid.makhtoot.mk.color

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

/**
 * Ports `Sources/MKColor/MKColorSpec.swift` **and**
 * `Sources/MKColor/MKColorSpec+HSB.swift`.
 *
 * **Naming-collision resolution (`ANDROID_SPINE.md` §3.3/§9, recorded per
 * `BATCH-1.3.md`):** `MKColorSpec+HSB.swift` is a `+`-extension file with no
 * valid mechanical Kotlin filename. Resolved by merging its members
 * (`MKHSBAComponents`, `MKColorSpec.hsba`, `MKColorSpec.init(hsba:)`)
 * directly into this file, rather than creating a separate
 * `MkColorSpecHsb.kt` — both options were permitted by the packet; this one
 * was chosen because the HSB conversion is small (8 symbols) and
 * conceptually inseparable from `MkColorSpec` itself.
 *
 * Color working space tag. Ports `MKColorSpaceTag`. Kept as a separate type
 * from any `mk-model` colour-space tag — `mk-model` must not import
 * `mk-color`, and `mk-color` must not import `mk-model`
 * (`ANDROID_SPINE.md` §3.2 dependency edges draw no edge between them).
 *
 * Swift's `MKColorSpaceTag: String` gives each case an implicit raw value
 * equal to its case name (`"srgb"`, `"displayP3"`). [SerialName] pins the
 * Kotlin serialized form to those exact strings rather than Kotlin's default
 * `Srgb`/`DisplayP3` enum-constant names — this field can appear inside a
 * `.makhtoot` `scene.json` that crosses platforms (D-309's zip interchange),
 * so the on-disk JSON shape must match iOS's `Codable` encoding byte-for-byte,
 * not merely round-trip within Kotlin.
 */
@Serializable
enum class MkColorSpaceTag {
    @SerialName("srgb")
    Srgb,

    @SerialName("displayP3")
    DisplayP3,
}

/**
 * The document/working-space color value: extended sRGB components (may
 * exceed `0...1`, D-117), plus an optional named-swatch reference. Ports
 * `MKColorSpec`.
 */
@Serializable
data class MkColorSpec(
    var r: Double,
    var g: Double,
    var b: Double,
    var a: Double = 1.0,
    var swatch: String? = null,
) {
    companion object {
        val black = MkColorSpec(r = 0.0, g = 0.0, b = 0.0)
        val white = MkColorSpec(r = 1.0, g = 1.0, b = 1.0)
        val clear = MkColorSpec(r = 0.0, g = 0.0, b = 0.0, a = 0.0)
    }

    /** The canonical DISPLAY/EXPORT-sRGB path (D-117 §15.1/§15.4). */
    fun cgColor(): MkPlatformColor = throw MkNotYetPorted("MkColorSpec.cgColor")

    /** The DISPLAY-ONLY P3 path (D-117: "P3 is display-only, never stored"). */
    fun cgColorDisplayP3(): MkPlatformColor = throw MkNotYetPorted("MkColorSpec.cgColorDisplayP3")

    /** A finite `0...1`-clamped sRGB color — the form every raster encoder actually paints with. */
    fun cgColorClampedSRGB(): MkPlatformColor = throw MkNotYetPorted("MkColorSpec.cgColorClampedSRGB")

    /**
     * RGB -> HSB. Ports `MKColorSpec.hsba` (from `MKColorSpec+HSB.swift`).
     * Input components are clamped to `0...1` first.
     */
    val hsba: MkHsbaComponents
        get() = throw MkNotYetPorted("MkColorSpec.hsba")
}

/**
 * HSB -> RGB (standard sector formula). Ports `MKColorSpec.init(hsba:)`
 * (from `MKColorSpec+HSB.swift`). Kotlin has no secondary-constructor-from-
 * conversion idiom as clean as Swift's `init(hsba:)`, so this is a factory
 * function rather than an additional constructor overload — a documented
 * mechanical substitution (`ANDROID_SPINE.md` §9), same throw-stub contract.
 */
fun MkColorSpec(hsba: MkHsbaComponents): MkColorSpec = throw MkNotYetPorted("MkColorSpec.init(hsba)")

/**
 * Hue/saturation/brightness/alpha, each nominally `0...1` (`hue` wraps).
 * Ports `MKHSBAComponents` (from `MKColorSpec+HSB.swift`). Pure value type.
 *
 * Deliberately NOT `@Serializable`: the Swift source (`Hashable, Sendable,
 * Equatable`) does not conform to `Codable` — this type is picker-UI-only
 * math, never persisted (D-117: document storage stays RGBA) — so marking
 * it `@Serializable` would grant a capability the Swift type never had.
 */
data class MkHsbaComponents(
    var hue: Double,
    var saturation: Double,
    var brightness: Double,
    var alpha: Double = 1.0,
)
