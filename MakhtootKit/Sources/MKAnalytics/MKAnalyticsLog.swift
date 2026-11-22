import os
import MKFoundation

/// `os.Logger` for the MKAnalytics module. No PII in log messages (T17):
/// analytics errors and status are logged at info/error level but never
/// include text content, project names, user identifiers, or font file paths.
extension MKLog {
    public static let analytics = MKLog.logger(for: "MKAnalytics")
}
