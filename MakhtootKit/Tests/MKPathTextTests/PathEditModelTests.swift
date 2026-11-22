import CoreGraphics
import MKModel
@testable import MKPathText
import Testing

@Suite("PathEditModel ، task 10 accepts")
struct PathEditModelTests {
    @Test("Hit-targets enumerate every anchor and its present handles")
    func hitTargetsEnumerate() {
        let path = BezierPathModel(anchors: [
            PathAnchor(point: .zero, handleOut: CGPoint(x: 10, y: 0)),
            PathAnchor(point: CGPoint(x: 100, y: 0), handleIn: CGPoint(x: 90, y: 0)),
        ], isClosed: false)
        let targets = PathEditModel.hitTargets(in: path)
        // 2 anchor points + anchor0's handleOut + anchor1's handleIn.
        #expect(targets.count == 4)
    }

    @Test("nearestHitTarget finds the closest control point within tolerance")
    func nearestHitTarget() {
        let path = BezierPathModel.line(from: .zero, to: CGPoint(x: 100, y: 0))
        let hit = PathEditModel.nearestHitTarget(to: CGPoint(x: 2, y: 1), in: path, tolerance: 10)
        #expect(hit != nil)
        #expect(hit?.id.kind == .anchor)
        let miss = PathEditModel.nearestHitTarget(to: CGPoint(x: 500, y: 500), in: path, tolerance: 10)
        #expect(miss == nil)
    }

    @Test("moveAnchor(moveHandles: true) translates the anchor's handles by the same delta")
    func moveAnchorTranslatesHandles() {
        let anchor = PathAnchor(point: CGPoint(x: 50, y: 50), handleIn: CGPoint(x: 40, y: 50), handleOut: CGPoint(x: 60, y: 50))
        let path = BezierPathModel(anchors: [anchor, PathAnchor(point: CGPoint(x: 200, y: 50))], isClosed: false)
        let moved = PathEditModel.moveAnchor(anchor.id, to: CGPoint(x: 70, y: 80), in: path)
        let updated = moved.anchors.first { $0.id == anchor.id }!
        #expect(updated.point == CGPoint(x: 70, y: 80))
        #expect(updated.handleIn == CGPoint(x: 60, y: 80))
        #expect(updated.handleOut == CGPoint(x: 80, y: 80))
    }

    @Test("moveHandle(.mirrored) keeps the opposite handle collinear and equidistant")
    func moveHandleMirrored() {
        let anchor = PathAnchor(point: CGPoint(x: 0, y: 0), handleIn: CGPoint(x: -20, y: 0), handleOut: CGPoint(x: 20, y: 0))
        let path = BezierPathModel(anchors: [PathAnchor(point: CGPoint(x: -100, y: 0)), anchor, PathAnchor(point: CGPoint(x: 100, y: 0))], isClosed: false)
        let moved = PathEditModel.moveHandle(PathHandleID(anchorID: anchor.id, kind: .handleOut), to: CGPoint(x: 10, y: 30), in: path, mode: .mirrored)
        let updated = moved.anchors.first { $0.id == anchor.id }!
        #expect(updated.handleOut == CGPoint(x: 10, y: 30))
        #expect(updated.handleIn == CGPoint(x: -10, y: -30))
    }

    @Test("moveHandle(.free) leaves the opposite handle untouched")
    func moveHandleFree() {
        let anchor = PathAnchor(point: CGPoint(x: 0, y: 0), handleIn: CGPoint(x: -20, y: 0), handleOut: CGPoint(x: 20, y: 0))
        let path = BezierPathModel(anchors: [PathAnchor(point: CGPoint(x: -100, y: 0)), anchor, PathAnchor(point: CGPoint(x: 100, y: 0))], isClosed: false)
        let moved = PathEditModel.moveHandle(PathHandleID(anchorID: anchor.id, kind: .handleOut), to: CGPoint(x: 10, y: 30), in: path, mode: .free)
        let updated = moved.anchors.first { $0.id == anchor.id }!
        #expect(updated.handleOut == CGPoint(x: 10, y: 30))
        #expect(updated.handleIn == CGPoint(x: -20, y: 0))
    }

