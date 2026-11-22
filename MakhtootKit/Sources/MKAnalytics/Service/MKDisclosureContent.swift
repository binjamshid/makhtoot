import Foundation

/// Versioned Arabic disclosure text shown in the Privacy consent screen.
/// T6 / D-125. The text is stored here as a constant tied to
/// `consentVersion = 1`. Changing the text MUST be accompanied by bumping
/// `MKConsentRecord.currentConsentVersion` and adding a new case here ،
/// the consent manager will then downgrade existing grants to `.neverAsked`
/// and force re-consent from every user.
///
/// All claims in the text must remain literally true against D-125's
/// prohibition list (T6 AC).
public enum MKDisclosureContent {

    /// The full Arabic disclosure text for consent version 1.
    /// Displayed verbatim in `PrivacyConsentView` before the opt-in toggle.
    public static let v1: String = """
    مخطوط يجمع معلومات مجهولة الهوية وبصورة مجمّعة حول الخطوط التي تستخدمها أكثر، \
    للمساعدة في تحسين مكتبة الخطوط مستقبلاً.

    ما يُجمَع (بإذنك فقط):
    · أسماء معرّفات الخطوط التي تطبّقها على النصوص
    · عدد الاستخدامات الأسبوعية، مُقرَّبة إلى نطاق (مثلاً: ١–٤، أو ٥–٩)

    ما لا يُجمَع أبداً:
    · نصوص مشاريعك أو محتواها
    · أي معرّفات للجهاز أو المستخدم
    · طوابع زمنية دقيقة ، الأسبوع فقط
    · ملفات الخطوط

    أين تذهب البيانات:
    قاعدة بيانات CloudKit العامة، مجهولة الهوية تمامًا، دون ربط بحسابك.

    كيف توقف الجمع:
    أوقف هذا المفتاح في أي وقت ، وسيُحذف ما جُمع محليًا فورًا.
    """

    /// SHA-256 hash of `v1`. Pre-computed for test assertions.
    /// Must be recomputed if `v1` text changes (which requires a version bump).
    public static var v1Hash: String {
        MKConsentRecord.hash(disclosureText: v1)
    }
}
