
/// M15 glass morphism tokens — blur, tint, and sheen for premium surfaces.
abstract final class AksharaGlass {
  /// Default backdrop blur radius (sigma).
  static const double blurSigma = 12;

  /// Lighter blur for app bars and compact strips.
  static const double blurSigmaLight = 8;

  /// Top-edge highlight opacity for glass panels.
  static const double highlightOpacity = 0.10;

  /// Subtle primary sheen strength on hero glass cards.
  static const double heroSheenOpacity = 0.06;

  /// Scrim behind modal glass overlays.
  static const double overlayScrimOpacity = 0.32;
}
