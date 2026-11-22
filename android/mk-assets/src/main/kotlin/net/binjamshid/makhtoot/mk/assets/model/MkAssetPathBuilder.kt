package net.binjamshid.makhtoot.mk.assets.model

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint
import net.binjamshid.makhtoot.mk.foundation.geometry.MkRect
import net.binjamshid.makhtoot.mk.model.MkBezierSegment

object MkAssetPathBuilder {
    fun polyline(points: List<MkPoint>, closed: Boolean): MkAssetSubpath { throw MkNotYetPorted("mk-assets.MkAssetPathBuilder.polyline") }
    fun regularPolygon(sides: Int, radius: Double, rotation: Double? = null): MkAssetSubpath { throw MkNotYetPorted("mk-assets.MkAssetPathBuilder.regularPolygon") }
    fun starPolygon(points: Int, outerRadius: Double, innerRatio: Double, rotation: Double? = null): MkAssetSubpath { throw MkNotYetPorted("mk-assets.MkAssetPathBuilder.starPolygon") }
    fun circle(center: MkPoint, radius: Double, reversed: Boolean = false): MkAssetSubpath { throw MkNotYetPorted("mk-assets.MkAssetPathBuilder.circle") }
    fun arcSegments(center: MkPoint, radius: Double, startAngle: Double, endAngle: Double): List<MkBezierSegment> { throw MkNotYetPorted("mk-assets.MkAssetPathBuilder.arcSegments") }
    fun ring(center: MkPoint, outerRadius: Double, innerRadius: Double): List<MkAssetSubpath> { throw MkNotYetPorted("mk-assets.MkAssetPathBuilder.ring") }
    fun crescent(outerRadius: Double, innerRadius: Double, offset: Double): List<MkAssetSubpath> { throw MkNotYetPorted("mk-assets.MkAssetPathBuilder.crescent") }
    fun pointedArchSegments(leftSpring: MkPoint, rightSpring: MkPoint): List<MkBezierSegment> { throw MkNotYetPorted("mk-assets.MkAssetPathBuilder.pointedArchSegments") }
    fun roundedRect(rect: MkRect, cornerRadius: Double): MkAssetSubpath { throw MkNotYetPorted("mk-assets.MkAssetPathBuilder.roundedRect") }
    fun subpath(cgPath: Any): MkAssetSubpath { throw MkNotYetPorted("mk-assets.MkAssetPathBuilder.subpath") }
    fun ribbon(centerline: List<MkPoint>, widths: List<Double>): MkAssetSubpath { throw MkNotYetPorted("mk-assets.MkAssetPathBuilder.ribbon") }
}

