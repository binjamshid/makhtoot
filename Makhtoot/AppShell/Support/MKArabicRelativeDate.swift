import Foundation
import MKFoundation

/// Minimal Arabic relative-date phrasing for browser rows (WS-13 packet §5
/// T4: "modified date (Arabic relative: 'قبل ٣ أيام')"). Not a full ICU
/// pluralization implementation (Arabic has dual/plural/collective forms
/// this deliberately does not model) ، good enough for the shell's stub
/// project fixtures today. A future pass should evaluate
/// `Date.RelativeFormatStyle` with an explicit `ar` locale once its exact
/// phrasing is verified against what this app wants (e.g. "أمس" vs. "قبل
/// يوم واحد" register), rather than hand-rolling pluralization here.
enum MKArabicRelativeDate {
    static func string(from date: Date, relativeTo reference: Date = Date()) -> String {
        let seconds = max(0, reference.timeIntervalSince(date))
        let minutes = Int(seconds / 60)
        let hours = Int(seconds / 3_600)
        let days = Int(seconds / 86_400)

        if minutes < 1 {
            // Latin gloss: now
            return "الآن"
        }
        if minutes < 60 {
            return "قبل \(digits(minutes)) دقيقة"
        }
        if hours < 24 {
            return "قبل \(digits(hours)) ساعة"
        }
        if days == 1 {
            // Latin gloss: yesterday
            return "أمس"
        }
        if days < 30 {
            return "قبل \(digits(days)) أيام"
        }
        let months = max(1, days / 30)
        return "قبل \(digits(months)) شهر"
    }

    private static func digits(_ n: Int) -> String {
        MKRTLUtilities.toArabicIndicDigits(String(n))
    }
}
