import 'package:flutter_test/flutter_test.dart';
import 'package:genui_template/catalog.dart';
import 'package:genui_template/explore/explore_catalog.dart';
import 'package:genui_template/explore/explore_prompt.dart';

void main() {
  test('buildExploreCatalog includes explorer components', () {
    final itemNames = buildExploreCatalog().items.map((item) => item.name);

    expect(itemNames, contains('ExploreHero'));
    expect(itemNames, contains('ExploreSummary'));
    expect(itemNames, contains('ExploreImageMosaic'));
    expect(itemNames, contains('ExploreAdventurePlan'));
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
    expect(itemNames, contains('TransitExploreBranch'));
    expect(itemNames, contains('TransitPlaceSearch'));
  });

  test('explore catalog does not include transit handoff components', () {
    final catalog = buildExploreCatalog();
    final itemNames = catalog.items.map((item) => item.name);

    expect(itemNames, isNot(contains('TransitExploreBranch')));
    expect(itemNames, isNot(contains('TransitPlaceSearch')));
  });

  test('ExplorePlaceSearch supports visual layouts', () {
    final schemaJson = explorePlaceSearchItem.dataSchema.toJson();

    expect(schemaJson, contains('layout'));
    expect(schemaJson, contains('carousel'));
    expect(schemaJson, contains('mosaic'));
  });

  test('explore prompts prefer modular previews and no auto-save', () {
    expect(exploreSystemPrompt, contains('ExploreAdventurePlan'));
    expect(exploreSystemPrompt, contains('ExploreImageMosaic'));
    expect(exploreSystemPrompt, contains('Never auto-save'));
    expect(exploreSystemPrompt, contains('preview'));
    expect(exploreSystemPrompt, isNot(contains('https://example.com')));
  });
}
