package net.binjamshid.makhtoot.mk.canvas

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize
import net.binjamshid.makhtoot.mk.model.MkAssetRef
import net.binjamshid.makhtoot.mk.model.MkBezierPathData
import net.binjamshid.makhtoot.mk.model.MkImageKind
import net.binjamshid.makhtoot.mk.model.MkShapeGeometry
import net.binjamshid.makhtoot.mk.model.MkStyle
import net.binjamshid.makhtoot.mk.model.MkTextStyle

fun MkCanvasSession.addLiveText(point: MkPoint, text: String? = null, style: MkTextStyle? = null): MkNodeId { throw MkNotYetPorted("mk-canvas.MkCanvasSession.addLiveText") }
fun MkCanvasSession.addPathText(path: MkBezierPathData, point: MkPoint? = null, text: String? = null, style: MkTextStyle? = null): MkNodeId { throw MkNotYetPorted("mk-canvas.MkCanvasSession.addPathText") }
fun MkCanvasSession.addShape(geometry: MkShapeGeometry, point: MkPoint, size: MkSize? = null, style: MkStyle? = null): MkNodeId { throw MkNotYetPorted("mk-canvas.MkCanvasSession.addShape") }
fun MkCanvasSession.addImage(assetRef: MkAssetRef, kind: MkImageKind, point: MkPoint, isPhotoBackgroundUse: Boolean = false): MkNodeId { throw MkNotYetPorted("mk-canvas.MkCanvasSession.addImage") }

