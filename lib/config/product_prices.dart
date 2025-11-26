/// Centralized fixed product prices (app-wide)
/// Update these values to change prices everywhere in the app.
class ProductPrices {
  // Centralized fixed product prices (app-wide)
  // Prices are in Philippine Peso (₱)

  // Gallon pricing — granular for refill vs new-container purchases.
  // Both round and slim containers use the same prices per the new rules.
  static const double gallonRefill = 25.0; // ₱25.00 refill only
  static const double gallonWithContainer = 150.0; // ₱150.00 with new container

  // Bottled water pricing by size (string keys are normalized to lower-case)
  static const Map<String, double> bottledSizes = {
    '350ml': 8.0,
    '500ml': 10.0,
    '1l': 18.0,
    '1.5l': 22.0,
    '5l': 50.0,
  };

  /// Get a price for a product type. The optional [options] map may include
  /// keys to select size or behavior:
  /// - For `gallon` pass: {'refill': 'refill_only'|'with_container'} (container type is ignored for price)
  /// - For `bottled` pass: {'size': '350ml'|'500ml'|'1l'|'1.5l'|'5l'}
  /// The method keeps the old single-arg behavior for compatibility.
  static double getPrice(String type, [Map<String, dynamic>? options]) {
    final t = type.toLowerCase();
    if (t == 'gallon') {
      final refillOpt = (options == null) ? null : (options['refill']?.toString().toLowerCase());
      if (refillOpt == 'with_container' || refillOpt == 'withcontainer' || refillOpt == 'new_container') {
        return gallonWithContainer;
      }
      // default/refill-only
      return gallonRefill;
    }

    if (t == 'bottled') {
      final size = (options == null) ? null : options['size']?.toString().toLowerCase();
      if (size != null && bottledSizes.containsKey(size)) return bottledSizes[size]!;
      // fallback to 500ml (existing UI often used 500ml previously)
      return bottledSizes['500ml']!;
    }

    // Unknown type => fallback to a safe default (gallon refill)
    return gallonRefill;
  }

  /// Helper to get the full bottled price map (read-only view)
  static Map<String, double> allBottledPrices() => Map.unmodifiable(bottledSizes);

  /// Helper to get gallon pricing breakdown
  static Map<String, double> gallonPricing() => Map.unmodifiable({
        'refill_only': gallonRefill,
        'with_container': gallonWithContainer,
      });
}
