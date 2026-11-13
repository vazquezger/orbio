import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/country.dart';
import '../models/world_question.dart';
import '../services/llm_client.dart';

/// Shared state for the active question, question history and LLM settings.
///
/// Decouples asking a question from pointing the camera at the canvas: the
/// user can ask a question (or pick one from [history]) at any time, and both
/// Live view and Explore project [activeQuestion] onto the map.
class QuestionStore extends ChangeNotifier {
  QuestionStore({
    LlmClient? llmClient,
    Future<Directory> Function()? directoryProvider,
    LlmConfig? initialConfig,
    List<WorldQuestion>? initialHistory,
  })  : _llmClient = llmClient ?? LlmClient(),
        _dirProvider = directoryProvider ?? getApplicationDocumentsDirectory,
        _config = initialConfig ?? const LlmConfig(),
        _history = List<WorldQuestion>.of(
          initialHistory ?? defaultSeedQuestions(),
        );

  final LlmClient _llmClient;
  final Future<Directory> Function() _dirProvider;

  LlmConfig _config;
  final List<WorldQuestion> _history;
  WorldQuestion? _active;
  bool _asking = false;
  String? _error;

  LlmConfig get config => _config;
  List<WorldQuestion> get history => List.unmodifiable(_history);
  WorldQuestion? get activeQuestion => _active;
  bool get isAsking => _asking;
  String? get error => _error;

