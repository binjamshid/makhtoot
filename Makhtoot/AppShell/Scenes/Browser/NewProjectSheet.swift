import CoreGraphics
import Foundation
import MKDesignSystem
import MKFoundation
import MKModel
import PhotosUI
import SwiftUI
import UIKit

/// Canvas presets, custom dimensions and projects sized from a photo.
struct NewProjectSheet: View {
    @Environment(\.mkTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    var onCreate: (MKCanvasSpec) -> Void
    /// P5.3: "start from a photo" ، creates the project at a canvas size
    /// derived from the picked photo's own aspect ratio, then hands the
    /// raw bytes + extension back so the caller (`ProjectBrowserView`) can
    /// carry them across to the freshly-opened editor
    /// (`AppNavigationModel.pendingBackgroundImageImport`, see that type's
    /// own doc comment for the full handoff).
    var onCreateFromPhoto: (MKCanvasSpec, Data) -> Void

    @State private var customWidthText = "1080"
    @State private var customHeightText = "1080"
    @State private var showsCustomFields = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showsPhotoPicker = false
    @State private var isIngestingPhoto = false
    @ScaledMetric(relativeTo: .body) private var cardIconSize: CGFloat = 26

    private struct Preset: Identifiable {
        let id: String
        let title: String
        let size: CGSize
        let symbol: String
    }

    private let presets: [Preset] = [
        Preset(id: "social.square", title: "مربع ١:١", size: CGSize(width: 1080, height: 1080), symbol: "square"),
        Preset(id: "social.story", title: "ستوري ٩:١٦", size: CGSize(width: 1080, height: 1920), symbol: "rectangle.portrait"),
        Preset(id: "social.post", title: "منشور ٤:٥", size: CGSize(width: 1080, height: 1350), symbol: "rectangle.portrait"),
        Preset(id: "messaging.status", title: "حالة رسائل", size: CGSize(width: 1080, height: 1920), symbol: "bubble.left"),
        Preset(id: "wallpaper.phone", title: "خلفية هاتف", size: CGSize(width: 1080, height: 2340), symbol: "iphone"),
        Preset(id: "print.a5", title: "بطاقة طباعة A5", size: CGSize(width: 1240, height: 1754), symbol: "printer"),
    ]

    private let columns = [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVGrid(columns: columns, spacing: theme.spacing.lg) {
                        ForEach(presets) { preset in
                            presetCard(preset)
                        }
                        customCard
                        photoCard
                    }
                    .padding(theme.spacing.lg)

                    if showsCustomFields {
                        customFieldsPanel
                            .padding(.horizontal, theme.spacing.lg)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation { scrollProxy.scrollTo("customFields", anchor: .top) }
                                }
                            }
                    }
                }
            }
            .background(theme.bg)
            .navigationTitle(Text(navTitle))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(cancelLabel) { dismiss() }
                }
            }
            .overlay {
                if isIngestingPhoto {
                    ProgressView()
                        .padding(theme.spacing.lg)
                        .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.radius.card, style: theme.radius.style))
                }
            }
        }
        .photosPicker(isPresented: $showsPhotoPicker, selection: $photoPickerItem, matching: .images)
        .onChange(of: photoPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await ingestPhoto(newItem)
                photoPickerItem = nil
            }
        }
    }

    private var photoCard: some View {
        Button {
            showsPhotoPicker = true
        } label: {
            VStack(spacing: theme.spacing.sm) {
                RoundedRectangle(cornerRadius: theme.radius.card, style: theme.radius.style)
                    .fill(theme.canvasBackdrop)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: cardIconSize))
                            .foregroundStyle(theme.inkMuted)
                    }
                Text(photoLabel)
                    .mkTypeStyle(theme.typeRamp.style(for: .callout))
                    .foregroundStyle(theme.ink)
                Text(photoSubtitle)
                    .mkTypeStyle(theme.typeRamp.style(for: .caption))
                    .foregroundStyle(theme.inkMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(.plain)
    }

    /// Derives a canvas size from the photo's own pixel aspect ratio
    /// (clamped so an extreme panorama/portrait photo doesn't produce a
    /// degenerate canvas), then hands the raw bytes to `onCreateFromPhoto`
    /// ، the actual project-creation/asset-store-ingest work happens
    /// downstream (`ProjectBrowserView.createProjectFromPhoto` →
    /// `EditorScene.open()` → `EditorViewModel.setBackgroundImage`), same
    /// division of responsibility `onCreate` already has with
    /// `ProjectBrowserView.createProject`.
    private func ingestPhoto(_ item: PhotosPickerItem) async {
        isIngestingPhoto = true
        defer { isIngestingPhoto = false }
        guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return }
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let canvasSize = Self.clampedCanvasSize(fromPhotoPixelSize: pixelSize)
        onCreateFromPhoto(MKCanvasSpec(size: canvasSize, presetID: "photo"), data)
    }

    /// Scales `pixelSize` to a ≈2 MP baseline (matching this sheet's own
    /// preset table, e.g. `social.square`'s 1080×1080 ≈ 1.17 MP, `wallpaper
    /// .phone`'s 1080×2340 ≈ 2.5 MP) while preserving the photo's aspect
    /// ratio, clamped to a sane minimum so a degenerate/near-zero-size
    /// decode never produces an unusable canvas.
    static func clampedCanvasSize(fromPhotoPixelSize pixelSize: CGSize, targetArea: CGFloat = 1_920 * 1_080) -> CGSize {
        guard pixelSize.width > 0, pixelSize.height > 0 else { return CGSize(width: 1080, height: 1080) }
        let currentArea = pixelSize.width * pixelSize.height
        let scale = (targetArea / currentArea).squareRoot()
        let width = max(320, (pixelSize.width * scale).rounded())
        let height = max(320, (pixelSize.height * scale).rounded())
        return CGSize(width: width, height: height)
    }

    private func presetCard(_ preset: Preset) -> some View {
        Button {
            onCreate(MKCanvasSpec(size: preset.size, presetID: preset.id))
        } label: {
            VStack(spacing: theme.spacing.sm) {
                RoundedRectangle(cornerRadius: theme.radius.card, style: theme.radius.style)
                    .fill(theme.canvasBackdrop)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        Image(systemName: preset.symbol)
                            .font(.system(size: cardIconSize))
                            .foregroundStyle(theme.inkMuted)
                    }
                Text(preset.title)
                    .mkTypeStyle(theme.typeRamp.style(for: .callout))
                    .foregroundStyle(theme.ink)
                Text(dimensionLabel(preset.size))
                    .mkTypeStyle(theme.typeRamp.style(for: .caption))
                    .foregroundStyle(theme.inkMuted)
            }
        }
        .buttonStyle(.plain)
    }

    private var customCard: some View {
        Button {
            showsCustomFields.toggle()
        } label: {
            VStack(spacing: theme.spacing.sm) {
                RoundedRectangle(cornerRadius: theme.radius.card, style: theme.radius.style)
                    .fill(theme.canvasBackdrop)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: cardIconSize))
                            .foregroundStyle(theme.inkMuted)
                    }
                Text(customLabel)
                    .mkTypeStyle(theme.typeRamp.style(for: .callout))
                    .foregroundStyle(theme.ink)
                Text(customSubtitle)
                    .mkTypeStyle(theme.typeRamp.style(for: .caption))
                    .foregroundStyle(theme.inkMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(.plain)
    }

    private var customFieldsPanel: some View {
        MKPanel(title: customLabel) {
            VStack(spacing: theme.spacing.md) {
                HStack(alignment: .bottom, spacing: theme.spacing.md) {
                    VStack(alignment: .leading, spacing: theme.spacing.xs) {
                        Text(widthLabel)
                            .mkTypeStyle(theme.typeRamp.style(for: .caption))
                            .foregroundStyle(theme.inkMuted)
                        TextField(widthPlaceholder, text: $customWidthText)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                    }
                    Text("×")
                        .foregroundStyle(theme.inkMuted)
                        .padding(.bottom, theme.spacing.xs)
                    VStack(alignment: .leading, spacing: theme.spacing.xs) {
                        Text(heightLabel)
                            .mkTypeStyle(theme.typeRamp.style(for: .caption))
                            .foregroundStyle(theme.inkMuted)
                        TextField(heightPlaceholder, text: $customHeightText)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                    }
                }
                .mkTypeStyle(theme.typeRamp.style(for: .body))

                Button(createCustomLabel) {
                    let width = max(1, Double(customWidthText) ?? 1080)
                    let height = max(1, Double(customHeightText) ?? 1080)
                    onCreate(MKCanvasSpec(size: CGSize(width: width, height: height), presetID: "custom"))
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.primary)
                .frame(maxWidth: .infinity)
            }
        }
        .id("customFields")
    }

    private func dimensionLabel(_ size: CGSize) -> String {
        let width = MKRTLUtilities.toArabicIndicDigits(String(Int(size.width)))
        let height = MKRTLUtilities.toArabicIndicDigits(String(Int(size.height)))
        return "\(width)×\(height)"
    }

    // MARK: - Strings

    private var navTitle: String {
        // Latin gloss: new project
        "مشروع جديد"
    }

    private var cancelLabel: String {
        "إلغاء"
    }

    private var customLabel: String {
        // Latin gloss: custom dimensions
        "أبعاد مخصصة"
    }

    private var customSubtitle: String {
        // Latin gloss: enter exact width and height
        "أدخل العرض والارتفاع بدقة"
    }

    private var photoLabel: String {
        // Latin gloss: start from a photo
        "ابدأ من صورة"
    }

    private var photoSubtitle: String {
        // Latin gloss: use a photo as the background
        "استخدم صورة كخلفية"
    }

    private var widthLabel: String {
        "العرض (بكسل)"
    }

    private var heightLabel: String {
        "الارتفاع (بكسل)"
    }

    private var widthPlaceholder: String {
        "١٠٨٠"
    }

    private var heightPlaceholder: String {
        "١٠٨٠"
    }

    private var createCustomLabel: String {
        // Latin gloss: create
        "إنشاء"
    }
}

#Preview {
    NewProjectSheet(onCreate: { _ in }, onCreateFromPhoto: { _, _ in })
        .environment(\.mkTheme, HibrTheme.default)
}
