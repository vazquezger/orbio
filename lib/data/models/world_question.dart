import 'dart:convert';

import 'package:flutter/foundation.dart';

/// A single country bullet returned for a [WorldQuestion].
@immutable
class AnswerItem {
  const AnswerItem({
    required this.code,
    this.badge,
    this.detail,
  });

  factory AnswerItem.fromJson(Map<String, dynamic> json) {
    final rawCode = _normalizeCode((json['code'] as String? ?? '').trim());
    final rawBadge = (json['badge'] as String?)?.trim();
    final rawDetail = (json['detail'] as String?)?.trim();
    return AnswerItem(
      code: rawCode,
      badge: (rawBadge == null || rawBadge.isEmpty) ? null : rawBadge,
      detail: (rawDetail == null || rawDetail.isEmpty) ? null : rawDetail,
    );
  }

  /// Common FIFA / colloquial 3-letter codes that small LLMs sometimes emit
  /// instead of ISO 3166-1 alpha-3.
  static const _codeAliases = <String, String>{
    'URU': 'URY',
    'GER': 'DEU',
    'ENG': 'GBR',
    'UK': 'GBR',
    'SCO': 'GBR',
    'SPA': 'ESP',
    'NED': 'NLD',
    'HOL': 'NLD',
    'SUI': 'CHE',
    'POR': 'PRT',
    'CHI': 'CHL',
    'DEN': 'DNK',
    'CRO': 'HRV',
    'GRE': 'GRC',
    'KSA': 'SAU',
    'RSA': 'ZAF',
    'UAE': 'ARE',
  };

  static String _normalizeCode(String code) {
    final upper = code.toUpperCase();
    return _codeAliases[upper] ?? upper;
  }

  /// ISO 3166-1 alpha-3 country code (`ARG`, `BRA`, `NPL`…).
  final String code;

  /// Short label shown on the map pill (number like `1.4B`, `8.849 m`, `5 🏆`,
  /// or 1-2 short words). Optional.
  final String? badge;

  /// Longer description (up to ~12 words) revealed on close zoom or tap.
  /// Optional.
  final String? detail;

  Map<String, dynamic> toJson() => {
        'code': code,
        if (badge != null) 'badge': badge,
        if (detail != null) 'detail': detail,
      };
}

/// A user question and its structured country response.
@immutable
class WorldQuestion {
  const WorldQuestion({
    required this.id,
    required this.question,
    required this.summary,
    required this.ordered,
    required this.items,
    required this.createdAt,
  });

