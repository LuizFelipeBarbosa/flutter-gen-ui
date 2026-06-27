import 'package:flutter_test/flutter_test.dart';
import 'package:genui_template/catalog.dart';
import 'package:genui_template/prompt.dart';
import 'package:genui_template/transit/transit_catalog.dart';

void main() {
  test('buildCatalog includes transit components', () {
    final itemNames = buildCatalog().items.map((item) => item.name);

    expect(itemNames, contains('TransitSummary'));
    expect(itemNames, contains('TransitJourney'));
    expect(itemNames, contains('TransitDepartures'));
    expect(itemNames, contains('TransitLiveDepartures'));
    expect(itemNames, contains('TransitExploreBranch'));
    expect(itemNames, contains('TransitPlaceSearch'));
    expect(itemNames, contains('TransitAlert'));
    expect(itemNames, contains('TransitNote'));
  });

  test('transit instructions keep bus rides separate from walk legs', () {
    expect(transitCatalogRules, contains('line "regional-bus"'));
    expect(transitCatalogRules, contains('Walk legs are only true foot paths'));
    expect(systemPrompt, contains('Bus connections need type "ride"'));
    expect(systemPrompt, contains('bus connections as walk legs'));
    expect(systemPrompt, contains('Walk legs are only true foot paths'));
  });

  test('transit instructions allow eligible Google Places POI markers', () {
    expect(transitCatalogRules, contains('TransitPlaceSearch'));
    expect(transitCatalogRules, contains('Google Maps POI markers'));
    expect(transitCatalogRules, contains('valid'));
    expect(transitCatalogRules, contains('coordinates'));
    expect(systemPrompt, contains('TransitPlaceSearch uses Google Places'));
    expect(systemPrompt, contains('Google Map markers'));
  });

  test('TransitPlaceSearch requires a concrete search query', () {
    final requiredFields = transitPlaceSearchItem.dataSchema.required;

    expect(requiredFields, containsAll(['component', 'title', 'query']));
    expect(transitCatalogRules, contains('Always include a'));
    expect(transitCatalogRules, contains('non-empty query'));
    expect(systemPrompt, contains('TransitPlaceSearch must include'));
    expect(systemPrompt, contains('non-empty query'));
  });
}
