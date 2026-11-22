#if MAKHTOOT_REFERRAL_ENABLED
import Foundation
import CryptoKit

/// Offline referral-code generation (T14, D-124). This entire file ، and
/// the whole `Referral/` folder ، compiles ONLY when
/// `MAKHTOOT_REFERRAL_ENABLED` is defined, which per D-225 (FOUNDER-
/// CONFIRMED 2026-07-17) must be set ONLY in Debug/internal build
/// configurations, never in Release. A Release build that never defines
/// this flag contains zero referral symbols ، not "disabled at runtime",
/// genuinely absent from the compiled binary (T15's Release-grep CI check
/// is the proof of that, not this `#if` alone).
public enum MKReferralCodeGenerator {
    /// Base32-ish alphabet, Crockford-style exclusions (no 0/O/1/I) so a
    /// user reading a code aloud/copying it by hand can't confuse
    /// characters (T14: "8 chars, prefix `MK-`").
    private static let alphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
    private static let prefix = "MK-"

    /// `base32(hash(installUUID + salt))`, 8 characters (T14 design).
    /// SHA-256 over `installUUID + salt`, first 40 bits (5 bytes) sliced
    /// into eight 5-bit groups ، deterministic for a given install, so the
    /// caller (`MKReferralLedger`) generates this once and persists it
    /// rather than recomputing (recomputing is also safe: same inputs
    /// always produce the same code).
    public static func code(installUUID: String, salt: String) -> String {
        let digest = SHA256.hash(data: Data((installUUID + salt).utf8))
        let bytes = Array(digest.prefix(5))
        var bitBuffer: UInt64 = 0
        for byte in bytes {
            bitBuffer = (bitBuffer << 8) | UInt64(byte)
        }
        var chars: [Character] = []
        for i in 0..<8 {
            let shift = (7 - i) * 5
            let index = Int((bitBuffer >> shift) & 0b1_1111)
            chars.append(alphabet[index % alphabet.count])
        }
        return prefix + String(chars)
    }
}
#endif
