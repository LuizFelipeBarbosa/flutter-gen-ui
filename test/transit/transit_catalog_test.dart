import 'package:flutter_test/flutter_test.dart';
import 'package:genui_template/catalog.dart';

void main() {
  test('buildCatalog includes transit components', () {
    final itemNames = buildCatalog().items.map((item) => item.name);

    expect(itemNames, contains('TransitSummary'));
    expect(itemNames, contains('TransitJourney'));
    expect(itemNames, contains('TransitDepartures'));
    expect(itemNames, contains('TransitLiveDepartures'));
    expect(itemNames, contains('TransitAlert'));
    expect(itemNames, contains('TransitNote'));
  });
}
