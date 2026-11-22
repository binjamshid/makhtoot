package net.binjamshid.makhtoot.mk.canvas

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.canvas.arrange.MkArrangeInteractionModel
import net.binjamshid.makhtoot.mk.canvas.pathtext.MkPathEditChromeLayer
import net.binjamshid.makhtoot.mk.canvas.pathtext.MkPathTextInteractionModel
import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.geometry.MkRect

class MkCanvasViewController(
    val session: MkCanvasSession,
    val scrollView: UIScrollView = UIScrollView(),
    val contentHostView: UIView = UIView(),
    val selectionChrome: MkSelectionChromeLayer = MkSelectionChromeLayer(),
    val pathEditChrome: MkPathEditChromeLayer = MkPathEditChromeLayer(),
    val guideRenderer: MkGuideRenderer = MkGuideRenderer(),
    val gridRenderer: MkGuideRenderer = MkGuideRenderer(),
    var activeTextOverlay: MkTextEditingOverlayView? = null,
    var onViewportChanged: ((MkRect, Double) -> Unit)? = null
) : UIViewController, UIScrollViewDelegate {
    val arrangeInteraction: MkArrangeInteractionModel?
        get() = throw MkNotYetPorted("mk-canvas.MkCanvasViewController.arrangeInteraction")
    val pathTextInteraction: MkPathTextInteractionModel?
        get() = throw MkNotYetPorted("mk-canvas.MkCanvasViewController.pathTextInteraction")
    val onArrangedNodeDoubleTapped: ((MkNodeId) -> Unit)?
        get() = throw MkNotYetPorted("mk-canvas.MkCanvasViewController.onArrangedNodeDoubleTapped")
    fun viewDidLoad() { throw MkNotYetPorted("mk-canvas.MkCanvasViewController.viewDidLoad") }
    fun viewDidLayoutSubviews() { throw MkNotYetPorted("mk-canvas.MkCanvasViewController.viewDidLayoutSubviews") }
    fun viewForZooming(scrollView: UIScrollView): UIView? { throw MkNotYetPorted("mk-canvas.MkCanvasViewController.viewForZooming") }
    fun scrollViewDidZoom(scrollView: UIScrollView) { throw MkNotYetPorted("mk-canvas.MkCanvasViewController.scrollViewDidZoom") }
    fun scrollViewDidScroll(scrollView: UIScrollView) { throw MkNotYetPorted("mk-canvas.MkCanvasViewController.scrollViewDidScroll") }
    fun zoomToFit() { throw MkNotYetPorted("mk-canvas.MkCanvasViewController.zoomToFit") }
    fun zoomTo100Percent() { throw MkNotYetPorted("mk-canvas.MkCanvasViewController.zoomTo100Percent") }
    companion object {
        val minimumZoom: Double = 0.1
        val maximumZoom: Double = 64.0
    }
}

