import Foundation
import Observation

/// Shared model for the in-editor first-use tour. Injected via
/// `.environment(tourModel)` on `EditorContentView`; consumed by
/// `EditorTourOverlay` (reads state/text) and `ToolRailView` (reports button
/// frames). Frames are in `.global` coordinate space so the overlay's
/// `GeometryReader` can subtract its own global origin to get local coords.
@Observable
final class EditorTourModel {
    var addButtonFrame: CGRect = .zero
    var fontButtonFrame: CGRect = .zero
    var arrangeButtonFrame: CGRect = .zero
    private(set) var step: Int = 0

    var isCompleted: Bool = UserDefaults.standard.bool(forKey: "MKEditorTourCompleted") {
        didSet { UserDefaults.standard.set(isCompleted, forKey: "MKEditorTourCompleted") }
    }

    let stepCount: Int = 3

    var isLastStep: Bool { step == stepCount - 1 }

    var currentHighlightFrame: CGRect {
        switch step {
        case 0: return addButtonFrame
        case 1: return fontButtonFrame
        default: return arrangeButtonFrame
        }
    }

    var currentTitle: String {
        switch step {
        case 0: return "أضِف عناصر بـ +"
        case 1: return "اضبط الخط بـ أء"
        default: return "الترتيب الحر"
        }
    }

    var currentBody: String {
        switch step {
        case 0: return "اضغط + في شريط الأدوات لإضافة حقل نص أو شكل إلى اللوحة"
        case 1: return "حدّد نصاً ثم اضغط أء لتغيير الخط والحجم"
        default: return "اضغط مطوّلاً على حرف لتفعيل وضع الترتيب وتحريكه بحرية"
        }
    }

    func advance() {
        if step < stepCount - 1 { step += 1 } else { isCompleted = true }
    }

    func skip() { isCompleted = true }

    func restart() {
        isCompleted = false
        step = 0
    }
}
