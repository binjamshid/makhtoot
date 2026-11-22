import Foundation
import Testing
@testable import MKFonts

/// T19 AC: exhaustive switch ، no English-only messages.
@Suite("MKFontError ، T19")
struct MKFontErrorTests {
    private static let allCases: [MKFontError] = [
        .premiumRequired,
        .unknownFont(fontID: "x"),
        .checksumMismatch,
        .offline,
        .unsupportedFormat(detected: "WOFF"),
        .corruptFile,
        .fontLocked(fontID: "x"),
        .registrationFailed(underlying: nil),
        .licenseRecordMissing(fontID: "x"),
    ]

    @Test func everyCaseHasANonNilArabicMessage() {
        for error in Self.allCases {
            let message = error.arabicUserMessage
            #expect(message != nil, "\(error) has no Arabic message")
            if let message {
                #expect(!message.isEmpty)
                // Contains at least one Arabic-script scalar.
                #expect(message.unicodeScalars.contains { (0x0600...0x06FF).contains($0.value) })
            }
        }
    }

    @Test func everyCaseHasAStableUniqueErrorCode() {
        let codes = Self.allCases.map(\.errorCode)
        #expect(Set(codes).count == codes.count)
        for code in codes { #expect(code.hasPrefix("fonts.")) }
    }

    @Test func localizedErrorForwardsToArabicMessage() {
        let error = MKFontError.checksumMismatch
        #expect((error as any LocalizedError).errorDescription == error.arabicUserMessage)
    }

    @Test func woffDetectionProducesTheExactSpecifiedString() {
        let error = MKFontError.unsupportedFormat(detected: "WOFF")
        #expect(error.arabicUserMessage == "صيغة WOFF غير مدعومة ، استخدم TTF أو OTF")
    }
}
