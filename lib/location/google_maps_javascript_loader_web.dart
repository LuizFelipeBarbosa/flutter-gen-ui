import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

const googleMapsJavaScriptSdkRequired = true;

Future<String?>? _loadFuture;

bool get isGoogleMapsJavaScriptSdkReady {
  return _mapsObject()?.getProperty<JSObject?>('Map'.toJS) != null;
}

Future<String?> ensureGoogleMapsJavaScriptSdkLoaded({
  required String apiKey,
}) {
  if (isGoogleMapsJavaScriptSdkReady) return Future.value();

  final trimmedApiKey = apiKey.trim();
  if (trimmedApiKey.isEmpty) {
    return Future.value('Add GOOGLE_MAPS_API_KEY to your local run config.');
  }

  return _loadFuture ??= _loadGoogleMapsJavaScript(trimmedApiKey);
}

Future<String?> _loadGoogleMapsJavaScript(String apiKey) async {
  if (_hasGoogleMapsScriptTag()) {
    return _waitForGoogleMapsJavaScript();
  }

  final completer = Completer<String?>();
  final script = web.HTMLScriptElement()
    ..async = true
    ..defer = true
    ..src = Uri.https(
      'maps.googleapis.com',
      '/maps/api/js',
      {
        'key': apiKey,
        'loading': 'async',
      },
    ).toString()
    ..setAttribute('data-bayhop-google-maps-sdk', 'true')
    ..addEventListener(
      'load',
      ((web.Event _) {
        unawaited(_completeMapsLoad(completer));
      }).toJS,
    )
    ..addEventListener(
      'error',
      ((web.Event _) {
        completer.complete(
          'Google Maps JavaScript failed to load. Check the Maps JavaScript '
          'API '
          'key and browser restrictions.',
        );
      }).toJS,
    );

  final parent =
      web.document.head ?? web.document.body ?? web.document.documentElement;
  parent?.appendChild(script);

  return completer.future.timeout(
    const Duration(seconds: 12),
    onTimeout: () {
      if (isGoogleMapsJavaScriptSdkReady) return null;
      return 'Google Maps JavaScript did not finish loading.';
    },
  );
}

Future<void> _completeMapsLoad(Completer<String?> completer) async {
  if (completer.isCompleted) return;

  final error = await _ensureMapsLibraryLoaded();
  if (!completer.isCompleted) completer.complete(error);
}

bool _hasGoogleMapsScriptTag() {
  final configuredScript = web.document.querySelector(
    'script[data-bayhop-google-maps-sdk="true"]',
  );
  if (configuredScript != null) return true;

  return web.document.querySelector(
        'script[src*="maps.googleapis.com/maps/api/js"]',
      ) !=
      null;
}

Future<String?> _waitForGoogleMapsJavaScript() async {
  for (var attempt = 0; attempt < 120; attempt++) {
    if (isGoogleMapsJavaScriptSdkReady) return null;
    if (_mapsObject()?.getProperty<JSFunction?>('importLibrary'.toJS) != null) {
      return _ensureMapsLibraryLoaded();
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  return 'Google Maps JavaScript did not finish loading.';
}

Future<String?> _ensureMapsLibraryLoaded() async {
  if (isGoogleMapsJavaScriptSdkReady) return null;

  final maps = _mapsObject();
  final importLibrary = maps?.getProperty<JSFunction?>('importLibrary'.toJS);
  if (maps == null || importLibrary == null) {
    return _waitForMapsConstructor();
  }

  try {
    final promise = maps.callMethod<JSPromise<JSAny?>>(
      'importLibrary'.toJS,
      'maps'.toJS,
    );
    await promise.toDart;
  } on Object {
    return 'Google Maps JavaScript loaded, but the Maps library failed to '
        'initialize.';
  }

  return _waitForMapsConstructor();
}

Future<String?> _waitForMapsConstructor() async {
  for (var attempt = 0; attempt < 40; attempt++) {
    if (isGoogleMapsJavaScriptSdkReady) return null;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  return 'Google Maps JavaScript loaded without Maps.';
}

JSObject? _mapsObject() {
  final google = globalContext.getProperty<JSObject?>('google'.toJS);
  if (google == null) return null;

  return google.getProperty<JSObject?>('maps'.toJS);
}
