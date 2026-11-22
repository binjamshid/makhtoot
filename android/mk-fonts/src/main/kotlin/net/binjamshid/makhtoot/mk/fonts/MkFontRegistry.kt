package net.binjamshid.makhtoot.mk.fonts

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.stubs.MkPlatformFont

class MkFontRegistry {
    val recordsDidChange: kotlinx.coroutines.flow.Flow<List<MkFontRecord>>
        get() = throw MkNotYetPorted("mk-fonts.MkFontRegistry.recordsDidChange")
    fun loadBundled(index: MkBundledFontIndex = MkBundledFontIndex()): List<MkFontId> { throw MkNotYetPorted("mk-fonts.MkFontRegistry.loadBundled") }
    fun registerURL(url: java.net.URI) { throw MkNotYetPorted("mk-fonts.MkFontRegistry.registerURL") }
    fun unregisterURL(url: java.net.URI) { throw MkNotYetPorted("mk-fonts.MkFontRegistry.unregisterURL") }
    fun isFontSystemInstalled(fontID: MkFontId): Boolean { throw MkNotYetPorted("mk-fonts.MkFontRegistry.isFontSystemInstalled") }
    fun systemInstalledFontIDs(): Set<MkFontId> { throw MkNotYetPorted("mk-fonts.MkFontRegistry.systemInstalledFontIDs") }
    suspend fun installFontSystemWide(fontID: MkFontId) { throw MkNotYetPorted("mk-fonts.MkFontRegistry.installFontSystemWide") }
    suspend fun uninstallFontSystemWide(fontID: MkFontId) { throw MkNotYetPorted("mk-fonts.MkFontRegistry.uninstallFontSystemWide") }
    fun refreshSystemInstalledStatus() { throw MkNotYetPorted("mk-fonts.MkFontRegistry.refreshSystemInstalledStatus") }
    fun records(): List<MkFontRecord> { throw MkNotYetPorted("mk-fonts.MkFontRegistry.records") }
    fun faces(): List<MkFontFace> { throw MkNotYetPorted("mk-fonts.MkFontRegistry.faces") }
    fun record(fontID: MkFontId): MkFontRecord? { throw MkNotYetPorted("mk-fonts.MkFontRegistry.record") }
    fun face(fontID: MkFontId, postScriptName: String? = null): MkFontFace? { throw MkNotYetPorted("mk-fonts.MkFontRegistry.face") }
    fun licenseRecord(fontID: MkFontId): MkLicenseRecord? { throw MkNotYetPorted("mk-fonts.MkFontRegistry.licenseRecord") }
    fun verificationEvidence(fontID: MkFontId): MkFontVerificationEvidence? { throw MkNotYetPorted("mk-fonts.MkFontRegistry.verificationEvidence") }
    fun isProvisionalShip(fontID: MkFontId): Boolean { throw MkNotYetPorted("mk-fonts.MkFontRegistry.isProvisionalShip") }
    fun ctFont(fontID: MkFontId, postScriptName: String? = null, size: Double): MkPlatformFont { throw MkNotYetPorted("mk-fonts.MkFontRegistry.ctFont") }
    fun registerDownloaded(record: MkFontRecord, license: MkLicenseRecord) { throw MkNotYetPorted("mk-fonts.MkFontRegistry.registerDownloaded") }
    fun registerImported(record: MkFontRecord, license: MkLicenseRecord) { throw MkNotYetPorted("mk-fonts.MkFontRegistry.registerImported") }
    fun remove(fontID: MkFontId) { throw MkNotYetPorted("mk-fonts.MkFontRegistry.remove") }
    fun setLocked(locked: Boolean, origins: Set<MkFontOrigin>? = null) { throw MkNotYetPorted("mk-fonts.MkFontRegistry.setLocked") }
    fun setLocked(locked: Boolean, fontID: MkFontId) { throw MkNotYetPorted("mk-fonts.MkFontRegistry.setLocked") }
    fun coverageReport(fontID: MkFontId): MkCoverageReport? { throw MkNotYetPorted("mk-fonts.MkFontRegistry.coverageReport") }
}

