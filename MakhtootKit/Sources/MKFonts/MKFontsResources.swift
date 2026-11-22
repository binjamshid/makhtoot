import Foundation

/// SPM's synthesized `Bundle.module` accessor is `internal` to the target,
/// so it cannot appear in a `public` API's default-argument position
/// directly (every other type in this module that wants "my own resource
/// bundle, but overridable in tests" routes through this instead).
public enum MKFontsResources {
    public static var bundle: Bundle { .module }
}
