import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/country.dart';
import '../models/world_question.dart';

/// Supported LLM backends.
enum LlmProvider {
  gemini,
  openai,
  anthropic,
  ollama;

  String get defaultModel => switch (this) {
        LlmProvider.gemini => 'gemini-3.5-flash',
        LlmProvider.openai => 'gpt-4o-mini',
        LlmProvider.anthropic => 'claude-3-5-haiku-latest',
        LlmProvider.ollama => 'llama3.2',
      };

  String get label => switch (this) {
        LlmProvider.gemini => 'Gemini',
        LlmProvider.openai => 'ChatGPT (OpenAI)',
        LlmProvider.anthropic => 'Claude (Anthropic)',
        LlmProvider.ollama => 'Ollama (Local)',
      };

  static LlmProvider parse(String? raw) => LlmProvider.values.firstWhere(
        (p) => p.name == raw,
        orElse: () => LlmProvider.gemini,
      );
}

/// User-editable LLM configuration (provider, model, keys, Ollama URL).
@immutable
class LlmConfig {
  const LlmConfig({
    this.provider = LlmProvider.gemini,
    this.geminiKey = const String.fromEnvironment('GEMINI_API_KEY'),
    this.openaiKey = const String.fromEnvironment('OPENAI_API_KEY'),
    this.anthropicKey = const String.fromEnvironment('ANTHROPIC_API_KEY'),
    this.ollamaBaseUrl = const String.fromEnvironment(
      'OLLAMA_BASE_URL',
      defaultValue: 'http://localhost:11434',
    ),
    this.customModel = '',
    this.speechLanguage = 'es',
  });

  factory LlmConfig.fromJson(Map<String, dynamic> json) {
    const defaults = LlmConfig();
    return LlmConfig(
      provider: LlmProvider.parse(json['provider'] as String?),
      geminiKey: _nonEmpty(json['gemini_key'] as String?, defaults.geminiKey),
      openaiKey: _nonEmpty(json['openai_key'] as String?, defaults.openaiKey),
      anthropicKey: _nonEmpty(json['anthropic_key'] as String?, defaults.anthropicKey),
      ollamaBaseUrl: _nonEmpty(json['ollama_base_url'] as String?, defaults.ollamaBaseUrl),
      customModel: (json['custom_model'] as String? ?? '').trim(),
      speechLanguage: _nonEmpty(json['speech_language'] as String?, defaults.speechLanguage),
    );
  }

  final LlmProvider provider;
  final String geminiKey;
  final String openaiKey;
  final String anthropicKey;
  final String ollamaBaseUrl;
  final String customModel;

  /// Language code for voice recognition and LLM answers (`'es'` or `'en'`).
  final String speechLanguage;

  String get speechLocaleId => speechLanguage == 'en' ? 'en-US' : 'es-AR';

  String get activeModel {
    if (provider != LlmProvider.ollama) {
      return provider.defaultModel;
    }
    final custom = customModel.trim();
    return custom.isNotEmpty ? custom : provider.defaultModel;
  }

  String get activeApiKey => switch (provider) {
        LlmProvider.gemini => geminiKey.trim(),
        LlmProvider.openai => openaiKey.trim(),
        LlmProvider.anthropic => anthropicKey.trim(),
        LlmProvider.ollama => '',
      };

  bool get isConfigured =>
      provider == LlmProvider.ollama
          ? ollamaBaseUrl.trim().isNotEmpty
          : activeApiKey.isNotEmpty;

  LlmConfig copyWith({
    LlmProvider? provider,
    String? geminiKey,
    String? openaiKey,
    String? anthropicKey,
    String? ollamaBaseUrl,
    String? customModel,
    String? speechLanguage,
  }) =>
      LlmConfig(
        provider: provider ?? this.provider,
        geminiKey: geminiKey ?? this.geminiKey,
        openaiKey: openaiKey ?? this.openaiKey,
        anthropicKey: anthropicKey ?? this.anthropicKey,
        ollamaBaseUrl: ollamaBaseUrl ?? this.ollamaBaseUrl,
        customModel: customModel ?? this.customModel,
        speechLanguage: speechLanguage ?? this.speechLanguage,
      );

