import MKCanvas
import MKDesignSystem
import MKFoundation
import MKModel
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// P5.3 (Bug 2): the missing background-image entry point. `PhotosPicker`
/// ONLY (system out-of-process picker, per this session's brief: needs no
/// `NSPhotoLibraryUsageDescription`, grants no library access, triggers no
/// permission prompt) plus a `.fileImporter` for Files/iCloud Drive ،
/// deliberately never `UIImagePickerController`/raw `PHPhotoLibrary` (those
/// WOULD require the usage string this sheet adds neither of).
///
/// Presentation via `.photosPicker(isPresented:selection:matching:)`
/// (not the simpler `PhotosPicker(selection:label:)` initializer) is
/// deliberate: the simpler form opens the system picker the INSTANT its
/// label is tapped, with no interception point ، gating entitlement
/// BEFORE the picker ever appears (§12.5/D-119: photo backgrounds are
/// premium) needs a plain `Button` whose action decides paywall-vs-picker
/// first. `EditorViewModel.setBackgroundImage` gates again, independently,
/// at the command layer (this UI-level check only saves a wasted picker
/// round-trip for a free user; it is not the load-bearing gate).
struct BackgroundImageSheet: View {
    @Environment(\.mkTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(AppContainer.self) private var container
    let viewModel: EditorViewModel
    var onRequestPaywall: () -> Void

    @State private var pickerItem: PhotosPickerItem?
    @State private var showsPhotosPicker = false
    @State private var showsFileImporter = false
    @State private var isIngesting = false
    @State private var ingestErrorText: String?
    @ScaledMetric(relativeTo: .body) private var previewIconSize: CGFloat = 32

    private var isEntitled: Bool { container.entitlementProvider.isEntitled(.photoBackgrounds) }
    private var hasImage: Bool { viewModel.inspector.backgroundImageRef != nil }
    private var currentFit: MKBackgroundImageFit { viewModel.inspector.backgroundImageFitValue ?? .cover }

    var body: some View {
        NavigationStack {
            VStack(spacing: theme.spacing.lg) {
                previewArea

                Button {
                    requestPhotosPicker()
                } label: {
                    Label(hasImage ? editLabel : chooseFromPhotosLabel, systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.primary)
                .frame(minHeight: 44)

                Button {
                    guard isEntitled else { onRequestPaywall(); return }
                    showsFileImporter = true
                } label: {
                    Label(chooseFromFilesLabel, systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .frame(minHeight: 44)

                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                    HStack(spacing: theme.spacing.md) {
                        Button {
                            viewModel.toggleBackgroundImageFit(entitlement: container.entitlementProvider)
                        } label: {
                            Label(currentFit == .cover ? fitCoverLabel : fitContainLabel, systemImage: "aspectratio")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!hasImage)
                        .frame(minHeight: 44)

                        Button(role: .destructive) {
                            viewModel.removeBackgroundImage()
                        } label: {
                            Label(removeLabel, systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!hasImage)
                        .frame(minHeight: 44)
                    }
                    // §2.5: every disabled control states why.
                    if !hasImage {
                        Text(noImageExplanation)
                            .mkTypeStyle(theme.typeRamp.style(for: .caption))
                            .foregroundStyle(theme.inkMuted)
                    }
                }

                if let ingestErrorText {
                    Text(ingestErrorText)
                        .mkTypeStyle(theme.typeRamp.style(for: .caption))
                        .foregroundStyle(theme.destructive)
                }

                Spacer(minLength: 0)
            }
            .padding(theme.spacing.lg)
            .background(theme.bg)
            .navigationTitle(Text(title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(doneLabel) { dismiss() }
                }
            }
            .overlay {
                if isIngesting {
                    ProgressView()
                        .padding(theme.spacing.lg)
                        .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.radius.card, style: theme.radius.style))
                }
            }
        }
        .photosPicker(isPresented: $showsPhotosPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await ingest(photosPickerItem: newItem)
                pickerItem = nil
            }
        }
        .fileImporter(isPresented: $showsFileImporter, allowedContentTypes: [.image]) { result in
            switch result {
            case .success(let url):
                Task { await ingest(fileURL: url) }
            case .failure:
                ingestErrorText = genericFailureText
            }
        }
    }

    private func requestPhotosPicker() {
        guard isEntitled else {
            onRequestPaywall()
            return
        }
        showsPhotosPicker = true
    }

    @ViewBuilder
    private var previewArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: theme.radius.card, style: theme.radius.style)
                .fill(theme.canvasBackdrop)
            if hasImage {
                Image(systemName: "photo.fill")
                    .font(.system(size: previewIconSize))
                    .foregroundStyle(theme.inkMuted)
            } else {
                VStack(spacing: theme.spacing.xs) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: previewIconSize))
                        .foregroundStyle(theme.inkMuted)
                    Text(noImageExplanation)
                        .mkTypeStyle(theme.typeRamp.style(for: .caption))
                        .foregroundStyle(theme.inkMuted)
                }
            }
        }
        .frame(height: 140)
    }

    // MARK: - Ingest

    /// `PhotosPickerItem.loadTransferable(type: Data.self)` decodes the
    /// asset OUT-OF-PROCESS (the `PhotosPicker` contract this session's
    /// brief documents) ، the app only ever sees already-exported bytes,
    /// never a `PHAsset`/library handle.
    private func ingest(photosPickerItem: PhotosPickerItem) async {
        isIngesting = true
        defer { isIngesting = false }
        guard let data = try? await photosPickerItem.loadTransferable(type: Data.self) else {
            ingestErrorText = genericFailureText
            return
        }
        await commitIngest(data: data)
    }

    /// `.fileImporter` hands back a security-scoped `URL` ، bytes are read
    /// via `Data(contentsOf:)` inside the access-scope bracket, exactly
    /// the documented `.fileImporter` contract (no file-timestamp API
    /// touched anywhere in this path).
    private func ingest(fileURL: URL) async {
        isIngesting = true
        defer { isIngesting = false }
        guard fileURL.startAccessingSecurityScopedResource() else {
            ingestErrorText = genericFailureText
            return
        }
        defer { fileURL.stopAccessingSecurityScopedResource() }
        guard let data = try? Data(contentsOf: fileURL) else {
            ingestErrorText = genericFailureText
            return
        }
        await commitIngest(data: data)
    }

    private func commitIngest(data: Data) async {
        let outcome = await viewModel.setBackgroundImage(data: data, entitlement: container.entitlementProvider)
        switch outcome {
        case .set:
            ingestErrorText = nil
            viewModel.refreshCanvasChrome()
        case .premiumRequired:
            onRequestPaywall()
        case .failed:
            ingestErrorText = ingestFailureText
        }
    }

    // MARK: - Strings

    private var title: String {
        // Latin gloss: background image
        "صورة الخلفية"
    }
    private var doneLabel: String { "تم" }
    private var chooseFromPhotosLabel: String {
        // Latin gloss: choose from photos
        "اختر من الصور"
    }
    private var chooseFromFilesLabel: String {
        // Latin gloss: import from files
        "استيراد من الملفات"
    }
    private var editLabel: String {
        // Latin gloss: change image
        "تغيير الصورة"
    }
    private var fitCoverLabel: String {
        // Latin gloss: fit: fill (tap to switch to contain)
        "الملاءمة: تعبئة"
    }
    private var fitContainLabel: String {
        // Latin gloss: fit: contain (tap to switch to fill)
        "الملاءمة: احتواء"
    }
    private var removeLabel: String {
        // Latin gloss: remove image
        "إزالة الصورة"
    }
    private var noImageExplanation: String {
        // Latin gloss: add an image first
        "أضف صورة أولاً لتفعيل هذه الخيارات"
    }
    private var genericFailureText: String {
        // Latin gloss: could not read this file
        "تعذّرت قراءة هذا الملف"
    }
    private var ingestFailureText: String {
        // Latin gloss: could not use this image
        "تعذّر استخدام هذه الصورة"
    }
}