  Future<void> load() async {
    try {
      final dir = await _dirProvider();
      final cfgFile = File(p.join(dir.path, 'llm_config.json'));
      if (await cfgFile.exists()) {
        final raw = jsonDecode(await cfgFile.readAsString()) as Map<String, dynamic>;
        _config = LlmConfig.fromJson(raw);
      }
      final histFile = File(p.join(dir.path, 'question_history.json'));
      if (await histFile.exists()) {
        final list = jsonDecode(await histFile.readAsString()) as List<dynamic>;
        final loaded = list
            .whereType<Map<String, dynamic>>()
            .map(WorldQuestion.fromJson)
            .toList();
        if (loaded.isNotEmpty) {
          _history
            ..clear()
            ..addAll(loaded);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('QuestionStore.load skipped: $e');
    }
  }

  Future<void> updateConfig(LlmConfig newConfig) async {
    _config = newConfig;
    _error = null;
    notifyListeners();
    try {
      final dir = await _dirProvider();
      final cfgFile = File(p.join(dir.path, 'llm_config.json'));
      await cfgFile.writeAsString(jsonEncode(_config.toJson()));
    } catch (e) {
      debugPrint('QuestionStore.updateConfig save skipped: $e');
    }
  }

  void selectQuestion(WorldQuestion? question) {
    _active = question;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<WorldQuestion?> ask({
    required String prompt,
    required List<Country> countries,
    required String languageCode,
  }) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty || _asking) return null;
    _asking = true;
    _error = null;
    notifyListeners();
    try {
      final answered = await _llmClient.ask(
        question: trimmed,
        config: _config,
        countries: countries,
        languageCode: languageCode,
      );
      _history.removeWhere(
        (q) => q.question.toLowerCase() == trimmed.toLowerCase(),
      );
      _history.insert(0, answered);
      if (_history.length > 30) {
        _history.removeRange(30, _history.length);
      }
      _active = answered;
      await _saveHistory();
      return answered;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _asking = false;
      notifyListeners();
    }
  }

  Future<void> _saveHistory() async {
    try {
      final dir = await _dirProvider();
      final histFile = File(p.join(dir.path, 'question_history.json'));
      await histFile.writeAsString(
        jsonEncode([for (final q in _history) q.toJson()]),
      );
    } catch (e) {
      debugPrint('QuestionStore._saveHistory skipped: $e');
    }
  }

  /// Starter questions in the history so the user can test the map and zoom
  /// behavior before configuring an LLM key.
  static List<WorldQuestion> defaultSeedQuestions() => [
        WorldQuestion(
          id: 'seed-world-cup',
          question: '¿Qué países ganaron mundiales de fútbol?',
          summary: '8 países ganaron la Copa Mundial de la FIFA',
          ordered: true,
          createdAt: DateTime.utc(2026, 1, 1),
          items: const [
            AnswerItem(
              code: 'BRA',
              badge: '5 🏆',
              detail: 'Pentacampeón mundial (1958, 1962, 1970, 1994 y 2002).',
            ),
            AnswerItem(
              code: 'DEU',
              badge: '4 🏆',
              detail: 'Cuatro títulos mundiales; el último fue en 2014.',
            ),
            AnswerItem(
              code: 'ITA',
              badge: '4 🏆',
              detail: 'Tetracampeón mundial (1934, 1938, 1982 y 2006).',
            ),
            AnswerItem(
              code: 'ARG',
              badge: '3 🏆',
              detail: 'Campeón en 1978, 1986 y 2022 con Kempes, Maradona y Messi.',
            ),
            AnswerItem(
              code: 'FRA',
              badge: '2 🏆',
              detail: 'Bicampeón mundial en 1998 y 2018.',
            ),
            AnswerItem(
              code: 'URY',
              badge: '2 🏆',
              detail: 'Ganó el primer Mundial en 1930 y el Maracanazo en 1950.',
            ),
            AnswerItem(
              code: 'GBR',
              badge: '1 🏆',
              detail: 'Inglaterra fue campeón como anfitrión en 1966.',
            ),
            AnswerItem(
              code: 'ESP',
              badge: '1 🏆',
              detail: 'Campeón por primera vez en Sudáfrica 2010.',
            ),
          ],
        ),
        WorldQuestion(
          id: 'seed-mountains',
          question: 'Países con las montañas más altas',
          summary: 'Top 10 países por su cumbre de mayor altitud',
          ordered: true,
          createdAt: DateTime.utc(2026, 1, 2),
          items: const [
            AnswerItem(
              code: 'NPL',
              badge: '8.849 m',
              detail: 'Monte Everest, el punto más alto de la Tierra.',
            ),
            AnswerItem(
              code: 'CHN',
              badge: '8.849 m',
              detail: 'Comparte la cumbre del Everest en la frontera tibetana.',
            ),
            AnswerItem(
              code: 'PAK',
              badge: '8.611 m',
              detail: 'K2 en el Karakórum, la segunda montaña más alta.',
            ),
            AnswerItem(
              code: 'IND',
              badge: '8.586 m',
              detail: 'Kangchenjunga, en el Himalaya oriental.',
            ),
            AnswerItem(
              code: 'BTN',
              badge: '7.570 m',
              detail: 'Gangkhar Puensum, la montaña más alta sin escalar.',
            ),
            AnswerItem(
              code: 'TJK',
              badge: '7.495 m',
              detail: 'Pico Ismail Samani en la cordillera del Pamir.',
            ),
            AnswerItem(
              code: 'AFG',
              badge: '7.492 m',
              detail: 'Noshaq, en la cordillera del Hindú Kush.',
            ),
            AnswerItem(
              code: 'KGZ',
              badge: '7.439 m',
              detail: 'Pico Jengish Chokusu en el Tian Shan.',
            ),
            AnswerItem(
              code: 'KAZ',
              badge: '7.010 m',
              detail: 'Khan Tengri, pirámide de mármol en el Tian Shan.',
            ),
            AnswerItem(
              code: 'ARG',
              badge: '6.961 m',
              detail: 'Cerro Aconcagua, cumbre más alta fuera de Asia.',
            ),
          ],
        ),
        WorldQuestion(
          id: 'seed-population',
          question: 'Los 10 países más poblados',
          summary: 'Top 10 países del mundo por población total',
          ordered: true,
          createdAt: DateTime.utc(2026, 1, 3),
          items: const [
            AnswerItem(
              code: 'IND',
              badge: '1.43B',
              detail: 'El país más poblado del planeta desde 2023.',
            ),
            AnswerItem(
              code: 'CHN',
              badge: '1.41B',
              detail: 'Concentra la mayor población en su costa oriental.',
            ),
            AnswerItem(
              code: 'USA',
              badge: '340M',
              detail: 'Tercer país más poblado, con grandes áreas metropolitanas.',
            ),
            AnswerItem(
              code: 'IDN',
              badge: '278M',
              detail: 'Archipiélago de más de 17.000 islas; Java es la más densa.',
            ),
            AnswerItem(
              code: 'PAK',
              badge: '241M',
              detail: 'Población concentrada a lo largo del valle del Indo.',
            ),
            AnswerItem(
              code: 'NGA',
              badge: '224M',
              detail: 'El país más poblado de África, con Lagos como megaciudad.',
            ),
            AnswerItem(
              code: 'BRA',
              badge: '203M',
              detail: 'El más poblado de Sudamérica, sobre todo en la costa atlántica.',
            ),
            AnswerItem(
              code: 'BGD',
              badge: '173M',
              detail: 'Altísima densidad en el fértil delta del Ganges.',
            ),
            AnswerItem(
              code: 'RUS',
              badge: '144M',
              detail: 'El país más extenso; la mayoría vive en la parte europea.',
            ),
            AnswerItem(
              code: 'MEX',
              badge: '129M',
              detail: 'El país hispanohablante más poblado del mundo.',
            ),
          ],
        ),
      ];
}

