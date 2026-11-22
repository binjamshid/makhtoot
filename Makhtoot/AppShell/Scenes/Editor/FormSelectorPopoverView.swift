import CoreGraphics
import MKCanvas
import MKDesignSystem
import MKModel
import SwiftUI

/// R-8.3's form-selector popover: "a visual selector shows the letter's
/// four contextual forms rendered in the composition's font: منفصل / بادئ /
/// وسطي / نهائي (isolated/initial/medial/final), current form highlighted."
/// Bound to `EditorViewModel.presentedFormSelectorModel`
/// (`MKArrangeFormSelectorModel`, `MKCanvas`'s structural mirror of
/// `MKArrange.FormSelectorModel` ، see that file's header for why the
/// mirror exists). Renders the ACTUAL resolved glyph outlines
/// (`MKPathData`) per packet §6's "form-selector previews must render
/// actual resolved glyphs... not presentation-form characters" ، never
/// Unicode presentation-form text.
struct FormSelectorPopoverView: View {
    @Environment(\.mkTheme) private var theme
    let model: MKArrangeFormSelectorModel
    var onSelect: (MKJoiningForm) -> Void
    var onDismiss: () -> Void

    private let order: [MKJoiningForm] = [.isolated, .initial, .medial, .final]

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Text(title)
                .mkTypeStyle(theme.typeRamp.style(for: .headline))
                .foregroundStyle(theme.ink)

            HStack(spacing: theme.spacing.md) {
                ForEach(order, id: \.self) { form in
                    let option = model.options.first { $0.form == form }
                    FormOptionTile(
                        option: option, isCurrent: model.currentForm == form,
                        label: label(for: form),
                        action: { onSelect(form) }
                    )
                }
            }

            // P3.4: prev/next cyclers ALONGSIDE the grid above, within
            // Arrange Mode where `FormSelectorModel`'s machinery (a strict
            // 1:1 substitution over an already-derived `ArrangedComposition`,
            // requiring `activeOwnerNode`) already exists and works.
            // Deliberately NOT a standalone feature lifted out of Arrange
            // Mode: `FormSelectorModel.command(selecting:ownerNode:)`
            // (`MKArrange/FormSelectorModel.swift:68-119`) has no insertion
            // path, only substitution over an owner node that only exists
            // once Arrange Mode has already derived a composition and
            // entered it ، see this session's report for the full reasoning
            // on why lifting it out is not feasible.
            HStack(spacing: theme.spacing.md) {
                Button {
                    if let previous = adjacentValidForm(from: model.currentForm, step: -1) { onSelect(previous) }
                } label: {
                    Label(previousFormLabel, systemImage: "chevron.forward")
                        .labelStyle(.iconOnly)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .disabled(adjacentValidForm(from: model.currentForm, step: -1) == nil)
                .accessibilityLabel(previousFormLabel)

                Spacer(minLength: theme.spacing.sm)

                Button {
                    if let next = adjacentValidForm(from: model.currentForm, step: 1) { onSelect(next) }
                } label: {
                    Label(nextFormLabel, systemImage: "chevron.backward")
                        .labelStyle(.iconOnly)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .disabled(adjacentValidForm(from: model.currentForm, step: 1) == nil)
                .accessibilityLabel(nextFormLabel)
            }

            Button(dismissLabel, action: onDismiss)
                .buttonStyle(.bordered)
        }
        .mkFloatingBar(padding: theme.spacing.md)
    }

    /// Walks `order` from `form`, `step` positions at a time (wrapping),
    /// skipping options that are `!isValid` (the letter's joining type
    /// structurally cannot realize them, `MKFormOption.isValid`'s own doc
    /// comment) or absent from `model.options` altogether. Returns `nil`
    /// once every OTHER option has been tried and none is valid (the
    /// current form is the only valid one ، both cyclers correctly disable
    /// themselves rather than cycling back to the same form).
    private func adjacentValidForm(from form: MKJoiningForm, step: Int) -> MKJoiningForm? {
        guard let startIndex = order.firstIndex(of: form) else { return nil }
        var index = startIndex
        for _ in 0..<order.count {
            index = (index + step + order.count) % order.count
            let candidate = order[index]
            if candidate != form, model.options.first(where: { $0.form == candidate })?.isValid == true {
                return candidate
            }
        }
        return nil
    }

    private func label(for form: MKJoiningForm) -> String {
        switch form {
        case .isolated: return "منفصل"   // isolated
        case .initial: return "بادئ"     // initial
        case .medial: return "وسطي"      // medial
        case .final: return "نهائي"      // final
        }
    }

    private var title: String {
        // Latin gloss: choose the letter's form
        "اختيار شكل الحرف"
    }
    private var dismissLabel: String {
        // Latin gloss: cancel
        "إلغاء"
    }
    // UX-7: catalog-extractable accessibility labels ، feed
    // `.accessibilityLabel(_:)` directly.
    private var previousFormLabel: LocalizedStringResource {
        // Latin gloss: previous form
        "الشكل السابق"
    }
    private var nextFormLabel: LocalizedStringResource {
        // Latin gloss: next form
        "الشكل التالي"
    }
}

private struct FormOptionTile: View {
    @Environment(\.mkTheme) private var theme
    let option: MKArrangeFormOption?
    let isCurrent: Bool
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: theme.spacing.xs) {
                ZStack {
                    RoundedRectangle(cornerRadius: theme.radius.card, style: theme.radius.style)
                        .fill(isCurrent ? theme.primary.opacity(0.15) : theme.bg)
                        .frame(width: 56, height: 56)
                    if let option, let outline = option.previewOutline {
                        GlyphOutlineShape(pathData: outline, advance: option.previewAdvance)
                            .fill(theme.ink)
                            .frame(width: 36, height: 36)
                    } else {
                        Text("؟")
                            .foregroundStyle(theme.inkMuted)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radius.card, style: theme.radius.style)
                        .stroke(isCurrent ? theme.primary : Color.clear, lineWidth: 2)
                )
                Text(label)
                    .mkTypeStyle(theme.typeRamp.style(for: .caption))
                    .foregroundStyle((option?.isValid ?? false) ? theme.ink : theme.inkMuted)
            }
        }
        .buttonStyle(.plain)
        .disabled(!(option?.isValid ?? false))
        .opacity((option?.isValid ?? false) ? 1 : 0.4)
    }
}

/// Renders one `MKPathData` glyph outline into its own local box, scaled to
/// fit ، the "actual resolved glyph" preview §6 requires. `MKPathData` is
/// `MKFoundation` (already a `MKCanvas`/app-target-visible type); this
/// shape only needs `cgPath(at:)`, no font/CoreText dependency.
private struct GlyphOutlineShape: Shape {
    let pathData: MKPathData
    let advance: CGSize

    func path(in rect: CGRect) -> Path {
        let cgPath = pathData.cgPath(at: 24)
        let bounds = cgPath.boundingBoxOfPath
        guard bounds.width > 0, bounds.height > 0 else { return Path() }
        let scale = min(rect.width / bounds.width, rect.height / bounds.height)
        var transform = CGAffineTransform(translationX: -bounds.minX, y: -bounds.minY)
        transform = transform.concatenating(CGAffineTransform(scaleX: scale, y: -scale))
        transform = transform.concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY + bounds.height * scale))
        guard let transformed = cgPath.copy(using: &transform) else { return Path() }
        return Path(transformed)
    }
}
