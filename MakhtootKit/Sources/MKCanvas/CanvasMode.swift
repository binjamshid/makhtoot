import MKFoundation

// WS-06 packet §5 task 2: "mode (browse/editText/arrange/pathEdit)".
// `.browse`/`.editText` have interaction handlers since the P4 "Canvas
// Core" slice; `.arrange` (task 15, `Arrange/MKArrangeInteractionModel
// .swift`) and `.pathEdit` (task 16, `PathText/MKPathTextInteractionModel
// .swift`) gained theirs in later passes once their upstream engines
// (`MKArrange`, `MKPathText`) shipped as complete, real modules ، both are
// now driven exactly like `.editText`, via `GestureCoordinator`'s
// mode-branching and each mode's own headless interaction model.
public enum MKCanvasMode: Sendable, Equatable {
    case browse
    case editText(nodeID: MKNodeID)
    case arrange(nodeID: MKNodeID)
    case pathEdit(nodeID: MKNodeID)

    public var isEditingText: Bool {
        if case .editText = self { return true }
        return false
    }

    /// The node id this mode is scoped to, or `nil` in `.browse`.
    public var scopedNodeID: MKNodeID? {
        switch self {
        case .browse: return nil
        case .editText(let id), .arrange(let id), .pathEdit(let id): return id
        }
    }
}
