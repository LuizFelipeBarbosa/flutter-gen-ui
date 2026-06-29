import 'dart:convert';

import 'package:bayhop/model/inception_model_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('streams Mercury content deltas from Inception SSE events', () async {
    late Map<String, dynamic> requestBody;
    final httpClient = MockClient((request) async {
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;

      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        'https://api.inceptionlabs.ai/v1/chat/completions',
      );
      expect(request.headers['accept'], 'text/event-stream');
      expect(request.headers['authorization'], 'Bearer test-key');

      return http.Response(
        [
          'data: ${jsonEncode(_chunk('Hello '))}',
          '',
          'data: ${jsonEncode(_chunk('Mercury'))}',
          '',
          'data: [DONE]',
          '',
        ].join('\n'),
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    });

    final client = InceptionModelClient(
      systemPrompt: 'System prompt',
      apiKey: 'test-key',
      maxTokens: 128,
      httpClient: httpClient,
    );
    addTearDown(client.dispose);

    final response = await client.sendMessage('Say hello.').join();

    expect(response, 'Hello Mercury');
    expect(requestBody['model'], 'mercury-2');
    expect(requestBody['max_tokens'], 128);
    expect(requestBody['reasoning_effort'], 'medium');
    expect(requestBody['stream'], isTrue);
    expect(requestBody['temperature'], 0.75);
    expect(requestBody['messages'], [
      {'role': 'system', 'content': 'System prompt'},
      {'role': 'user', 'content': 'Say hello.'},
    ]);
  });

  test('reports missing API key before making a request', () async {
    final client = InceptionModelClient(
      systemPrompt: 'System prompt',
      apiKey: '',
      httpClient: MockClient((_) async => http.Response('', 500)),
    );
    addTearDown(client.dispose);

    await expectLater(
      client.sendMessage('Hello'),
      emitsError(isA<InceptionConfigurationException>()),
    );
  });
}

Map<String, dynamic> _chunk(String content) => {
  'choices': [
    {
      'delta': {'content': content},
    },
  ],
};
