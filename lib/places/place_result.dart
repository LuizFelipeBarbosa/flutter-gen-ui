class PlaceResult {
  const PlaceResult({
    required this.id,
    required this.displayName,
    this.formattedAddress,
    this.rating,
    this.userRatingCount,
    this.priceLevel,
    this.googleMapsUri,
    this.websiteUri,
    this.phoneNumber,
    this.openNow,
    this.latitude,
    this.longitude,
    this.types = const [],
    this.photos = const [],
  });

  factory PlaceResult.fromJson(Map<String, Object?> json) {
    final displayName = _map(json['displayName']);
    final currentHours = _map(json['currentOpeningHours']);
    final regularHours = _map(json['regularOpeningHours']);
    final location = _map(json['location']);

    return PlaceResult(
      id: _placeId(json),
      displayName:
          _nullableString(displayName['text']) ??
          _nullableString(json['displayName']) ??
          'Place',
      formattedAddress: _nullableString(json['formattedAddress']),
      rating: _nullableDouble(json['rating']),
      userRatingCount: _nullableInt(json['userRatingCount']),
      priceLevel: _nullableString(json['priceLevel']),
      googleMapsUri: _nullableUri(json['googleMapsUri']),
      websiteUri: _nullableUri(json['websiteUri']),
      phoneNumber: _nullableString(json['nationalPhoneNumber']),
      openNow:
          _nullableBool(currentHours['openNow']) ??
          _nullableBool(regularHours['openNow']),
      latitude: _nullableDouble(location['latitude']),
      longitude: _nullableDouble(location['longitude']),
      types: _stringList(json['types']),
      photos: _photoList(json['photos']),
    );
  }

  final String id;
  final String displayName;
  final String? formattedAddress;
  final double? rating;
  final int? userRatingCount;
  final String? priceLevel;
  final Uri? googleMapsUri;
  final Uri? websiteUri;
  final String? phoneNumber;
  final bool? openNow;
  final double? latitude;
  final double? longitude;
  final List<String> types;
  final List<PlacePhoto> photos;

  PlaceResultCardData toCardData() => PlaceResultCardData.fromPlace(this);

  PlacePhoto? get primaryPhoto => photos.isEmpty ? null : photos.first;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      if (formattedAddress != null) 'formattedAddress': formattedAddress,
      if (rating != null) 'rating': rating,
      if (userRatingCount != null) 'userRatingCount': userRatingCount,
      if (priceLevel != null) 'priceLevel': priceLevel,
      if (googleMapsUri != null) 'googleMapsUri': googleMapsUri.toString(),
      if (websiteUri != null) 'websiteUri': websiteUri.toString(),
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (openNow != null) 'openNow': openNow,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (types.isNotEmpty) 'types': types,
      if (photos.isNotEmpty)
        'photos': [for (final photo in photos) photo.toJson()],
    };
  }
}

class PlacePhoto {
  const PlacePhoto({
    required this.name,
    this.widthPx,
    this.heightPx,
    this.authorAttributions = const [],
  });

  factory PlacePhoto.fromJson(Map<String, Object?> json) {
    return PlacePhoto(
      name: _nullableString(json['name']) ?? '',
      widthPx: _nullableInt(json['widthPx']),
      heightPx: _nullableInt(json['heightPx']),
      authorAttributions: _photoAttributionList(json['authorAttributions']),
    );
  }

  final String name;
  final int? widthPx;
  final int? heightPx;
  final List<PlacePhotoAttribution> authorAttributions;

  String? get attributionLabel {
    for (final attribution in authorAttributions) {
      final label = attribution.displayName;
      if (label != null) return label;
    }
    return null;
  }

  Map<String, Object?> toJson() {
    return {
      'name': name,
      if (widthPx != null) 'widthPx': widthPx,
      if (heightPx != null) 'heightPx': heightPx,
      if (authorAttributions.isNotEmpty)
        'authorAttributions': [
          for (final attribution in authorAttributions) attribution.toJson(),
        ],
    };
  }
}

class PlacePhotoAttribution {
  const PlacePhotoAttribution({
    this.displayName,
    this.uri,
    this.photoUri,
  });

  factory PlacePhotoAttribution.fromJson(Map<String, Object?> json) {
    return PlacePhotoAttribution(
      displayName: _nullableString(json['displayName']),
      uri: _nullableUri(json['uri']),
      photoUri: _nullableUri(json['photoUri']),
    );
  }

  final String? displayName;
  final Uri? uri;
  final Uri? photoUri;

  Map<String, Object?> toJson() {
    return {
      if (displayName != null) 'displayName': displayName,
      if (uri != null) 'uri': uri.toString(),
      if (photoUri != null) 'photoUri': photoUri.toString(),
    };
  }
}

class PlaceResultCardData {
  const PlaceResultCardData({
    required this.id,
    required this.title,
    this.subtitle,
    this.ratingLabel,
    this.priceLabel,
    this.openLabel,
    this.googleMapsUri,
    this.websiteUri,
    this.phoneNumber,
    this.photoName,
    this.photoAttributionLabel,
    this.tags = const [],
  });

