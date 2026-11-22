package net.binjamshid.makhtoot.mk.fonts

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.stubs.MkPlatformFont

class MkCoverageAnalyzer {
    fun analyze(font: MkPlatformFont): MkCoverageReport { throw MkNotYetPorted("mk-fonts.MkCoverageAnalyzer.analyze") }
    data class RangeCoverage(
        var rangeName: String,
        var coveredCount: Int,
        var totalCount: Int,
        var percentage: Double
    )
}

data class MkCoverageReport(
    var ranges: List<MkCoverageAnalyzer.RangeCoverage>,
    var supportsTashkeel: Boolean,
    var supportsQuranicMarks: Boolean,
    var supportsLatin: Boolean
)


fun Any.hasMember(scalar: Long): Boolean { throw MkNotYetPorted("mk-fonts.Any.hasMember") }

