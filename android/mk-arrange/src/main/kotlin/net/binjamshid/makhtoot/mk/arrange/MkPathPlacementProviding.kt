package net.binjamshid.makhtoot.mk.arrange

import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint
import net.binjamshid.makhtoot.mk.textengine.MkGlyphAddress

/**
 * A resolved glyph placement along a path (D-110 seam). Ports
 * `Sources/MKArrange/PathPlacementProviding.swift`'s `MKPathGlyphPlacement`.
 *
 * **Same-name note (not a naming-rule collision, `ANDROID_SPINE.md` §3.3):**
 * `mk-pathtext` independently ports its OWN, different Swift type also named
 * `MKPathGlyphPlacement` (from `PathGlyphPlacement.swift`) to the same
 * mechanical Kotlin name `MkPathGlyphPlacement`, but in package
 * `net.binjamshid.makhtoot.mk.pathtext`. This mirrors the Swift source
 * exactly, where the two same-named types already coexist disambiguated only
 * by their owning module (`MKArrange` vs `MKPathText`) — Kotlin's package
 * system disambiguates the same way, so no rename was needed or made.
 */
data class MkPathGlyphPlacement(
    var position: MkPoint,
    var tangentAngle: Double,
)

/**
 * Path-placement override seam (D-110, WS-05). Ports `PathPlacementProviding`.
 */
interface MkPathPlacementProviding {
    /** Returns a placement override for [address] on [lineIndex], or `null` for the default straight-baseline placement. */
    fun placement(address: MkGlyphAddress, lineIndex: Int): MkPathGlyphPlacement?
}

/** The default: no override, every glyph uses the straight-baseline placement. Ports `IdentityPlacement`. */
class MkIdentityPlacement : MkPathPlacementProviding {
    override fun placement(address: MkGlyphAddress, lineIndex: Int): MkPathGlyphPlacement? = null
}
