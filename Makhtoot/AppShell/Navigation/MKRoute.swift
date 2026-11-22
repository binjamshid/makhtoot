import MKFoundation

/// Shell routes for navigation stacks, sheets and full-screen covers.
enum MKRoute: Hashable, Sendable, Identifiable {
    case browser
    case editor(MKProjectID)
    case settings
    case onboarding

    var id: Self { self }
}
