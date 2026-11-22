import MKAssets
import MKDesignSystem
import SwiftUI

/// P3.2: the asset browser sheet ، a view over `MKAssetBrowserModel`
/// (`MakhtootKit/Sources/MKAssets/Browser/MKAssetBrowserModel.swift`), a
/// complete, already-tested backend with zero UI before this file. Ships
/// all FIVE BRIEF-locked categories (`MKAssetCategory.browserOrder`:
/// أشكال أساسية/زخارف/إطارات/حليات خطية/خلفيات زخرفية ، the model's own
/// `nameAr` is the source of truth for these titles, not re-typed here),
/// plus favorites/recents, search, and premium lock badges.
///
/// Presentation follows Pattern B (`ToolRailView.swift`'s own
/// `showFontSettings`/`showTextInsertSheet` precedent): the trigger
/// (`ToolRailView`) and presenter (this view, via `.sheet(isPresented:)`)
/// are the same view; `ToolRailView` owns `$showAssetBrowser` and passes
/// `onRequestPaywall` down so a `.premiumRequired` outcome can dismiss THIS
/// sheet before routing to the app-level paywall sheet, mirroring
/// `ProjectBrowserView.swift`'s `NewProjectSheet(onRequestPaywall:)` call
/// site exactly (same "set the local flag false, THEN call
/// `nav.presentPaywall(...)`" order ، two sheets driven by two different
/// presenters must not fight over being frontmost).
///
/// **Thumbnails (57 assets, packet risk "thumbnails for 57 assets on sheet
/// open").** Nothing renders eagerly here: each `AssetCell` below renders
/// its OWN thumbnail lazily via `.task(id:)`, which SwiftUI only runs once
/// that `LazyVGrid` cell is actually materialized (i.e., scrolled into or
/// near the visible area) ، `container.assetThumbnailRenderer`
/// (`AppContainer`) is a shared actor with its own internal 256-entry LRU
/// cache, so re-opening the sheet (or scrolling back to an already-seen
/// cell) re-renders nothing. Sheet-open cost is therefore just
/// `loadMetadata()` (favorites/recents, a couple of in-memory `Set`/
/// `Array` reads) plus however many cells the FIRST screenful actually
/// shows (one category's page at a time, never all 57 categories' worth at
/// once since only one category is visible per chip selection).
struct MKAssetBrowserSheet: View {
    @Environment(\.mkTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    let viewModel: EditorViewModel
    let model: MKAssetBrowserModel
    let thumbnailRenderer: MKAssetThumbnailRenderer
    var onRequestPaywall: () -> Void

    private enum Filter: Hashable {
        case recent
        case favorites
        case category(MKAssetCategory)
    }

    @State private var selectedFilter: Filter = .category(.basicShapes)
    @State private var searchText: String = ""
    @State private var isLoadingMetadata = true

    private var currentDescriptors: [MKAssetDescriptor] {
        switch selectedFilter {
        case .recent: return model.recentDescriptors()
        case .favorites: return model.favoriteDescriptors()
        case .category(let category): return model.descriptors(in: category)
        }
    }

    private let columns = [GridItem(.adaptive(minimum: 84, maximum: 108), spacing: 12)]

    var body: some View {
        NavigationStack {
            VStack(spacing: theme.spacing.sm) {
                filterChips
                if isLoadingMetadata {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if currentDescriptors.isEmpty {
                    emptyState
                } else {
                    assetGrid
                }
            }
            .padding(.horizontal, theme.spacing.md)
            .padding(.top, theme.spacing.xs)
            .navigationTitle(titleLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(closeLabel) { dismiss() }
                }
            }
            .searchable(text: $searchText, prompt: searchPrompt)
            .onChange(of: searchText) { _, newValue in model.setSearchQuery(newValue) }
        }
        .presentationDetents([.medium, .large])
        .task {
            await model.loadMetadata()
            isLoadingMetadata = false
        }
    }

    // MARK: - Filter chips (recent/favorites + the five BRIEF categories)

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacing.xs) {
                if !model.recentDescriptors().isEmpty {
                    MKChip(title: recentLabel, isSelected: selectedFilter == .recent) {
                        selectedFilter = .recent
                    }
                }
                if !model.favoriteDescriptors().isEmpty {
                    MKChip(title: favoritesLabel, isSelected: selectedFilter == .favorites) {
                        selectedFilter = .favorites
                    }
                }
                ForEach(MKAssetCategory.browserOrder) { category in
                    MKChip(title: category.nameAr, isSelected: selectedFilter == .category(category)) {
                        selectedFilter = .category(category)
                    }
                }
            }
            .padding(.vertical, theme.spacing.xs)
        }
    }

    // MARK: - Grid

    private var assetGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: theme.spacing.sm) {
                ForEach(currentDescriptors) { descriptor in
                    AssetCell(
                        descriptor: descriptor,
                        isLocked: model.isLocked(descriptor),
                        isFavorite: model.isFavorite(descriptor.assetID),
                        thumbnailRenderer: thumbnailRenderer,
                        onSelect: { select(descriptor) },
                        onToggleFavorite: { Task { await model.toggleFavorite(descriptor.assetID) } }
                    )
                }
            }
            .padding(.vertical, theme.spacing.sm)
        }
    }

    @ScaledMetric(relativeTo: .body) private var emptyStateIconSize: CGFloat = 32

    private var emptyState: some View {
        VStack(spacing: theme.spacing.sm) {
            Spacer()
            Image(systemName: "square.dashed")
                .font(.system(size: emptyStateIconSize))
                .foregroundStyle(theme.inkMuted)
            Text(emptyStateLabel)
                .mkTypeStyle(theme.typeRamp.style(for: .footnote))
                .foregroundStyle(theme.inkMuted)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Placement

    private func select(_ descriptor: MKAssetDescriptor) {
        Task {
            let outcome = await viewModel.placeAsset(descriptor, using: model)
            switch outcome {
            case .placed, .placedPattern:
                dismiss()
            case .premiumRequired:
                onRequestPaywall()
            }
        }
    }

    // MARK: - Strings

    private var titleLabel: String {
        // Latin gloss: element library
        "مكتبة العناصر"
    }
    private var closeLabel: String {
        // Latin gloss: close
        "إغلاق"
    }
    private var searchPrompt: String {
        // Latin gloss: search elements
        "ابحث عن عنصر"
    }
    private var recentLabel: String {
        // Latin gloss: recent
        "الأخيرة"
    }
    private var favoritesLabel: String {
        // Latin gloss: favorites
        "المفضلة"
    }
    private var emptyStateLabel: String {
        // Latin gloss: no elements found
        "لا توجد عناصر"
    }
}

/// One grid cell: lazily-rendered thumbnail + Arabic name + favorite
/// toggle + (when locked) a lock badge. Tapping a LOCKED cell still calls
/// `onSelect` rather than being a dead disabled control ، the plan
/// explicitly rejects a silent grey-out; `EditorViewModel.placeAsset`'s
/// underlying `MKAssetBrowserModel.select(_:)` call returns
/// `.premiumRequired` for a locked asset, which routes straight to the
/// paywall (the paywall screen IS the "why" explanation), so the lock icon
/// here is a preview of that outcome, not a dead end.
private struct AssetCell: View {
    @Environment(\.mkTheme) private var theme
    @Environment(\.displayScale) private var displayScale

    let descriptor: MKAssetDescriptor
    let isLocked: Bool
    let isFavorite: Bool
    let thumbnailRenderer: MKAssetThumbnailRenderer
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void

    @State private var thumbnail: CGImage?

    var body: some View {
        VStack(spacing: theme.spacing.xs) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: theme.radius.card, style: theme.radius.style)
                    .fill(theme.surfaceMuted)
                if let thumbnail {
                    Image(decorative: thumbnail, scale: displayScale)
                        .resizable()
                        .scaledToFit()
                        .padding(theme.spacing.xs)
                } else {
                    ProgressView()
                }
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(.black.opacity(0.55), in: Circle())
                        .padding(4)
                }
            }
            .frame(height: 84)
            .contentShape(RoundedRectangle(cornerRadius: theme.radius.card, style: theme.radius.style))
            .onTapGesture(perform: onSelect)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(descriptor.nameAr)
            .accessibilityHint(isLocked ? lockedHint : "")

            HStack(spacing: theme.spacing.xs) {
                Text(descriptor.nameAr)
                    .mkTypeStyle(theme.typeRamp.style(for: .caption))
                    .foregroundStyle(theme.inkMuted)
                    .lineLimit(1)
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
                Button(action: onToggleFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundStyle(isFavorite ? theme.primary : theme.inkMuted)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isFavorite ? removeFavoriteLabel : addFavoriteLabel)
            }
        }
        .task(id: descriptor.assetID) {
            thumbnail = await thumbnailRenderer.thumbnail(for: descriptor, size: CGSize(width: 160, height: 160))
        }
    }

    private var lockedHint: String {
        // Latin gloss: premium element — tapping opens the subscription screen
        "عنصر مميز — يفتح النقر شاشة الاشتراك"
    }
    // UX-7: catalog-extractable accessibility labels ، feed
    // `.accessibilityLabel(_:)` directly.
    private var addFavoriteLabel: LocalizedStringResource {
        // Latin gloss: add to favorites
        "إضافة إلى المفضلة"
    }
    private var removeFavoriteLabel: LocalizedStringResource {
        // Latin gloss: remove from favorites
        "إزالة من المفضلة"
    }
}
