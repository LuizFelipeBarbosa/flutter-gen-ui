import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genui_template/conversation.dart';
import 'package:genui_template/model/model_client.dart';

void main() {
  group('GenUiSession', () {
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

      session.sendMessage(' Next trains from Embarcadero ');
      await _waitForHistoryLength(modelClient, 1);

      expect(
        modelClient.history.single.text,
        'Current time is 09:05. Request: Next trains from Embarcadero',
      );
    });

    testWidgets('adds the current-time prefix to button interactions', (
      tester,
    ) async {
      late final _CapturingModelClient modelClient;
      final session = GenUiSession(
        currentTime: () => DateTime(2026, 6, 26, 21, 7),
        modelClientBuilder: ({required systemPrompt}) {
          return modelClient = _CapturingModelClient(
            systemPrompt: systemPrompt,
            firstResponse: _buttonSurfaceResponse,
          );
        },
      );
      addTearDown(session.dispose);

      session.sendMessage('Show departure controls');
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
      expect(prompt, startsWith('Current time is 21:07. Request: '));
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

const _buttonSurfaceResponse =
    '''
```json
{"version":"v0.9","createSurface":{"surfaceId":"main","catalogId":"$basicCatalogId"}}
```
```json
{"version":"v0.9","updateComponents":{"surfaceId":"main","components":[{"id":"root","component":"Button","child":"label","action":{"event":{"name":"refresh_departures"}}},{"id":"label","component":"Text","text":"Refresh departures"}]}}
```
''';
