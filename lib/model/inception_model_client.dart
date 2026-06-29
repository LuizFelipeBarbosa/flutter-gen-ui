import 'dart:convert';

import 'package:bayhop/model/model_client.dart';
import 'package:http/http.dart' as http;

enum InceptionReasoningEffort {
  instant('instant'),
  low('low'),
  medium('medium'),
  high('high');

  const InceptionReasoningEffort(this.value);

  final String value;
}

/// A [ModelClient] backed by Inception Labs' Mercury 2 chat model.
///
/// It calls Inception's OpenAI-compatible chat completions endpoint directly
/// and streams the raw text chunks so GenUI can render A2UI as it arrives.
class InceptionModelClient extends ModelClient {
  InceptionModelClient({
    required super.systemPrompt,
    String? apiKey,
    String? model,
    InceptionReasoningEffort? reasoningEffort,
    double? temperature,
    int? maxTokens,
    http.Client? httpClient,
  }) : _model = model ?? _defaultModel,
       _reasoningEffort = reasoningEffort ?? _defaultReasoningEffort,
       _temperature = temperature ?? _defaultTemperature,
       _maxTokens = maxTokens ?? _defaultMaxTokens,
       _apiKey = apiKey ?? _defaultApiKey,
       _httpClient = httpClient ?? http.Client();

  static const String _baseUrl = 'https://api.inceptionlabs.ai/v1';
  static const String _defaultModel = 'mercury-2';
  static const InceptionReasoningEffort _defaultReasoningEffort =
      InceptionReasoningEffort.medium;
  static const double _defaultTemperature = 0.75;
  static const int _defaultMaxTokens = 8192;

  // API key supplied at build time via
  // `flutter run --dart-define=INCEPTION_API_KEY=...`.
  static const String _defaultApiKey = String.fromEnvironment(
    'INCEPTION_API_KEY',
  );

  final String _model;
  final InceptionReasoningEffort _reasoningEffort;
  final double _temperature;
  final int _maxTokens;
  final String _apiKey;
  final http.Client _httpClient;

  @override
  Stream<String> generateResponse() async* {
    final apiKey = _apiKey.trim();
    if (apiKey.isEmpty) {
      throw const InceptionConfigurationException(
        'Missing INCEPTION_API_KEY. Run Flutter with '
        '--dart-define-from-file=.env or '
        '--dart-define=INCEPTION_API_KEY=your_key_here.',
      );
    }

    final request =
        http.Request(
            'POST',
            Uri.parse('$_baseUrl/chat/completions'),
          )
          ..headers.addAll({
            'Accept': 'text/event-stream',
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          })
          ..body = jsonEncode({
            'model': _model,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              ...history.map(_toMessageJson),
            ],
            'max_tokens': _maxTokens,
            'reasoning_effort': _reasoningEffort.value,
            'stream': true,
            'temperature': _temperature,
          });

    final response = await _httpClient.send(request);
    if (response.statusCode >= 400) {
      final body = await response.stream.bytesToString();
      throw InceptionApiException(
        statusCode: response.statusCode,
        message: _errorMessageFrom(body),
        body: body,
      );
    }

    await for (final delta in _contentDeltasFrom(response.stream)) {
      yield delta;
    }
  }

  Map<String, String> _toMessageJson(ModelMessage message) => {
    'role': switch (message.role) {
      MessageRole.user => 'user',
      MessageRole.model => 'assistant',
    },
    'content': message.text,
  };

  Stream<String> _contentDeltasFrom(Stream<List<int>> bytes) async* {
    final dataLines = <String>[];

    await for (final line
        in bytes
            .transform(utf8.decoder)
            .transform(
              const LineSplitter(),
            )) {
      if (line.isEmpty) {
        final delta = _contentDeltaFrom(dataLines.join('\n'));
        dataLines.clear();
        if (delta == null) continue;
        yield delta;
        continue;
      }

      if (line.startsWith('data:')) {
        dataLines.add(line.substring('data:'.length).trimLeft());
      }
    }

    if (dataLines.isNotEmpty) {
      final delta = _contentDeltaFrom(dataLines.join('\n'));
      if (delta != null) yield delta;
    }
  }

  String? _contentDeltaFrom(String data) {
    if (data.isEmpty || data == '[DONE]') return null;

    final decoded = jsonDecode(data) as Map<String, dynamic>;
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) return null;

    final firstChoice = choices.first;
    if (firstChoice is! Map<String, dynamic>) return null;

    final delta = firstChoice['delta'];
    if (delta is! Map<String, dynamic>) return null;

    final content = delta['content'];
    if (content is! String || content.isEmpty) return null;

    return content;
  }

  String _errorMessageFrom(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message'];
        if (message is String && message.isNotEmpty) return message;
      }
    } on Object {
      // Fall through to the raw body below.
    }

    return body.isEmpty ? 'Inception API request failed.' : body;
  }

  @override
  void dispose() {
    latestResponse.dispose();
    _httpClient.close();
  }
}

class InceptionConfigurationException implements Exception {
  const InceptionConfigurationException(this.message);

  final String message;

  @override
  String toString() => 'InceptionConfigurationException: $message';
}

class InceptionApiException implements Exception {
  const InceptionApiException({
    required this.statusCode,
    required this.message,
    required this.body,
  });

  final int statusCode;
  final String message;
  final String body;

  @override
  String toString() => 'InceptionApiException ($statusCode): $message';
}
