package net.binjamshid.makhtoot.mk.export

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.color.MkIccProfile
import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.entitlement.MkEntitlementProviding
import net.binjamshid.makhtoot.mk.foundation.stubs.MkFontProviding
import net.binjamshid.makhtoot.mk.foundation.stubs.MkSystemFontStubProvider
import net.binjamshid.makhtoot.mk.model.MkScene
import net.binjamshid.makhtoot.mk.render.MkAssetProviding
import net.binjamshid.makhtoot.mk.render.MkEmptyAssetProvider
import net.binjamshid.makhtoot.mk.render.MkSnapshotRenderer

interface MkExportHistoryRecording {
    suspend fun record(result: MkExportResult)
}

class MkNoOpExportHistoryRecording : MkExportHistoryRecording {
    override suspend fun record(result: MkExportResult) { throw MkNotYetPorted("mk-export.MkNoOpExportHistoryRecording.record") }
    suspend fun recordFailure(error: Throwable, request: MkExportRequest) { throw MkNotYetPorted("mk-export.MkNoOpExportHistoryRecording.recordFailure") }
}

class MkExportCancellationToken : MkExportMemoryCooperating {
    fun cancel() { throw MkNotYetPorted("mk-export.MkExportCancellationToken.cancel") }
    override fun isCancelled(): Boolean { throw MkNotYetPorted("mk-export.MkExportCancellationToken.isCancelled") }
    override fun shouldPauseBeforeNextStrip(): Boolean { throw MkNotYetPorted("mk-export.MkExportCancellationToken.shouldPauseBeforeNextStrip") }
}

class MkExportCoordinator(
    val gate: MkExportGate = MkExportGate(),
    val history: MkExportHistoryRecording = MkNoOpExportHistoryRecording(),
    val renderer: MkSnapshotRenderer = MkSnapshotRenderer(),
    val fonts: MkFontProviding = MkSystemFontStubProvider(),
    val fontLicense: MkFontLicenseProviding = MkAllOflLicenseStub(),
    val fontData: MkExportFontDataProviding = MkNoFontDataProviding(),
    val assets: MkAssetProviding = MkEmptyAssetProvider(),
    val cmykProfile: (() -> MkIccProfile)? = null,
    val maxTileBytes: Int? = null
) {
    fun progressUpdates(): kotlinx.coroutines.flow.Flow<Double> { throw MkNotYetPorted("mk-export.MkExportCoordinator.progressUpdates") }
    suspend fun export(request: MkExportRequest, scene: MkScene, entitlement: MkEntitlementProviding, premiumAssetNodeIDs: Set<MkNodeId> = emptySet(), filenameBase: String = "مخطوط", destinationDirectory: java.net.URI? = null, cooperation: MkExportMemoryCooperating = MkNoOpMemoryCooperation()): MkExportResult { throw MkNotYetPorted("mk-export.MkExportCoordinator.export") }
}