  factory WorldQuestion.fromJson(Map<String, dynamic> json) => WorldQuestion(
        id: json['id'] as String? ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        question: json['question'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        ordered: json['ordered'] as bool? ?? false,
        items: (json['items'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(AnswerItem.fromJson)
            .where((i) => i.code.isNotEmpty)
            .toList(growable: false),
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );

  /// Parses the structured JSON returned by an LLM (tolerating ```json fences
  /// and truncated item arrays), filtering to known country [validCodes] and
  /// capping at [maxItems]. Supports both item lists and compact key-value maps.
  factory WorldQuestion.fromLlmResponse({
    required String question,
    required String rawJson,
    Set<String>? validCodes,
    DateTime? now,
    int maxItems = maxItemsDefault,
  }) {
    final decoded = _decodeOrRecover(rawJson);
    final summary = (decoded['summary'] as String? ?? '').trim();
    final ordered = decoded['ordered'] as bool? ?? false;
    final rawItems = decoded['items'];
    final seen = <String>{};
    final items = <AnswerItem>[];

    if (rawItems is List<dynamic>) {
      for (final raw in rawItems) {
        if (raw is! Map<String, dynamic>) continue;
        final item = AnswerItem.fromJson(raw);
        if (item.code.isEmpty || !seen.add(item.code)) continue;
        if (validCodes != null && !validCodes.contains(item.code)) continue;
        items.add(item);
        if (items.length >= maxItems) break;
      }
    } else if (rawItems is Map<String, dynamic>) {
      // Support ultra-compact dictionary format: {"items": {"ARG": "12 🌋", "BRA": "0"}}
      for (final entry in rawItems.entries) {
        final code = AnswerItem._normalizeCode(entry.key.trim());
        if (code.isEmpty || !seen.add(code)) continue;
        if (validCodes != null && !validCodes.contains(code)) continue;
        final badge = entry.value?.toString().trim();
        items.add(AnswerItem(
          code: code,
          badge: (badge == null || badge.isEmpty) ? null : badge,
        ));
        if (items.length >= maxItems) break;
      }
    }

    final timestamp = now ?? DateTime.now();
    return WorldQuestion(
      id: timestamp.microsecondsSinceEpoch.toString(),
      question: question.trim(),
      summary: summary.isEmpty ? question.trim() : summary,
      ordered: ordered,
      items: List.unmodifiable(items),
      createdAt: timestamp,
    );
  }

  /// Default cap for countries returned/rendered for a single question.
  /// Set to 180 so global questions can cover every country on the world map.
  static const maxItemsDefault = 180;

  final String id;
  final String question;
  final String summary;
  final bool ordered;
  final List<AnswerItem> items;
  final DateTime createdAt;

  /// Lookup map by country code.
  Map<String, AnswerItem> get itemsByCode => {
        for (final item in items) item.code: item,
      };

  /// 1-based rank of [countryCode] when [ordered] is true, else `null`.
  int? rankOf(String countryCode) {
    if (!ordered) return null;
    for (var i = 0; i < items.length; i++) {
      if (items[i].code == countryCode) return i + 1;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'summary': summary,
        'ordered': ordered,
        'items': [for (final i in items) i.toJson()],
        'created_at': createdAt.toIso8601String(),
      };

  static Map<String, dynamic> _decodeOrRecover(String raw) {
    final cleaned = _stripFences(raw);
    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Try closing `]}` or `}` at each `}` from the end backwards.
      var searchFrom = cleaned.length;
      while (searchFrom > 0) {
        final brace = cleaned.lastIndexOf('}', searchFrom - 1);
        if (brace < 0) break;
        for (final suffix in const [']}', '}']) {
          try {
            final candidate = '${cleaned.substring(0, brace + 1)}$suffix';
            final recovered = jsonDecode(candidate);
            if (recovered is Map<String, dynamic>) return recovered;
          } on FormatException {
            // Keep searching backwards.
          }
        }
        searchFrom = brace;
      }

      // Final fallback: extract any complete item objects with a regex.
      final itemMatches = RegExp(r'\{[^{}]*"code"\s*:\s*"[^"]+"[^{}]*\}')
          .allMatches(cleaned);
      final items = <Map<String, dynamic>>[];
      for (final m in itemMatches) {
        try {
          final obj = jsonDecode(m.group(0)!);
          if (obj is Map<String, dynamic>) items.add(obj);
        } on FormatException {
          // Skip malformed item.
        }
      }
      final summaryMatch =
          RegExp(r'"summary"\s*:\s*"([^"]*)"').firstMatch(cleaned);
      final orderedMatch =
          RegExp(r'"ordered"\s*:\s*(true|false)').firstMatch(cleaned);
      if (items.isNotEmpty || summaryMatch != null) {
        return {
          'summary': summaryMatch?.group(1) ?? '',
          'ordered': orderedMatch?.group(1) == 'true',
          'items': items,
        };
      }
      rethrow;
    }
    throw const FormatException('LLM response is not a JSON object');
  }

  static String _stripFences(String text) {
    final trimmed = text.trim();
    final fence = RegExp(r'^```(?:json)?\s*([\s\S]*?)\s*```$', multiLine: true);
    final match = fence.firstMatch(trimmed);
    if (match != null) return match.group(1)!.trim();
    final start = trimmed.indexOf('{');
    if (start >= 0) {
      final end = trimmed.lastIndexOf('}');
      if (end > start) {
        return trimmed.substring(start, end + 1);
      }
      return trimmed.substring(start);
    }
    return trimmed;
  }
}
