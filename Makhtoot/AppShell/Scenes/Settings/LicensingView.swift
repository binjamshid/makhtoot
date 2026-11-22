import MKAnalytics
import MKDesignSystem
import MKFonts
import MKFoundation
import SwiftUI

/// التراخيص ، Licensing screen (WS-12 T13 / OFL attribution mechanism).
///
/// Renders `MKLicensingDataSource.sections()` grouped as:
/// - الخطوط المدمجة (bundled, origin = 0)
/// - خطوط مميزة (premium downloaded, origin = 1)
/// - خطوط مستوردة (user imported, origin = 2)
///
/// Per-font row: family name, foundry, license badge.
/// Detail screen: full license text loaded lazily (async on `.task`, not
/// preloaded for the list ، T13 AC: lazy loading requirement).
///
/// This screen is a **submission blocker** ، OFL 1.1 requires the copyright
/// notice and license text to accompany the fonts [WS-12 §6/^26/^28/^30].
struct LicensingView: View {
    @Environment(\.mkTheme) private var theme
    @Environment(AppContainer.self) private var container

    @State private var sections: [MKLicensingDataSource.Section] = []
    @State private var isLoading = true

    private var dataSource: MKLicensingDataSource {
        MKLicensingDataSource(registry: container.fontRegistry)
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                licenseList
            }
        }
        .navigationTitle(Text(navTitle))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            sections = await dataSource.sections()
            isLoading = false
        }
    }

    @ViewBuilder
    private var licenseList: some View {
        List {
            let bundled  = sections.filter { $0.origin == .bundled }
            let premium  = sections.filter { $0.origin == .premiumDownloaded }
            let imported = sections.filter { $0.origin == .userImported }

            if !bundled.isEmpty {
                Section(header: Text(bundledHeader)) {
                    ForEach(bundled, id: \.fontID) { section in
                        NavigationLink {
                            LicenseFontDetailView(section: section)
                        } label: {
                            fontRow(section)
                        }
                    }
                }
            }

            if !premium.isEmpty {
                Section(header: Text(premiumHeader)) {
                    ForEach(premium, id: \.fontID) { section in
                        NavigationLink {
                            LicenseFontDetailView(section: section)
                        } label: {
                            fontRow(section)
                        }
                    }
                }
            }

            if !imported.isEmpty {
                Section(header: Text(importedHeader)) {
                    ForEach(imported, id: \.fontID) { section in
                        NavigationLink {
                            LicenseFontDetailView(section: section)
                        } label: {
                            fontRow(section)
                        }
                    }
                }
            }

            if sections.isEmpty {
                Text(nothingToShowLabel)
                    .mkTypeStyle(theme.typeRamp.style(for: .body))
                    .foregroundStyle(theme.inkMuted)
            }
        }
        .mkDefaultFont(theme)
    }

    @ViewBuilder
    private func fontRow(_ section: MKLicensingDataSource.Section) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(section.familyName)
                .mkTypeStyle(theme.typeRamp.style(for: .body))
                .foregroundStyle(theme.ink)
            Text(section.foundryOrAuthor)
                .mkTypeStyle(theme.typeRamp.style(for: .caption))
                .foregroundStyle(theme.inkMuted)
        }
    }

    // MARK: - Strings (ar only ، D-100)

    private var navTitle: String { "التراخيص" }
    private var bundledHeader: String { "الخطوط المدمجة" }
    private var premiumHeader: String { "خطوط مميزة" }
    private var importedHeader: String { "خطوط مستوردة" }
    private var nothingToShowLabel: String { "لا توجد خطوط مسجّلة." }
}