  Map<String, dynamic> toJson() => {
        'provider': provider.name,
        'gemini_key': geminiKey,
        'openai_key': openaiKey,
        'anthropic_key': anthropicKey,
        'ollama_base_url': ollamaBaseUrl,
        'custom_model': customModel,
        'speech_language': speechLanguage,
      };

  static String _nonEmpty(String? value, String fallback) =>
      (value != null && value.trim().isNotEmpty) ? value.trim() : fallback;
}

class LlmException implements Exception {
  const LlmException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Queries Gemini, OpenAI, Claude or a local Ollama server and returns a
/// structured [WorldQuestion].
class LlmClient {
  /// Bumped on every change to the LLM request/parsing, shown in the AI
  /// provider sheet so you can check which build is installed on the phone.
  static const buildTag = 'llm-18 · global questions & fast badges';

  LlmClient({HttpClient Function()? httpFactory})
      : _httpFactory = httpFactory ?? HttpClient.new;

  final HttpClient Function() _httpFactory;

  static String buildSystemPrompt(List<Country> countries, String languageCode) {
    final lang = languageCode.startsWith('es') ? 'Spanish (es)' : 'English (en)';
    return '''
You are the geographic intelligence of Orbio, an interactive world map.
Answer the user's question by selecting matching countries and returning ONLY a JSON object with this exact structure:
{
  "summary": "Short 1-sentence answer in $lang",
  "ordered": true,
  "items": [
    {
      "code": "ISO3",
      "badge": "short tag",
      "detail": "short description"
    }
  ]
}

Rules:
1. "code": standard ISO 3166-1 alpha-3 uppercase code (e.g. ARG, BRA, URY, DEU, ITA, FRA, ESP, GBR, USA, CHN, IND, NPL, PAK, JPN, IDN, etc.).
2. "ordered": true when the question implies a ranking or comparison (largest, highest, most populous, most titles); sort "items" from #1 to #N. Otherwise false.
3. Country scope & fast volume:
   - For global questions or large groups (e.g. "every country", "all countries", "volcanoes per country", "population of every country", "Europe", "Africa"): include ALL matching countries (or as many as relevant, up to 180). To ensure ultra-fast generation (<3s) and avoid token limits, OMIT "detail" on large lists (>15 countries); provide only "code" and "badge" (e.g. {"code": "IDN", "badge": "127 🌋"}).
   - For focused questions or top rankings (e.g. "most world cups", "top 10 economies"): return the relevant 5 to 15 countries with both "badge" and concise "detail".
4. "badge" (max 10 chars): numbers with units or emojis (e.g. "1.4B", "46M", "127 🌋", "5 🏆", "8.849 m", "17.1M km²"). If the question is a group, category or listing without specific numbers or rankings (e.g. "países de África", "países de habla hispana", "países de la UE"), set "badge": null. NEVER repeat the continent, category or country name in "badge".
5. "detail" (optional, MAX 7 WORDS): ultra-concise fact in $lang.
6. Return compact single-line JSON only.
''';
  }

  Future<WorldQuestion> ask({
    required String question,
    required LlmConfig config,
    required List<Country> countries,
    required String languageCode,
  }) async {
    if (!config.isConfigured) {
      throw LlmException('Missing API key for ${config.provider.label}');
    }
    final systemPrompt = buildSystemPrompt(countries, languageCode);
    final rawJson = await switch (config.provider) {
      LlmProvider.gemini => _askGemini(question, systemPrompt, config),
      LlmProvider.openai => _askOpenAi(question, systemPrompt, config),
      LlmProvider.anthropic => _askAnthropic(question, systemPrompt, config),
      LlmProvider.ollama => _askOllama(question, systemPrompt, config),
    };
    final validCodes = {for (final c in countries) c.code};
    return WorldQuestion.fromLlmResponse(
      question: question,
      rawJson: rawJson,
      validCodes: validCodes,
    );
  }

