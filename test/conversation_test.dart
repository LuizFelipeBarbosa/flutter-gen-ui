import 'dart:async';

import 'package:bayhop/conversation.dart';
import 'package:bayhop/model/model_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';

void main() {
  group('GenUiSession', () {
    test('uses the transit catalog and prompt by default', () {
      late final _CapturingModelClient modelClient;
      final session = GenUiSession(
        modelClientBuilder: ({required systemPrompt}) {
          return modelClient = _CapturingModelClient(
            systemPrompt: systemPrompt,
          );
        },
      );
      addTearDown(session.dispose);

      expect(modelClient.systemPrompt, contains('Bay Area transit app'));
      expect(modelClient.systemPrompt, contains('TransitSummary'));
    });

    test('accepts a custom catalog builder and system prompt', () {
      var builtCatalog = false;
      late final _CapturingModelClient modelClient;
      final session = GenUiSession(
        catalogBuilder: () {
          builtCatalog = true;
          return BasicCatalogItems.asCatalog(
            systemPromptFragments: ['Only render compact custom widgets.'],
          );
        },
        systemPrompt: 'You are a custom GenUI assistant.',
        modelClientBuilder: ({required systemPrompt}) {
          return modelClient = _CapturingModelClient(
            systemPrompt: systemPrompt,
          );
        },
      );
      addTearDown(session.dispose);

      expect(builtCatalog, isTrue);
      expect(
        modelClient.systemPrompt,
        contains('Only render compact custom widgets.'),
      );
      expect(
        modelClient.systemPrompt,
        contains('You are a custom GenUI assistant.'),
      );
      expect(modelClient.systemPrompt, isNot(contains('Bay Area transit app')));
    });

    test('adds the current-time prefix to typed messages', () async {
      late final _CapturingModelClient modelClient;
      final session = GenUiSession(
        currentTime: () => DateTime(2026, 6, 26, 9, 5),
        modelClientBuilder: ({required systemPrompt}) {
          return modelClient = _CapturingModelClient(
            systemPrompt: systemPrompt,
          );
        },
      );
      addTearDown(session.dispose);

      unawaited(session.sendMessage(' Next trains from Embarcadero '));
      await _waitForHistoryLength(modelClient, 1);

      expect(
        modelClient.history.single.text,
        'Current time is 09:05. Request: Next trains from Embarcadero',
      );
    });

    test('adds normalized context text to typed messages', () async {
      late final _CapturingModelClient modelClient;
      final session = GenUiSession(
        currentTime: () => DateTime(2026, 6, 26, 9, 5),
        contextProvider: () => '  Nearby:   Powell St\nMode: train\t ',
        modelClientBuilder: ({required systemPrompt}) {
          return modelClient = _CapturingModelClient(
            systemPrompt: systemPrompt,
          );
        },
      );
      addTearDown(session.dispose);

      unawaited(session.sendMessage('Next trains from Embarcadero'));
      await _waitForHistoryLength(modelClient, 1);

      expect(
        modelClient.history.single.text,
        'Current time is 09:05. Context: Nearby: Powell St Mode: train. '
        'Request: Next trains from Embarcadero',
      );
    });

    test('omits blank context text from typed messages', () async {
      late final _CapturingModelClient modelClient;
      final session = GenUiSession(
        currentTime: () => DateTime(2026, 6, 26, 9, 5),
        contextProvider: () => ' \n\t ',
        modelClientBuilder: ({required systemPrompt}) {
          return modelClient = _CapturingModelClient(
            systemPrompt: systemPrompt,
          );
        },
      );
      addTearDown(session.dispose);

      unawaited(session.sendMessage('Next trains from Embarcadero'));
      await _waitForHistoryLength(modelClient, 1);

      expect(
        modelClient.history.single.text,
        'Current time is 09:05. Request: Next trains from Embarcadero',
      );
    });

    test('serializes back-to-back sends through one model stream', () async {
      late final _BlockingModelClient modelClient;
      final session = GenUiSession(
        currentTime: () => DateTime(2026, 6, 26, 9, 5),
        modelClientBuilder: ({required systemPrompt}) {
          return modelClient = _BlockingModelClient(
            systemPrompt: systemPrompt,
          );
        },
      );
      addTearDown(session.dispose);

      final firstSend = session.sendMessage('First request');
      final secondSend = session.sendMessage('Second request');

      await modelClient.waitForStartedCount(1);
      expect(modelClient.maxActiveGenerations, 1);
      expect(
        modelClient.history.map((message) => message.text),
        ['Current time is 09:05. Request: First request'],
      );

      modelClient.completeCurrent('first response');
      await firstSend;
      await modelClient.waitForStartedCount(2);

      expect(modelClient.maxActiveGenerations, 1);
      expect(
        modelClient.history.map((message) => message.text),
        [
          'Current time is 09:05. Request: First request',
          'first response',
          'Current time is 09:05. Request: Second request',
        ],
      );

      modelClient.completeCurrent('second response');
      await secondSend;
    });

    testWidgets('adds the current-time prefix to button interactions', (
      tester,
    ) async {
      late final _CapturingModelClient modelClient;
      final session = GenUiSession(
        currentTime: () => DateTime(2026, 6, 26, 21, 7),
        contextProvider: () => '  Nearby: Embarcadero\n ',
        modelClientBuilder: ({required systemPrompt}) {
          return modelClient = _CapturingModelClient(
            systemPrompt: systemPrompt,
            firstResponse: _buttonSurfaceResponse,
          );
        },
      );
      addTearDown(session.dispose);

      unawaited(session.sendMessage('Show departure controls'));
      await _pumpUntil(
        tester,
        () => session.conversationState.value.surfaces.contains('main'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Surface(surfaceContext: session.contextFor('main')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ElevatedButton));
      await _pumpUntil(tester, () => modelClient.history.length >= 3);

      final prompt = modelClient.history[2].text;
      expect(
        prompt,
        startsWith(
          'Current time is 21:07. Context: Nearby: Embarcadero. Request: ',
        ),
      );
      expect(prompt, contains('"name":"refresh_departures"'));
      expect(prompt, contains('"sourceComponentId":"root"'));
    });
  });
}

Future<void> _waitForHistoryLength(
  _CapturingModelClient modelClient,
  int length,
) async {
  for (var attempts = 0; attempts < 20; attempts++) {
    if (modelClient.history.length >= length) return;
    await Future<void>.delayed(Duration.zero);
  }

  fail('Expected at least $length model history entries.');
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition,
) async {
  for (var attempts = 0; attempts < 20; attempts++) {
    if (condition()) return;
    await tester.pump();
  }

  fail('Condition was not met before the pump limit.');
}

class _CapturingModelClient extends ModelClient {
  _CapturingModelClient({
    required super.systemPrompt,
    this.firstResponse,
  });

  final String? firstResponse;

  @override
  Stream<String> generateResponse() async* {
    if (history.length == 1 && firstResponse != null) {
      yield firstResponse!;
    }
  }

  @override
  void dispose() {}
}

class _BlockingModelClient extends ModelClient {
  _BlockingModelClient({required super.systemPrompt});

  final _startWaiters = <Completer<void>>[];
  Completer<String>? _currentResponse;
  int _startedGenerations = 0;
  int _activeGenerations = 0;
  int maxActiveGenerations = 0;

  Future<void> waitForStartedCount(int count) async {
    if (_startedGenerations >= count) return;

    final completer = Completer<void>();
    _startWaiters.add(completer);
    await completer.future;
  }

  void completeCurrent(String response) {
    final currentResponse = _currentResponse;
    if (currentResponse == null) {
      fail('No model response is waiting.');
    }

    _currentResponse = null;
    currentResponse.complete(response);
  }

  @override
  Stream<String> generateResponse() async* {
    _startedGenerations++;
    _activeGenerations++;
    if (_activeGenerations > maxActiveGenerations) {
      maxActiveGenerations = _activeGenerations;
    }
    _completeReadyStartWaiters();

    final response = Completer<String>();
    _currentResponse = response;

    try {
      final text = await response.future;
      if (text.isNotEmpty) yield text;
    } finally {
      _activeGenerations--;
    }
  }

  void _completeReadyStartWaiters() {
    for (final waiter in _startWaiters) {
      if (!waiter.isCompleted) waiter.complete();
    }
    _startWaiters.clear();
  }

  @override
  void dispose() {}
}

const _buttonSurfaceResponse =
    '''
```json
{"version":"v0.9","createSurface":{"surfaceId":"main","catalogId":"$basicCatalogId"}}
```
```json
{"version":"v0.9","updateComponents":{"surfaceId":"main","components":[{"id":"root","component":"Button","child":"label","action":{"event":{"name":"refresh_departures"}}},{"id":"label","component":"Text","text":"Refresh departures"}]}}
```
''';
