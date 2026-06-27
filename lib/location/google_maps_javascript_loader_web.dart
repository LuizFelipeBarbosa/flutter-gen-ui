import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

const googleMapsJavaScriptSdkRequired = true;

Future<String?>? _loadFuture;

bool get isGoogleMapsJavaScriptSdkReady {
  final google = globalContext.getProperty<JSObject?>('google'.toJS);
  if (google == null) return false;

  final maps = google.getProperty<JSObject?>('maps'.toJS);
  if (maps == null) return false;

  return maps.getProperty<JSObject?>('Map'.toJS) != null;
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
      },
    ).toString()
    ..setAttribute('data-bayhop-google-maps-sdk', 'true')
    ..addEventListener(
      'load',
      ((web.Event _) {
        completer.complete(
          isGoogleMapsJavaScriptSdkReady
              ? null
              : 'Google Maps JavaScript loaded without Maps.',
        );
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
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  return 'Google Maps JavaScript did not finish loading.';
}
