package net.binjamshid.makhtoot.mk.textengine

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.stubs.MkFontProviding
import net.binjamshid.makhtoot.mk.foundation.stubs.MkSystemFontStubProvider

/**
 * The WS-03 shaping-capture core (D-103): builds the attributed text,
 * drives the shaper, and assembles `MkShapedLine`/`MkShapedParagraph` with
 * cluster (D-105) and bidi (D-109) maps attached. Ports
 * `Sources/MKTextEngine/MKShapingEngine.swift`.
 *
 * This is the **pure, uncached** core; `MkShapingService` (the actor-backed
 * facade) is the cached facade ARCHITECTURE §4.4/§4.7 specifies ،
 * consumers on the typing-echo path use the service, batch/analysis
 * callers may use this directly. Sendable per D-102; stateless, cheap to
 * construct.
 */
class MkShapingEngine(fonts: MkFontProviding = MkSystemFontStubProvider()) {
    /**
     * Shapes `request.text` as one line with no width constraint (packet
     * task 4's capture core). Ignores `request.frame` ، callers wanting
     * width-constrained wrapping should call [shapeParagraph].
     */
    fun shapeSingleLine(request: MkShapingRequest): MkShapedLine =
        throw MkNotYetPorted("MkShapingEngine.shapeSingleLine")

    /**
     * Multi-line support (packet task 5): line-break loop when
     * `request.frame` is `.widthConstrained`; falls back to a single line
     * (equivalent to [shapeSingleLine]) for `.singleLine`.
     */
    fun shapeParagraph(request: MkShapingRequest): MkShapedParagraph =
        throw MkNotYetPorted("MkShapingEngine.shapeParagraph")
}
