import Foundation
import MKModel

// Supports WS-02 packet §5 task 13 (`CommandJournal` needs to serialize
// `any MKCommand`). Not a packet-named deliverable file on its own ، kept
// beside `MKCommand.swift`/`Commands.swift` since it is purely the
// (de)serialization glue for the closed command catalog declared there.
//
// Closed-catalog dispatch: `any MKCommand` doesn't carry its concrete type
// through `Codable` automatically, so encode/decode switches on the known
// concrete types explicitly (mirrors `MKNode`'s `{"kind", "payload"}`
// pattern in `MKModel`).
public enum MKCommandCoder {
    private struct Tagged<Payload: Codable>: Codable {
        var kind: String
        var payload: Payload
    }

    private struct KindProbe: Codable { var kind: String }

    public static func encode(_ command: any MKCommand) throws -> Data {
        let encoder = JSONEncoder()
        switch command {
        case let c as MKInsertNodeCommand: return try encoder.encode(Tagged(kind: "insert", payload: c))
        case let c as MKInsertNodesCommand: return try encoder.encode(Tagged(kind: "insertNodes", payload: c))
        case let c as MKRemoveNodeCommand: return try encoder.encode(Tagged(kind: "remove", payload: c))
        case let c as MKReorderCommand: return try encoder.encode(Tagged(kind: "reorder", payload: c))
        case let c as MKTransformCommand: return try encoder.encode(Tagged(kind: "transform", payload: c))
        case let c as MKStyleCommand: return try encoder.encode(Tagged(kind: "style", payload: c))
        case let c as MKLockHideCommand: return try encoder.encode(Tagged(kind: "lockHide", payload: c))
        case let c as MKRenameCommand: return try encoder.encode(Tagged(kind: "rename", payload: c))
        case let c as MKCanvasSpecCommand: return try encoder.encode(Tagged(kind: "canvasSpec", payload: c))
        case let c as MKRestoreTopLevelNodesCommand: return try encoder.encode(Tagged(kind: "restoreTopLevel", payload: c))
        case let c as MKGroupCommand: return try encoder.encode(Tagged(kind: "group", payload: c))
        case let c as MKUngroupCommand: return try encoder.encode(Tagged(kind: "ungroup", payload: c))
        case let c as MKReplaceNodeCommand: return try encoder.encode(Tagged(kind: "replaceNode", payload: c))
        case let c as MKReplaceNodesCommand: return try encoder.encode(Tagged(kind: "replaceNodes", payload: c))
        case let c as MKBatchTransformCommand: return try encoder.encode(Tagged(kind: "batchTransform", payload: c))
        case let c as MKBatchCoreCommand: return try encoder.encode(Tagged(kind: "batchCore", payload: c))
        case let c as MKTextEditCommand: return try encoder.encode(Tagged(kind: "textEdit", payload: c))
        case let c as MKNoOpCommand: return try encoder.encode(Tagged(kind: "noOp", payload: c))
        default:
            throw MKPersistenceError.unknownCommandType(String(describing: type(of: command)))
        }
    }

    public static func decode(_ data: Data) throws -> any MKCommand {
        let decoder = JSONDecoder()
        let probe = try decoder.decode(KindProbe.self, from: data)
        switch probe.kind {
        case "insert": return try decoder.decode(Tagged<MKInsertNodeCommand>.self, from: data).payload
        case "insertNodes": return try decoder.decode(Tagged<MKInsertNodesCommand>.self, from: data).payload
        case "remove": return try decoder.decode(Tagged<MKRemoveNodeCommand>.self, from: data).payload
        case "reorder": return try decoder.decode(Tagged<MKReorderCommand>.self, from: data).payload
        case "transform": return try decoder.decode(Tagged<MKTransformCommand>.self, from: data).payload
        case "style": return try decoder.decode(Tagged<MKStyleCommand>.self, from: data).payload
        case "lockHide": return try decoder.decode(Tagged<MKLockHideCommand>.self, from: data).payload
        case "rename": return try decoder.decode(Tagged<MKRenameCommand>.self, from: data).payload
        case "canvasSpec": return try decoder.decode(Tagged<MKCanvasSpecCommand>.self, from: data).payload
        case "restoreTopLevel": return try decoder.decode(Tagged<MKRestoreTopLevelNodesCommand>.self, from: data).payload
        case "group": return try decoder.decode(Tagged<MKGroupCommand>.self, from: data).payload
        case "ungroup": return try decoder.decode(Tagged<MKUngroupCommand>.self, from: data).payload
        case "replaceNode": return try decoder.decode(Tagged<MKReplaceNodeCommand>.self, from: data).payload
        case "replaceNodes": return try decoder.decode(Tagged<MKReplaceNodesCommand>.self, from: data).payload
        case "batchTransform": return try decoder.decode(Tagged<MKBatchTransformCommand>.self, from: data).payload
        case "batchCore": return try decoder.decode(Tagged<MKBatchCoreCommand>.self, from: data).payload
        case "textEdit": return try decoder.decode(Tagged<MKTextEditCommand>.self, from: data).payload
        case "noOp": return try decoder.decode(Tagged<MKNoOpCommand>.self, from: data).payload
        default:
            throw MKPersistenceError.unknownCommandType(probe.kind)
        }
    }
}
