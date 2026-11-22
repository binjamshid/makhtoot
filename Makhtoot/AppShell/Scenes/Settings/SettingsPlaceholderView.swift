import Foundation
import MKDesignSystem
import MKFoundation
import MKModel
import SwiftUI

/// Device preferences, privacy, project sync and support.
struct SettingsPlaceholderView: View {
    @Environment(\.mkTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    /// `false` when embedded as a `NavigationSplitView` detail (iPad
    /// regular width ، nothing to dismiss); `true` when presented as a
    /// sheet (iPhone / compact width).
    var showsCloseButton: Bool
    /// 2026-07-29: threaded through to `GeneralSettingsView` rather than
    /// having it declare its own `@Environment(AppNavigationModel.self)`
    /// — see that view's own doc comment on `onResetOnboarding` for why.
    var onResetOnboarding: () -> Void

    #if DEBUG
    @Environment(AppContainer.self) private var container
    @State private var seedStatus: String?
    @State private var isSeeding = false
    #endif

    var body: some View {
        List {
            syncSection
            NavigationLink {
                PrivacyConsentView()
            } label: {
                Label(privacyTitle, systemImage: "hand.raised")
            }
            NavigationLink {
                GeneralSettingsView(onResetOnboarding: onResetOnboarding)
            } label: {
                Label(generalTitle, systemImage: "gearshape")
            }
            NavigationLink {
                FontManagementView()
            } label: {
                Label(fontsTitle, systemImage: "textformat")
            }
            NavigationLink {
                SupportSettingsView()
            } label: {
                Label(supportTitle, systemImage: "questionmark.circle")
            }
            legacySubscriptionSection
            #if DEBUG
            Section(header: Text("Debug")) {
                NavigationLink {
                    DesignSystemGallery()
                } label: {
                    Label(designGalleryLabel, systemImage: "paintpalette")
                }
                NavigationLink {
                    RootView()
                } label: {
                    Label(ws01RootLabel, systemImage: "square.on.square")
                }
                NavigationLink {
                    ShapingHarnessView()
                } label: {
                    Label(shapingHarnessLabel, systemImage: "textformat.abc")
                }
                NavigationLink {
                    PathTextHarnessView()
                } label: {
                    Label(pathTextHarnessLabel, systemImage: "circle.dashed")
                }
                Button {
                    seedFixtureProjects()
                } label: {
                    if isSeeding {
                        ProgressView()
                    } else {
                        Label(seedLabel, systemImage: "square.stack.3d.up")
                    }
                }
                .disabled(isSeeding)
                if let seedStatus {
                    Text(seedStatus)
                        .mkTypeStyle(theme.typeRamp.style(for: .caption))
                        .foregroundStyle(theme.inkMuted)
                }
            }
            #endif
        }
        .mkDefaultFont(theme)
        .tint(theme.primary)
        .scrollContentBackground(.hidden)
        .background(theme.bgAlt)
        .navigationTitle(Text(navTitle))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button(closeLabel) { dismiss() }
                }
            }
        }
    }

    private var legacySubscriptionSection: some View {
        Section {
            Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                Label(manageSubscriptionLabel, systemImage: "arrow.up.right.square")
            }
        } footer: {
            Text(legacySubscriptionFooter)
        }
    }

    @ViewBuilder
    private var syncSection: some View {
        NavigationLink {
            SyncSettingsView()
        } label: {
            Label(syncTitle, systemImage: "icloud.and.arrow.up")
        }
    }

    #if DEBUG
    private func seedFixtureProjects() {
        isSeeding = true
        seedStatus = nil
        Task {
            let clock = ContinuousClock()
            let start = clock.now
            for index in 1...500 {
                let ordinal = MKRTLUtilities.toArabicIndicDigits(String(index))
                _ = await container.projectLibrary.create(
                    name: "مشروع تجريبي \(ordinal)",
                    canvas: MKCanvasSpec(size: CGSize(width: 1080, height: 1080), presetID: "social.square")
                )
            }
            let elapsed = clock.now - start
            MKLog.app.info("T17 fixture seed: 500 projects in \(elapsed.description, privacy: .public)")
            seedStatus = "أُنشئ ٥٠٠ مشروع خلال \(elapsed)"
            isSeeding = false
        }
    }
    #endif

    // MARK: - Strings (ar only ، D-100)

    private var navTitle: String { "الإعدادات" }         // settings
    private var syncTitle: String { "المزامنة" }          // sync
    private var privacyTitle: String { "الخصوصية" }      // privacy
    private var generalTitle: String { "عام" }            // general
    private var fontsTitle: String { "الخطوط" }           // fonts
    private var supportTitle: String { "الدعم" }          // support
    private var closeLabel: String { "إغلاق" }            // close
    private var manageSubscriptionLabel: String { "إدارة الاشتراكات في App Store" }
    private var legacySubscriptionFooter: String {
        "إذا كان لديك اشتراك سابق في مخطوط، يمكنك إدارته أو إلغاؤه في App Store."
    }

    #if DEBUG
    private var designGalleryLabel: String { "معرض عناصر التصميم" }
    private var ws01RootLabel: String { "شاشة WS-01 الأصلية" }
    private var shapingHarnessLabel: String { "مختبر التشكيل النصي" }
    private var pathTextHarnessLabel: String { "مختبر النص على مسار" }
    private var seedLabel: String { "توليد ٥٠٠ مشروع تجريبي" }
    #endif
}

#Preview {
    NavigationStack {
        SettingsPlaceholderView(showsCloseButton: true, onResetOnboarding: {})
    }
    .environment(\.mkTheme, HibrTheme.default)
}
