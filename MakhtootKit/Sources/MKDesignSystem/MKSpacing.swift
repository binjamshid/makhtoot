import CoreGraphics

/// The 4-pt spacing grid (D-126). Every layout gap/padding value in the app
/// should come from here rather than a magic number, so a future re-theme
/// (BRIEF "Product identity" ، themeable design-system layer) can rescale
/// spacing globally.
public struct MKSpacing: Sendable {
    public var xs: CGFloat = 4
    public var sm: CGFloat = 8
    public var md: CGFloat = 12
    public var lg: CGFloat = 16
    public var xl: CGFloat = 24
    public var xxl: CGFloat = 32
    public var xxxl: CGFloat = 48

    public init(
        xs: CGFloat = 4,
        sm: CGFloat = 8,
        md: CGFloat = 12,
        lg: CGFloat = 16,
        xl: CGFloat = 24,
        xxl: CGFloat = 32,
        xxxl: CGFloat = 48
    ) {
        self.xs = xs
        self.sm = sm
        self.md = md
        self.lg = lg
        self.xl = xl
        self.xxl = xxl
        self.xxxl = xxxl
    }

    /// The FOUNDATION §9 / D-126 default 4-pt grid.
    public static let `default` = MKSpacing()
}
