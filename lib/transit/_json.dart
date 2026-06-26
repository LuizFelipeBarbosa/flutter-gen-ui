typedef JsonObject = Map<String, Object?>;

JsonObject map(Object? value) {
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return const {};
}

List<JsonObject> mapList(Object? value) {
  if (value is Map) return [map(value)];
  if (value is! List) return const [];

  return [
    for (final item in value)
      if (item is Map) map(item),
  ];
}

String string(Object? value, [String fallback = '']) {
  if (value == null) return fallback;
  final text = value.toString();
  return text.isEmpty ? fallback : text;
}

String? nullableString(Object? value) {
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}

int integer(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

int? nullableInteger(Object? value) {
  if (value == null) return null;
  return integer(value);
}

bool boolean(Object? value, {required bool fallback}) {
  if (value is bool) return value;
  if (value is String) {
    return switch (value.toLowerCase()) {
      'true' => true,
      'false' => false,
      _ => fallback,
    };
  }
  return fallback;
}
