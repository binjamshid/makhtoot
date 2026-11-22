import MKFoundation

/// Feature access for every installation. The shared engine APIs use
/// `.lifetime` to represent unlimited access. No transaction is created
/// or queried and the app never presents this value as a purchase.
struct MKUnrestrictedAppAccess: MKEntitlementProviding {
    var state: MKEntitlementState { .lifetime }
}