  factory PlaceResultCardData.fromPlace(PlaceResult place) {
    final photo = place.primaryPhoto;

    return PlaceResultCardData(
      id: place.id,
      title: place.displayName,
      subtitle: place.formattedAddress,
      ratingLabel: _ratingLabel(place.rating, place.userRatingCount),
      priceLabel: _priceLabel(place.priceLevel),
      openLabel: switch (place.openNow) {
        true => 'Open now',
        false => 'Closed now',
        null => null,
      },
      googleMapsUri: place.googleMapsUri,
      websiteUri: place.websiteUri,
      phoneNumber: place.phoneNumber,
      photoName: photo?.name,
      photoAttributionLabel: photo?.attributionLabel,
      tags: place.types.take(3).map(_typeLabel).toList(),
    );
  }

  final String id;
  final String title;
  final String? subtitle;
  final String? ratingLabel;
  final String? priceLabel;
  final String? openLabel;
  final Uri? googleMapsUri;
  final Uri? websiteUri;
  final String? phoneNumber;
  final String? photoName;
  final String? photoAttributionLabel;
  final List<String> tags;

  List<String> get metadata {
    final labels = <String>[];
    if (ratingLabel != null) labels.add(ratingLabel!);
    if (priceLabel != null) labels.add(priceLabel!);
    if (openLabel != null) labels.add(openLabel!);
    return labels;
  }

  Map<String, Object?> toJson() {
    return {
      'kind': 'placeResultCard',
      'id': id,
      'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      if (metadata.isNotEmpty) 'metadata': metadata,
      if (tags.isNotEmpty) 'tags': tags,
      if (googleMapsUri != null) 'googleMapsUri': googleMapsUri.toString(),
      if (websiteUri != null) 'websiteUri': websiteUri.toString(),
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (photoName != null) 'photoName': photoName,
      if (photoAttributionLabel != null)
        'photoAttributionLabel': photoAttributionLabel,
    };
  }
}

class PlaceResultListData {
  const PlaceResultListData({
    required this.cards,
    this.title = 'Places',
  });

  factory PlaceResultListData.fromResults(
    Iterable<PlaceResult> results, {
    String title = 'Places',
  }) {
    return PlaceResultListData(
      title: title,
      cards: [for (final result in results) result.toCardData()],
    );
  }

  final String title;
  final List<PlaceResultCardData> cards;

  Map<String, Object?> toJson() {
    return {
      'kind': 'placeResultList',
      'title': title,
      'cards': [for (final card in cards) card.toJson()],
    };
  }
}

Map<String, Object?> _map(Object? value) {
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return const {};
}

String _placeId(Map<String, Object?> json) {
  final id = _nullableString(json['id']);
  if (id != null) return id;

  final resourceName = _nullableString(json['name']);
  if (resourceName != null && resourceName.startsWith('places/')) {
    return resourceName.substring('places/'.length);
  }

  return resourceName ?? _nullableString(json['displayName']) ?? 'place';
}

String? _nullableString(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

double? _nullableDouble(Object? value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int? _nullableInt(Object? value) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}

bool? _nullableBool(Object? value) {
  if (value is bool) return value;
  if (value is String) {
    return switch (value.toLowerCase()) {
      'true' => true,
      'false' => false,
      _ => null,
    };
  }
  return null;
}

Uri? _nullableUri(Object? value) {
  final text = _nullableString(value);
  if (text == null) return null;
  return Uri.tryParse(text);
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];

  final labels = <String>[];
  for (final item in value) {
    final label = _nullableString(item);
    if (label != null) labels.add(label);
  }
  return labels;
}

List<PlacePhoto> _photoList(Object? value) {
  if (value is! List) return const [];

  final photos = <PlacePhoto>[];
  for (final item in value) {
    if (item is! Map) continue;

    final photo = PlacePhoto.fromJson(_map(item));
    if (photo.name.isNotEmpty) photos.add(photo);
  }
  return photos;
}

List<PlacePhotoAttribution> _photoAttributionList(Object? value) {
  if (value is! List) return const [];

  final attributions = <PlacePhotoAttribution>[];
  for (final item in value) {
    if (item is Map) {
      attributions.add(PlacePhotoAttribution.fromJson(_map(item)));
    }
  }
  return attributions;
}

String? _ratingLabel(double? rating, int? userRatingCount) {
  if (rating == null) return null;

  final label = rating.toStringAsFixed(1);
  if (userRatingCount == null || userRatingCount <= 0) return label;
  return '$label ($userRatingCount)';
}

String? _priceLabel(String? priceLevel) {
  return switch (priceLevel?.toUpperCase()) {
    'PRICE_LEVEL_FREE' => 'Free',
    'PRICE_LEVEL_INEXPENSIVE' => r'$',
    'PRICE_LEVEL_MODERATE' => r'$$',
    'PRICE_LEVEL_EXPENSIVE' => r'$$$',
    'PRICE_LEVEL_VERY_EXPENSIVE' => r'$$$$',
    _ => null,
  };
}

String _typeLabel(String type) {
  final words = type
      .split('_')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}');
  return words.join(' ');
}
