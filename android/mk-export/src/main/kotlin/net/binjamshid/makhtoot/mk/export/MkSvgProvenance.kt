package net.binjamshid.makhtoot.mk.export

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkAffineTransform
import net.binjamshid.makhtoot.mk.model.MkShapeGeometry
import net.binjamshid.makhtoot.mk.model.MkSolidColor

object MkSvgxml {
    fun escape(string: String): String { throw MkNotYetPorted("mk-export.MkSvgxml.escape") }
    fun number(value: Double): String { throw MkNotYetPorted("mk-export.MkSvgxml.number") }
    fun number(value: Double): String { throw MkNotYetPorted("mk-export.MkSvgxml.number") }
    fun hexCodepoints(codepoints: List<Long>): String { throw MkNotYetPorted("mk-export.MkSvgxml.hexCodepoints") }
    fun matrix(t: MkAffineTransform): String { throw MkNotYetPorted("mk-export.MkSvgxml.matrix") }
    fun hexColor(color: MkSolidColor): String { throw MkNotYetPorted("mk-export.MkSvgxml.hexColor") }
    fun pathData(path: Any): String { throw MkNotYetPorted("mk-export.MkSvgxml.pathData") }
}

object MkSvgShapeGeometry {
    fun localPath(geometry: MkShapeGeometry): Any? { throw MkNotYetPorted("mk-export.MkSvgShapeGeometry.localPath") }
}

