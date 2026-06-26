import 'package:flutter_test/flutter_test.dart';
import 'package:genui_template/catalog.dart';
import 'package:genui_template/explore/explore_catalog.dart';

void main() {
  test('buildExploreCatalog includes explorer components', () {
    final itemNames = buildExploreCatalog().items.map((item) => item.name);

    expect(itemNames, contains('ExploreSummary'));
    expect(itemNames, contains('ExplorerOptionCard'));
    expect(itemNames, contains('ExplorePlaceSearch'));
    expect(itemNames, contains('ExploreNote'));
  });

  test('transit catalog remains separate from explore catalog', () {
    final catalog = buildCatalog();
    final itemNames = catalog.items.map((item) => item.name);

    expect(itemNames, isNot(contains('ExploreSummary')));
    expect(itemNames, isNot(contains('ExplorerOptionCard')));
    expect(itemNames, contains('TransitSummary'));
  });
}
