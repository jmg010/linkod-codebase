/// System-wide marketplace categories (Facebook-style, localized).
/// Used for: marketplace filters, Sell Product (required), Admin approval detail.
class MarketplaceCategories {
  MarketplaceCategories._();

  static const List<MarketplaceCategory> all = [
    MarketplaceCategory('Clothing & Accessories', 'Biste / Gamit'),
    MarketplaceCategory('Food and Beverage', 'Pagkaon ug Ilimnon'),
    MarketplaceCategory('Household & Living', 'Gamit sa Bayay'),
    MarketplaceCategory('Health & Wellness', 'Pang-lawas'),
    MarketplaceCategory('Vehicles & Transport', 'Sakyanan'),
    MarketplaceCategory('Others', 'Iban pa'),
  ];

  static List<String> get ids => all.map((e) => e.id).toList();

  /// Label for UI: "English (Localized)" e.g. "Clothing & Accessories (Biste / Gamit)"
  static String label(String id) {
    for (final c in all) {
      if (c.id == id) return '${c.id} (${c.displayName})';
    }
    return id;
  }

  static const String healthWellnessId = 'Health & Wellness';
  /// Medicines must be strictly checked during admin approval.
  static bool get isHealthWellnessStrictCheck => true;
}

class MarketplaceCategory {
  final String id;
  final String displayName;
  const MarketplaceCategory(this.id, this.displayName);
}