  Future<String> _askGemini(
    String question,
    String systemPrompt,
    LlmConfig config,
  ) async {
    final apiKey = config.activeApiKey;

    final models = [
      'gemini-3.5-flash',
      'gemini-3.8-flash',
      'gemma-4-26b-a4b-it',
    ];

    // Strategy 1: Google's official OpenAI-compatible endpoint.
    // Standard chat completions, no thinking overhead, fast (<1-2s).
    final openAiUri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
    );
    final openAiHeaders = {
      'Authorization': 'Bearer $apiKey',
    };

    for (final model in models) {
      final body = {
        'model': model,
        'temperature': 0.2,
        'response_format': {'type': 'json_object'},
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': question},
        ],
      };

      try {
        final json = await _postJson(
          openAiUri,
          body,
          headers: openAiHeaders,
          timeout: const Duration(seconds: 12),
        );
        final choices = json['choices'] as List<dynamic>?;
        final msg = (choices?.first as Map<String, dynamic>?)?['message']
            as Map<String, dynamic>?;
        final text = msg?['content'] as String?;
        if (text != null && text.trim().isNotEmpty) {
          return text;
        }
      } catch (e) {
        debugPrint('Gemini OpenAI-layer [$model] failed: $e, trying next...');
      }
    }

    // Strategy 2: Fallback to native REST generateContent endpoint
    final nativeHeaders = {
      'x-goog-api-key': apiKey,
    };
    final nativeBody = {
      'systemInstruction': {
        'parts': [
          {'text': systemPrompt},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': question},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.2,
        'responseMimeType': 'application/json',
        'responseSchema': _geminiResponseSchema,
      },
    };

    for (final model in models) {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=${Uri.encodeQueryComponent(apiKey)}',
      );
      try {
        final json = await _postJson(
          uri,
          nativeBody,
          headers: nativeHeaders,
          timeout: const Duration(seconds: 15),
        );
        final candidates = json['candidates'] as List<dynamic>?;
        final content = (candidates?.first as Map<String, dynamic>?)?['content']
            as Map<String, dynamic>?;
        final parts = content?['parts'] as List<dynamic>?;
        final text = (parts?.first as Map<String, dynamic>?)?['text'] as String?;
        if (text != null && text.isNotEmpty) {
          return text;
        }
      } catch (e) {
        debugPrint('Gemini native [$model] failed: $e');
      }
    }

