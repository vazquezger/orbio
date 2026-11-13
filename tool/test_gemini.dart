// Pure Dart script - no Flutter/dart:ui dependencies.
// Run with: dart run tool/test_gemini.dart "Paises con mas mundiales"
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  final apiKey = Platform.environment['GEMINI_API_KEY'] ??
      (args.isNotEmpty && args.first.startsWith('AIza') ? args.first : null);

  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('Error: GEMINI_API_KEY environment variable is not set.');
    stderr.writeln('Run with: GEMINI_API_KEY="\$GEMINI_API_KEY" dart run tool/test_gemini.dart');
    exit(1);
  }

  final question = args.isNotEmpty && !args.first.startsWith('AIza')
      ? args.join(' ')
      : 'Paises de Sudamerica con mas copas del mundo';

  print('=== Testing Gemini 3.8 Flash via OpenAI-compatible endpoint ===');
  print('Question: "$question"');
  print('API Key: ${apiKey.substring(0, 6)}...${apiKey.substring(apiKey.length - 4)}');

  final uri = Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
  );

  final client = HttpClient();
  final sw = Stopwatch()..start();

  try {
    final req = await client.postUrl(uri);
    req.headers.contentType = ContentType.json;
    req.headers.set('Authorization', 'Bearer $apiKey');

    final body = jsonEncode({
      'model': 'gemini-3.5-flash',
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are the geographic intelligence of Orbio. Return compact JSON only: {"summary": "...", "ordered": true, "items": [{"code": "ISO3", "badge": "5", "detail": "5 titles"}]}',
        },
        {'role': 'user', 'content': question},
      ],
    });

    req.add(utf8.encode(body));
    final res = await req.close().timeout(const Duration(seconds: 15));
    final text = await utf8.decoder.bind(res).join();
    sw.stop();

    print('\nHTTP Status: ${res.statusCode}');
    print('Latency: ${sw.elapsedMilliseconds} ms (${(sw.elapsedMilliseconds / 1000).toStringAsFixed(2)}s)');

    if (res.statusCode != 200) {
      print('Response error:\n$text');
      exit(1);
    }

    final decoded = jsonDecode(text) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>?;
    final msg = (choices?.first as Map<String, dynamic>?)?['message']
        as Map<String, dynamic>?;
    final content = msg?['content'] as String?;

    print('\nContent:');
    print(content);
  } catch (e) {
    sw.stop();
    print('\nFailed after ${sw.elapsedMilliseconds} ms: $e');
  } finally {
    client.close();
  }
}
