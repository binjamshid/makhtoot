import Foundation

/// Central legal URL constants ، the single source of truth consumed by
/// both Settings (T10) and the paywall (WS-13 must show them per
/// PW-05/PW-06 of WS-10's requirements). T14 AC: grep shows no duplicated
/// URL literals; all surfaces reference these constants.
///
/// Real URLs (WS-15, 2026-07-23): served from `docs/legal/privacy.html` /
/// `docs/legal/terms.html` in this repo, deployed to
/// `binjamshid.com/makhtoot/{privacy,terms}` (nginx `try_files` resolves the
/// clean URL to the `.html` file on disk ، see `docs/impl-log/WS-15.md`).
/// Re-deploy that directory to the server if either page's content changes.
public enum MKLegalLinks {
    /// Privacy Policy URL ، required in-binary by App Store Guideline 3.1.2.
    public static let privacyPolicyURL = "https://binjamshid.com/makhtoot/privacy"

    /// Terms of Use URL ، required in-binary by App Store Guideline 3.1.2.
    public static let termsOfUseURL = "https://binjamshid.com/makhtoot/terms"

    /// Contact / support email ، shown in Support section (T12).
    public static let supportEmail = "support@binjamshid.com"
}