    throw const LlmException('Gemini request failed on all endpoints');
  }

  Future<String> _askOpenAi(
    String question,
    String systemPrompt,
    LlmConfig config,
  ) async {
    final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
    final body = {
      'model': config.activeModel,
      'temperature': 0.2,
      'response_format': {'type': 'json_object'},
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': question},
      ],
    };
    final json = await _postJson(
      uri,
      body,
      headers: {'Authorization': 'Bearer ${config.activeApiKey}'},
    );
    final choices = json['choices'] as List<dynamic>?;
    final msg = (choices?.first as Map<String, dynamic>?)?['message']
        as Map<String, dynamic>?;
    final text = msg?['content'] as String?;
    if (text == null || text.isEmpty) {
      throw const LlmException('Empty response from OpenAI');
    }
    return text;
  }

  Future<String> _askAnthropic(
    String question,
    String systemPrompt,
    LlmConfig config,
  ) async {
    final uri = Uri.parse('https://api.anthropic.com/v1/messages');
    final body = {
      'model': config.activeModel,
      'max_tokens': 1024,
      'temperature': 0.2,
      'system': systemPrompt,
      'messages': [
        {'role': 'user', 'content': question},
      ],
    };
    final json = await _postJson(
      uri,
      body,
      headers: {
        'x-api-key': config.activeApiKey,
        'anthropic-version': '2023-06-01',
      },
    );
    final content = json['content'] as List<dynamic>?;
    final text = (content?.first as Map<String, dynamic>?)?['text'] as String?;
    if (text == null || text.isEmpty) {
      throw const LlmException('Empty response from Claude');
    }
    return text;
  }

  static const _geminiResponseSchema = {
    'type': 'OBJECT',
    'properties': {
      'summary': {'type': 'STRING'},
      'ordered': {'type': 'BOOLEAN'},
      'items': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'code': {'type': 'STRING'},
            'badge': {'type': 'STRING'},
            'detail': {'type': 'STRING'},
          },
          'required': ['code'],
        },
      },
    },
    'required': ['summary', 'ordered', 'items'],
  };

  static const _ollamaResponseSchema = {
    'type': 'object',
    'properties': {
      'summary': {'type': 'string'},
      'ordered': {'type': 'boolean'},
      'items': {
        'type': 'array',
        'maxItems': 10,
        'items': {
          'type': 'object',
          'properties': {
            'code': {'type': 'string'},
            'badge': {'type': 'string'},
            'detail': {'type': 'string'},
          },
          'required': ['code'],
        },
      },
    },
    'required': ['summary', 'ordered', 'items'],
  };

  Future<String> _askOllama(
    String question,
    String systemPrompt,
    LlmConfig config,
  ) async {
    final base = config.ollamaBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/api/chat');
    final body = {
      'model': config.activeModel,
      'stream': false,
      'keep_alive': '15m',
      'format': _ollamaResponseSchema,
      'options': {
        'temperature': 0.1,
        'num_predict': 900,
      },
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': question},
      ],
    };
    final json = await _postJson(
      uri,
      body,
      timeout: const Duration(seconds: 60),
    );
    final msg = json['message'] as Map<String, dynamic>?;
    final text = msg?['content'] as String?;
    if (text == null || text.isEmpty) {
      throw const LlmException('Empty response from Ollama');
    }
    return text;
  }

  /// Queries `GET /api/tags` on the Ollama server at [baseUrl] and returns the
  /// names of installed models (e.g. `['qwen2.5:7b', 'llama3.2:latest']`).
  Future<List<String>> fetchOllamaModels(String baseUrl) async {
    final base = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/api/tags');
    final client = _httpFactory();
    client.connectionTimeout = const Duration(seconds: 5);
    try {
      final req = await client.getUrl(uri);
      final res = await req.close().timeout(const Duration(seconds: 5));
      if (res.statusCode < 200 || res.statusCode >= 300) return const [];
      final text = await utf8.decoder.bind(res).join();
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) return const [];
      final models = decoded['models'] as List<dynamic>? ?? const [];
      return [
        for (final m in models.whereType<Map<String, dynamic>>())
          if ((m['name'] as String?)?.isNotEmpty ?? false) m['name'] as String,
      ];
    } catch (_) {
      return const [];
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _postJson(
    Uri uri,
    Map<String, dynamic> body, {
    Map<String, String> headers = const {},
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final client = _httpFactory();
    client.connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType.json;
      headers.forEach(req.headers.set);
      req.add(utf8.encode(jsonEncode(body)));
      final res = await req.close().timeout(timeout);
      final text = await utf8.decoder.bind(res).join();
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('Orbio LLM error (${uri.path}): HTTP ${res.statusCode}: $text');
        throw LlmException('HTTP ${res.statusCode}: $text');
      }
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        throw const LlmException('Invalid JSON response');
      }
      return decoded;
    } on TimeoutException {
      debugPrint('Orbio LLM error (${uri.path}): request timed out');
      throw const LlmException('Request timed out');
    } on SocketException catch (e) {
      debugPrint('Orbio LLM error (${uri.path}): network error: ${e.message}');
      throw LlmException('Network error: ${e.message}');
    } finally {
      client.close(force: true);
    }
  }
}

