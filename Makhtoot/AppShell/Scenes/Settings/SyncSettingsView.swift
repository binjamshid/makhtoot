import MKDesignSystem
import MKFoundation
import MKStore
import SwiftUI

struct SyncSettingsView: View {
    @Environment(\.mkTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(AppContainer.self) private var container

    @State private var entitlementState: MKEntitlementState = .free
    /// UX-5: `globalState` only ever carries `.zoneNotFound`, and even that
    /// reverts to `.idle`/`.syncing` moments later once the engine's own
    /// event flow continues ، `MKSyncEngineController.lastError` (this
    /// Wave's fix) is the one thing that persists past that, so this row
    /// mirrors it into local state rather than reading it live (the
    /// controller is an actor; its properties need `await`).
    @State private var lastSyncErrorMessage: String?

    var body: some View {
        List {
            Section {
                Toggle(isOn: Binding(
                    get: { container.isProjectSyncEnabled },
                    set: { container.setProjectSyncEnabled($0) }
                )) {
                    HStack {
                        Label(syncToggleLabel, systemImage: "icloud.and.arrow.up")
                        if !hasPremium {
                            Spacer()
                            Image(systemName: "lock.fill")
                                .foregroundStyle(theme.inkMuted)
                        }
                    }
                }
                .disabled(!hasPremium && !container.isProjectSyncEnabled)

                if !hasPremium {
                    NavigationLink {
                        PaywallView(context: .premiumFeatureTap(.cloudSync)) { dismiss() }
                    } label: {
                        Label(upgradeForSyncLabel, systemImage: "arrow.up.circle")
                            .foregroundStyle(theme.primary)
                    }
                }
            } header: {
                Text(syncSectionHeader)
            } footer: {
                Text(syncSectionFooter)
                    .mkTypeStyle(theme.typeRamp.style(for: .caption))
                    .foregroundStyle(theme.inkMuted)
            }

            // Sync status — driven by the real MKSyncStatusPublisher.
            Section {
                HStack {
                    Text(syncStatusLabel)
                        .mkTypeStyle(theme.typeRamp.style(for: .caption))
                        .foregroundStyle(theme.inkMuted)
                    Spacer()
                    Text(container.syncStatusPublisher.globalState.localizedMessage)
                        .mkTypeStyle(theme.typeRamp.style(for: .caption))
                        .foregroundStyle(theme.inkMuted)
                }

                // UX-5: a detail row for the most recent sync error, fed by
                // `MKSyncEngineController.lastError` rather than
                // `globalState` ، `globalState` reverts to `.idle`/
                // `.syncing` again as soon as the engine's own event flow
                // continues, even right after a real per-project failure
                // (materialise/conflict-resolution/upload), so it alone
                // can't hold this. Hidden entirely once there has never
                // been an error this launch.
                if let lastSyncErrorMessage {
                    HStack(alignment: .top) {
                        Text(lastSyncErrorLabel)
                            .mkTypeStyle(theme.typeRamp.style(for: .caption))
                            .foregroundStyle(theme.inkMuted)
                        Spacer()
                        Text(lastSyncErrorMessage)
                            .mkTypeStyle(theme.typeRamp.style(for: .caption))
                            .foregroundStyle(theme.destructive)
                            .multilineTextAlignment(.trailing)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .mkDefaultFont(theme)
        .navigationTitle(Text(navTitle))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            entitlementState = container.entitlementProvider.state
            lastSyncErrorMessage = await container.syncEngineController?.lastError?.localizedMessage
            for await state in await container.entitlementResolver.states() {
                entitlementState = state
            }
        }
        // Event-driven refresh (not a poll loop): `globalState` is already
        // `@Observable` and already re-renders this view on every engine
        // status change, so re-checking the actor-isolated `lastError`
        // exactly then ، rather than on a fixed interval ، keeps this row
        // current without adding a new timer.
        .onChange(of: container.syncStatusPublisher.globalState) { _, _ in
            Task { lastSyncErrorMessage = await container.syncEngineController?.lastError?.localizedMessage }
        }
    }

    private var hasPremium: Bool {
        entitlementState.grantsPremiumAccess
    }

    // MARK: - Strings (ar only ، D-100)

    private var navTitle: String { "المزامنة" }
    private var syncSectionHeader: String { "المزامنة عبر iCloud" }
    private var syncToggleLabel: String { "مزامنة المشاريع عبر iCloud" }
    private var upgradeForSyncLabel: String { "الترقية لتفعيل المزامنة" }
    private var syncSectionFooter: String {
        "المزامنة معطّلة افتراضيًا. عند تفعيلها مع توفر صلاحية بريميوم، تُزامَن مشاريعك عبر حساب iCloud الخاص بك."
    }
    private var syncStatusLabel: String { "الحالة:" }
    private var lastSyncErrorLabel: String { "آخر خطأ:" }
}
