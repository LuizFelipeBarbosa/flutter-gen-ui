import 'package:bayhop/transit/transit_catalog.dart';
import 'package:genui/genui.dart';

/// Builds the catalog of widgets the model is allowed to generate.
///
/// A [Catalog] is the model's vocabulary: each entry is a widget the model can
/// request by name. The same catalog drives both the rendered surfaces and the
/// system prompt, so the model only ever emits components this client can
/// actually build.
///
/// [BasicCatalogItems] is a ready-made set of common widgets (text, buttons,
/// lists, and so on) — enough to start without defining anything. `copyWith`
/// keeps those basics and adds your own widgets on top.
Catalog buildCatalog() =>
    BasicCatalogItems.asCatalog(
      systemPromptFragments: [transitCatalogRules],
    ).copyWith(
      newItems: [
        ...transitCatalogItems,
      ],
    );
