import 'package:bayhop/catalog.dart';
import 'package:bayhop/explore/explore_catalog.dart';
import 'package:bayhop/explore/explore_prompt.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('ExploreHero supports Google Places header photos', () {
    final schemaJson = exploreHeroItem.dataSchema.toJson();
    final catalogPrompt = _normalizedPrompt(
      buildExploreCatalog().systemPromptFragments.join('\n'),
    );

    expect(schemaJson, contains('placeQuery'));
    expect(exploreSystemPrompt, contains('ExploreHero.placeQuery'));
    expect(catalogPrompt, contains('ExploreHero.placeQuery'));
  });

  test('ExploreImageMosaic supports Google Places tile photos', () {
    final schemaJson = exploreImageMosaicItem.dataSchema.toJson();
    final catalogPrompt = _normalizedPrompt(
      buildExploreCatalog().systemPromptFragments.join('\n'),
    );

    expect(schemaJson, contains('placeQuery'));
    expect(exploreSystemPrompt, contains('images[].placeQuery'));
    expect(catalogPrompt, contains('ExploreImageMosaic images[].placeQuery'));
  });

  test('ExplorerOptionCard supports Google Places branch photos', () {
    final schemaJson = explorerOptionCardItem.dataSchema.toJson();
    final catalogPrompt = _normalizedPrompt(
      buildExploreCatalog().systemPromptFragments.join('\n'),
    );

    expect(schemaJson, contains('placeQuery'));
    expect(exploreSystemPrompt, contains('ExplorerOptionCard'));
    expect(exploreSystemPrompt, contains('placeQuery'));
    expect(catalogPrompt, contains('ExplorerOptionCard.placeQuery'));
  });

  test('ExplorePlaceSearch allows eligible Google Maps POI markers', () {
    final schemaJson = explorePlaceSearchItem.dataSchema.toJson();

    expect(schemaJson, contains('Google Map markers'));
    expect(exploreSystemPrompt, contains('coordinate-bearing'));
    expect(exploreSystemPrompt, contains('Do not emit custom marker schema'));
  });

  test('explore prompts prefer modular previews and no auto-save', () {
    expect(exploreSystemPrompt, contains('ExploreAdventurePlan'));
    expect(exploreSystemPrompt, contains('ExploreImageMosaic'));
    expect(exploreSystemPrompt, contains('Never auto-save'));
    expect(exploreSystemPrompt, contains('preview'));
    expect(exploreSystemPrompt, isNot(contains('https://example.com')));
  });

  test('explore prompts prefer creative bento mosaics', () {
    final systemPrompt = _normalizedPrompt(exploreSystemPrompt);
    final catalogPrompt = _normalizedPrompt(
      buildExploreCatalog().systemPromptFragments.join('\n'),
    );

    expect(systemPrompt, contains('broad visual branching'));
    expect(systemPrompt, contains('creative bento-style'));
    expect(catalogPrompt, contains('creative bento mosaics'));
    expect(catalogPrompt, contains('broad visual branching'));
  });

  test('explore prompts route exact venues through Google Places', () {
    final systemPrompt = _normalizedPrompt(exploreSystemPrompt);
    final catalogPrompt = _normalizedPrompt(
      buildExploreCatalog().systemPromptFragments.join('\n'),
    );

    expect(
      systemPrompt,
      contains('Google Places-backed ExplorePlaceSearch'),
    );
    expect(
      systemPrompt,
      contains('ExploreAdventurePlan stops with placeQuery'),
    );
    expect(systemPrompt, contains('images[].placeQuery'));
    expect(systemPrompt, contains('ExplorerOptionCard'));
    expect(systemPrompt, contains('Google photos'));
    expect(catalogPrompt, contains('Google Places-backed ExplorePlaceSearch'));
    expect(catalogPrompt, contains('Google photos'));
  });

  test('explore prompts reject stock and invented image URLs', () {
    final systemPrompt = _normalizedPrompt(exploreSystemPrompt);
    final catalogPrompt = _normalizedPrompt(
      buildExploreCatalog().systemPromptFragments.join('\n'),
    );

    expect(systemPrompt, contains('Omit imageUrl by default'));
    expect(systemPrompt, contains('Never use Unsplash'));
    expect(systemPrompt, contains('do not emit imageUrl'));
    expect(catalogPrompt, contains('omit it by default'));
    expect(catalogPrompt, contains('Never emit imageUrl for exact venues'));
    expect(catalogPrompt, contains('invented image URLs'));
  });

  test('explore examples do not include stock image URLs', () {
    final exampleText = [
      for (final item in buildExploreCatalog().items)
        for (final example in item.exampleData) example(),
      exploreSystemPrompt,
    ].join('\n');

    expect(exampleText, isNot(contains('images.unsplash.com')));
    expect(exampleText, isNot(contains('unsplash.com')));
  });
}

String _normalizedPrompt(String prompt) =>
    prompt.replaceAll(RegExp(r'\s+'), ' ').trim();
