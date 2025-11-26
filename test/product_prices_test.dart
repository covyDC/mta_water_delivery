import 'package:flutter_test/flutter_test.dart';
import 'package:mta_water_delivery/config/product_prices.dart';

void main() {
  test('gallon pricing: refill vs with_container', () {
    expect(ProductPrices.getPrice('gallon', {'refill': 'refill_only'}), 25.0);
    expect(ProductPrices.getPrice('gallon', {'refill': 'with_container'}), 150.0);
  });

  test('bottled sizes pricing', () {
    expect(ProductPrices.getPrice('bottled', {'size': '350ml'}), 8.0);
    expect(ProductPrices.getPrice('bottled', {'size': '500ml'}), 10.0);
    expect(ProductPrices.getPrice('bottled', {'size': '1l'}), 18.0);
    expect(ProductPrices.getPrice('bottled', {'size': '1.5l'}), 22.0);
    expect(ProductPrices.getPrice('bottled', {'size': '5l'}), 50.0);
  });

  test('bottled default size fallback', () {
    expect(ProductPrices.getPrice('bottled'), ProductPrices.getPrice('bottled', {'size': '500ml'}));
  });
}