    @Test("insertAnchor lands within 1pt of the tapped location (exact de Casteljau split)")
    func insertAnchorLandsOnCurve() {
        let path = Fixtures.gentleArc(radius: 500)
        let lut = ArcLengthLUT(path: path)
        let targetLength = lut.totalLength * 0.42
        let expectedPoint = lut.point(atLength: targetLength)
        let inserted = PathEditModel.insertAnchor(atLength: targetLength, in: path, lut: lut)
        #expect(inserted.anchors.count == path.anchors.count + 1)
        #expect(inserted.isValid)
        // The new anchor should be within 1pt of the tapped point, and the
        // overall curve shape is preserved (exact split, not approximate).
        let nearestInserted = inserted.anchors.min { a, b in
            hypot(a.point.x - expectedPoint.x, a.point.y - expectedPoint.y) < hypot(b.point.x - expectedPoint.x, b.point.y - expectedPoint.y)
        }!
        let distance = hypot(nearestInserted.point.x - expectedPoint.x, nearestInserted.point.y - expectedPoint.y)
        #expect(distance < 1.0)
        // Shape preservation: total length barely changes (subdivision is lossless).
        let lut2 = ArcLengthLUT(path: inserted)
        #expect(abs(lut2.totalLength - lut.totalLength) < 0.5)
    }

    @Test("insertAnchor on a closed path splits the closing segment correctly")
    func insertAnchorOnClosedPath() {
        let path = BezierPathModel.circle(center: .zero, radius: 200)
        let lut = ArcLengthLUT(path: path)
        // Target a length inside the LAST (closing) segment.
        let targetLength = lut.totalLength * 0.99
        let inserted = PathEditModel.insertAnchor(atLength: targetLength, in: path, lut: lut)
        #expect(inserted.isValid)
        #expect(inserted.anchors.count == path.anchors.count + 1)
        let lut2 = ArcLengthLUT(path: inserted)
        #expect(abs(lut2.totalLength - lut.totalLength) < 1.0)
    }

    @Test("deleteAnchor keeps the path valid, refuses to go below the minimum")
    func deleteAnchorRefusesBelowMinimum() {
        let path = BezierPathModel(anchors: [PathAnchor(point: .zero), PathAnchor(point: CGPoint(x: 100, y: 0)), PathAnchor(point: CGPoint(x: 200, y: 0))], isClosed: false)
        let afterOneDelete = PathEditModel.deleteAnchor(path.anchors[0].id, in: path)
        #expect(afterOneDelete != nil)
        #expect(afterOneDelete!.anchors.count == 2)

        let twoAnchorPath = BezierPathModel(anchors: [PathAnchor(point: .zero), PathAnchor(point: CGPoint(x: 100, y: 0))], isClosed: false)
        let refused = PathEditModel.deleteAnchor(twoAnchorPath.anchors[0].id, in: twoAnchorPath)
        #expect(refused == nil)
    }

    @Test("toggleClosed refuses when the result would be invalid")
    func toggleClosedRefusesInvalid() {
        let twoAnchorPath = BezierPathModel(anchors: [PathAnchor(point: .zero), PathAnchor(point: CGPoint(x: 100, y: 0))], isClosed: false)
        #expect(PathEditModel.toggleClosed(in: twoAnchorPath) == nil)

        let threeAnchorPath = BezierPathModel(anchors: [PathAnchor(point: .zero), PathAnchor(point: CGPoint(x: 100, y: 0)), PathAnchor(point: CGPoint(x: 50, y: 100))], isClosed: false)
        let closed = PathEditModel.toggleClosed(in: threeAnchorPath)
        #expect(closed != nil)
        #expect(closed!.isClosed)
    }
}
