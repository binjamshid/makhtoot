import Foundation

/// The user's analytics consent status ، default `.neverAsked` (OFF).
/// D-125: consent is opt-in; nothing is collected before `.granted`.
/// T1: version bump downgrades to `.neverAsked` (re-consent required).
public enum MKConsentStatus: Codable, Sendable, Equatable {
    /// Initial state ، toggle has never been touched. Nothing is collected.
    case neverAsked
    /// User granted consent at the given date, for the recorded version.
    case granted(date: Date)
    /// User revoked consent at the given date (or was downgraded by a
    /// version bump). Local counters and pending batches were wiped.
    case revoked(date: Date)

    // MARK: Codable (manual ، associated values need explicit coding)

    private enum CodingKeys: String, CodingKey {
        case kind, date
    }

    private enum Kind: String, Codable {
        case neverAsked, granted, revoked
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .neverAsked: self = .neverAsked
        case .granted:
            let date = try container.decode(Date.self, forKey: .date)
            self = .granted(date: date)
        case .revoked:
            let date = try container.decode(Date.self, forKey: .date)
            self = .revoked(date: date)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .neverAsked:
            try container.encode(Kind.neverAsked, forKey: .kind)
        case .granted(let date):
            try container.encode(Kind.granted, forKey: .kind)
            try container.encode(date, forKey: .date)
        case .revoked(let date):
            try container.encode(Kind.revoked, forKey: .kind)
            try container.encode(date, forKey: .date)
        }
    }

    /// `true` only when the user has actively granted consent for the
    /// CURRENT consent version.
    public var isGranted: Bool {
        if case .granted = self { return true }
        return false
    }
}
