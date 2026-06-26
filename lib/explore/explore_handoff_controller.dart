import 'package:flutter/foundation.dart';

class ExploreHandoff {
  const ExploreHandoff({
    required this.id,
    required this.query,
  });

  final int id;
  final String query;
}

class ExploreHandoffController extends ValueNotifier<ExploreHandoff?> {
  ExploreHandoffController() : super(null);

  int _nextId = 1;

  void open(String query) {
    final text = query.trim();
    if (text.isEmpty) return;
    value = ExploreHandoff(id: _nextId++, query: text);
  }
}
