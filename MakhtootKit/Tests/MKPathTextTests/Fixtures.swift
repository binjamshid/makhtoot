import CoreGraphics
import MKFoundation
import MKModel
@testable import MKPathText
import MKTextEngine

/// Shared fixtures for `MKPathTextTests` ، same pattern
/// `MKTextEngineTests/Fixtures.swift` and `MKArrangeTests/ArrangeTestFixtures.swift`
/// already established (duplicated per test target, not shared via a
/// resource-bundle indirection ، see either file's own header comment for
/// why).
enum Fixtures {
    static let engine = MKShapingEngine()

    static func style(size: Double = 36, direction: MKBaseDirection = .rightToLeft) -> MKTextStyle {
        MKTextStyle(font: .systemFallback, pointSize: size, baseDirection: direction)
    }

    static func shape(_ text: String, size: Double = 36, direction: MKBaseDirection = .rightToLeft) -> MKShapedLine {
        engine.shapeSingleLine(MKShapingRequest(string: text, style: style(size: size, direction: direction)))
    }

    // MARK: - §6 canonical fixture strings

    static let bismillah = "بسم الله الرحمن الرحيم"
    static let laLigature = "لا رجل"
    static let shaddaStack = "شَدَّةٌ"
    static let mixedBidiDigits = "عام ٢٠٢٦ Design"
    static let multiSwitch = "Hello سلام World ٤٥"
    static let noSpaceDigits = "الرقم٤٥"
    static let tatweelStretch = "مـــد"
    static let numeralsArabic = "١٢٣٤٥"
    static let numeralsLatin = "12345"

    // MARK: - Path helpers

    static func straightLine(length: CGFloat = 2000) -> BezierPathModel {
        .line(from: CGPoint(x: 0, y: 0), to: CGPoint(x: length, y: 0))
    }

    static func gentleArc(radius: CGFloat = 600) -> BezierPathModel {
        .arc(center: .zero, radius: radius, startAngle: -.pi / 2, endAngle: .pi / 2)
    }

    static func circle(radius: CGFloat = 300) -> BezierPathModel {
        .circle(center: .zero, radius: radius)
    }

    /// A tight, near-cusp "star point" fixture meant to trip the curvature
    /// warning (task 8.3 / §6's "sharp-corner star path" fixture): three
    /// anchors forming a 90°-turn corner with no smoothing handles, sized
    /// so the corner sits INSIDE the laid text's arc span (each leg is
    /// ~42 pt; a size-36 «سلام» is ~56 pt of advance, so glyphs straddle
    /// the corner ، the first version of this fixture had 300 pt legs and
    /// the whole text fit on the first straight leg, never crossing the
    /// corner at all, caught on the first test run).
    static func sharpCorner() -> BezierPathModel {
        BezierPathModel(anchors: [
            PathAnchor(point: CGPoint(x: 0, y: 0)),
            PathAnchor(point: CGPoint(x: 30, y: -30)),
            PathAnchor(point: CGPoint(x: 60, y: 0)),
        ], isClosed: false)
    }
}
