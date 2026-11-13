import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/country.dart';
import '../../data/repositories/question_store.dart';
import '../../data/services/llm_client.dart';
import '../../data/services/speech_service.dart';
import '../l10n_labels.dart';

/// Floating bar that displays the active question (or "All flags"), lets the
/// user ask a question by voice (`🎤`) or text, and opens the question history.
class QuestionBar extends StatefulWidget {
  const QuestionBar({
    super.key,
    required this.store,
    required this.countries,
    this.initiallyCollapsed = false,
    this.collapsed,
    this.onCollapsedChanged,
  });

  final QuestionStore store;
  final List<Country> countries;
  final bool initiallyCollapsed;
  final bool? collapsed;
  final ValueChanged<bool>? onCollapsedChanged;

  @override
  State<QuestionBar> createState() => _QuestionBarState();
}

class _QuestionBarState extends State<QuestionBar> {
  final _speech = SpeechService();
  Timer? _silenceTimer;
  String _liveTranscript = '';
  bool _listening = false;
  late bool _collapsed = widget.collapsed ?? widget.initiallyCollapsed;

  @override
  void didUpdateWidget(QuestionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.collapsed != null && widget.collapsed != _collapsed) {
      _collapsed = widget.collapsed!;
    }
  }

  void _setCollapsed(bool value) {
    if (_collapsed == value) return;
    setState(() => _collapsed = value);
    widget.onCollapsedChanged?.call(value);
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _speech.stop();
    super.dispose();
  }

  Future<void> _startMic() async {
    if (_listening) {
      await _finishAndSendVoice();
      return;
    }

    setState(() => _liveTranscript = '');
    final localeId = widget.store.config.speechLocaleId;
    final started = await _speech.start(
      localeId: localeId,
      onResult: (text) {
        if (!mounted) return;
        setState(() => _liveTranscript = text);
        _silenceTimer?.cancel();
        if (text.trim().isNotEmpty) {
          _silenceTimer = Timer(
            const Duration(milliseconds: 1800),
            _finishAndSendVoice,
          );
        }
      },
      onListeningChanged: (active) {
        if (!mounted) return;
        setState(() => _listening = active);
      },
    );

    if (!started && mounted) {
      await _openHistorySheet(autofocusInput: true);
    }
  }

  Future<void> _finishAndSendVoice() async {
    _silenceTimer?.cancel();
    final prompt = _liveTranscript.trim();
    setState(() {
      _listening = false;
      _liveTranscript = '';
    });
    await _speech.stop();
    if (prompt.isNotEmpty && mounted) {
      await _submitQuestion(prompt);
    }
  }

  Future<void> _cancelVoice() async {
    _silenceTimer?.cancel();
    setState(() {
      _listening = false;
      _liveTranscript = '';
    });
    await _speech.stop();
  }

  Future<void> _submitQuestion(String prompt) async {
    if (!widget.store.config.isConfigured) {
      if (!mounted) return;
      final configured = await LlmSettingsSheet.show(
        context,
        store: widget.store,
      );
      if (configured != true || !mounted) return;
    }
    final lang = widget.store.config.speechLanguage;
    _setCollapsed(true);
    await widget.store.ask(
      prompt: prompt,
      countries: widget.countries,
      languageCode: lang,
    );
  }

  Future<void> _toggleLanguage() async {
    final current = widget.store.config.speechLanguage;
    final next = current == 'es' ? 'en' : 'es';
    await widget.store.updateConfig(
      widget.store.config.copyWith(speechLanguage: next),
    );
  }

  Future<void> _openHistorySheet({bool autofocusInput = false}) async {
    final prevId = widget.store.activeQuestion?.id;
    await QuestionHistorySheet.show(
      context,
      store: widget.store,
      countries: widget.countries,
      autofocusInput: autofocusInput,
    );
    if (!mounted) return;
    if (widget.store.activeQuestion != null &&
        widget.store.activeQuestion?.id != prevId) {
      _setCollapsed(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final active = widget.store.activeQuestion;
        final asking = widget.store.isAsking;
        final error = widget.store.error;

        if (_collapsed) {
          return Align(
            alignment: Alignment.bottomLeft,
            child: Tooltip(
              message: active != null
                  ? active.question
                  : l.questionExpandTooltip,
              child: Material(
                color: const Color(0xEB181B20),
                shape: const CircleBorder(),
                elevation: 6,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _setCollapsed(false),
                  child: Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    child: asking
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.amberAccent,
                            ),
                          )
                        : Icon(
                            active != null ? Icons.auto_awesome : Icons.mic,
                            color: active != null ? Colors.amber : Colors.white,
                            size: 24,
                          ),
                  ),
                ),
              ),
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: Colors.redAccent.shade700,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => LlmSettingsSheet.show(
                      context,
                      store: widget.store,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              error,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Material(
              color: const Color(0xEB181B20),
              elevation: 6,
              borderRadius: BorderRadius.circular(28),
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: () => _openHistorySheet(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: l.questionCollapseTooltip,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _setCollapsed(true),
                        icon: const Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.white70,
                          size: 22,
                        ),
                      ),
                      Icon(
                        active != null ? Icons.auto_awesome : Icons.flag_outlined,
                        color: active != null ? Colors.amber : Colors.white70,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: asking
                            ? Text(
                                l.questionThinking,
                                style: const TextStyle(
                                  color: Colors.amberAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : _listening
                                ? Text(
                                    _liveTranscript.isEmpty
                                        ? l.questionListening
                                        : _liveTranscript,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.greenAccent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        active != null
                                            ? active.summary
                                            : l.questionAllFlags,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                      Text(
                                        active != null
                                            ? l.questionCloseUpHint
                                            : l.questionHint,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                      ),
                      if (active != null && !asking && !_listening)
                        IconButton(
                          tooltip: l.questionClearTooltip,
                          visualDensity: VisualDensity.compact,
                          onPressed: () => widget.store.selectQuestion(null),
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white70,
                            size: 18,
                          ),
                        ),
                      if (_listening)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: _cancelVoice,
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white70,
                            size: 20,
                          ),
                        )
                      else
                        TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(36, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            foregroundColor: Colors.white70,
                          ),
                          onPressed: _toggleLanguage,
                          child: Text(
                            widget.store.config.speechLanguage.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      IconButton.filled(
                        tooltip: _listening
                            ? l.questionAskButton
                            : l.questionMicTooltip,
                        style: IconButton.styleFrom(
                          backgroundColor: _listening
                              ? Colors.greenAccent.shade400
                              : Colors.amber.shade700,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: asking
                            ? null
                            : (_listening ? _finishAndSendVoice : _startMic),
                        icon: Icon(
                          _listening ? Icons.send : Icons.mic,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Bottom sheet to ask a new question, pick a previous question from history,
/// or inspect the active question's country bullets.
class QuestionHistorySheet extends StatefulWidget {
  const QuestionHistorySheet({
    super.key,
    required this.store,
    required this.countries,
    this.autofocusInput = false,
  });

  final QuestionStore store;
  final List<Country> countries;
  final bool autofocusInput;

  static Future<void> show(
    BuildContext context, {
    required QuestionStore store,
    required List<Country> countries,
    bool autofocusInput = false,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (_) => QuestionHistorySheet(
          store: store,
          countries: countries,
          autofocusInput: autofocusInput,
        ),
      );

  @override
  State<QuestionHistorySheet> createState() => _QuestionHistorySheetState();
}

class _QuestionHistorySheetState extends State<QuestionHistorySheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (!widget.store.config.isConfigured) {
      final ok = await LlmSettingsSheet.show(context, store: widget.store);
      if (ok != true || !mounted) return;
    }
    final lang = widget.store.config.speechLanguage;
    final res = await widget.store.ask(
      prompt: text,
      countries: widget.countries,
      languageCode: lang,
    );
    if (res != null && mounted) {
      _controller.clear();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scroll) => ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final active = widget.store.activeQuestion;
            final history = widget.store.history;
            final asking = widget.store.isAsking;

            return ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.questionHistoryTitle,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => LlmSettingsSheet.show(
                        context,
                        store: widget.store,
                      ),
                      icon: const Icon(Icons.tune, size: 18),
                      label: Text(widget.store.config.provider.label),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: widget.autofocusInput,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          hintText: l.questionHint,
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: asking ? null : _submit,
                      child: asking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l.questionAskButton),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  selected: active == null,
                  selectedTileColor: theme.colorScheme.primaryContainer,
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(l.questionAllFlags),
                  onTap: () {
                    widget.store.selectQuestion(null);
                    Navigator.of(context).pop();
                  },
                ),
                const Divider(height: 20),
                for (final q in history) ...[
                  Card(
                    elevation: active?.id == q.id ? 2 : 0,
                    color: active?.id == q.id
                        ? theme.colorScheme.secondaryContainer
                        : theme.colorScheme.surfaceContainerLow,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        widget.store.selectQuestion(q);
                        Navigator.of(context).pop();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              active?.id == q.id
                                  ? Icons.radio_button_checked
                                  : Icons.history,
                              size: 18,
                              color: active?.id == q.id
                                  ? theme.colorScheme.primary
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                q.question,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Sheet to select Gemini, ChatGPT, Claude or local Ollama and save credentials.
class LlmSettingsSheet extends StatefulWidget {
  const LlmSettingsSheet({super.key, required this.store});

  final QuestionStore store;

  static Future<bool?> show(
    BuildContext context, {
    required QuestionStore store,
  }) =>
      showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (_) => LlmSettingsSheet(store: store),
      );

  @override
  State<LlmSettingsSheet> createState() => _LlmSettingsSheetState();
}

class _LlmSettingsSheetState extends State<LlmSettingsSheet> {
  final _client = LlmClient();
  late LlmProvider _provider;
  late final TextEditingController _geminiKey;
  late final TextEditingController _openaiKey;
  late final TextEditingController _anthropicKey;
  late final TextEditingController _ollamaUrl;
  late final TextEditingController _model;
  List<String> _ollamaModels = const [];
  bool _loadingModels = false;

  @override
  void initState() {
    super.initState();
    final cfg = widget.store.config;
    _provider = cfg.provider;
    _geminiKey = TextEditingController(text: cfg.geminiKey);
    _openaiKey = TextEditingController(text: cfg.openaiKey);
    _anthropicKey = TextEditingController(text: cfg.anthropicKey);
    _ollamaUrl = TextEditingController(text: cfg.ollamaBaseUrl);
    final initialModel = cfg.activeModel == cfg.provider.defaultModel ? '' : cfg.customModel;
    _model = TextEditingController(text: initialModel);
    if (_provider == LlmProvider.ollama) _refreshOllamaModels();
  }

  Future<void> _refreshOllamaModels() async {
    setState(() => _loadingModels = true);
    final url = _ollamaUrl.text.trim().isEmpty
        ? 'http://localhost:11434'
        : _ollamaUrl.text.trim();
    final models = await _client.fetchOllamaModels(url);
    if (!mounted) return;
    setState(() {
      _loadingModels = false;
      _ollamaModels = models;
      if (_model.text.trim().isEmpty && models.isNotEmpty) {
        _model.text = models.first;
      }
    });
  }

  @override
  void dispose() {
    _geminiKey.dispose();
    _openaiKey.dispose();
    _anthropicKey.dispose();
    _ollamaUrl.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final next = LlmConfig(
      provider: _provider,
      geminiKey: _geminiKey.text.trim(),
      openaiKey: _openaiKey.text.trim(),
      anthropicKey: _anthropicKey.text.trim(),
      ollamaBaseUrl: _ollamaUrl.text.trim().isEmpty
          ? 'http://localhost:11434'
          : _ollamaUrl.text.trim(),
      customModel: _provider == LlmProvider.ollama ? _model.text.trim() : '',
      speechLanguage: widget.store.config.speechLanguage,
    );
    await widget.store.updateConfig(next);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final keyController = switch (_provider) {
      LlmProvider.gemini => _geminiKey,
      LlmProvider.openai => _openaiKey,
      LlmProvider.anthropic => _anthropicKey,
      LlmProvider.ollama => null,
    };

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.llmSettingsTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            l.llmMissingKeyPrompt,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            LlmClient.buildTag,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<LlmProvider>(
            initialValue: _provider,
            decoration: InputDecoration(
              labelText: l.llmProviderLabel,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final p in LlmProvider.values)
                DropdownMenuItem(value: p, child: Text(p.label)),
            ],
            onChanged: (p) {
              if (p == null) return;
              setState(() {
                _provider = p;
                _model.text = '';
              });
              if (p == LlmProvider.ollama) _refreshOllamaModels();
            },
          ),
          const SizedBox(height: 12),
          if (keyController != null)
            TextField(
              controller: keyController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: '${_provider.label} · ${l.llmApiKeyLabel}',
                hintText: l.llmApiKeyHint,
                border: const OutlineInputBorder(),
              ),
            )
          else
            TextField(
              controller: _ollamaUrl,
              onSubmitted: (_) => _refreshOllamaModels(),
              decoration: InputDecoration(
                labelText: l.llmOllamaUrlLabel,
                hintText: l.llmOllamaUrlHint,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: _loadingModels ? null : _refreshOllamaModels,
                  icon: _loadingModels
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ),
            ),
          if (_provider == LlmProvider.ollama) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _model,
              decoration: InputDecoration(
                labelText: l.llmModelLabel,
                hintText: _provider.defaultModel,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_ollamaModels.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final m in _ollamaModels)
                    ChoiceChip(
                      label: Text(m, style: const TextStyle(fontSize: 12)),
                      selected: _model.text.trim() == m,
                      onSelected: (_) => setState(() => _model.text = m),
                    ),
                ],
              ),
            ],
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _save,
            child: Text(l.llmSaveButton),
          ),
        ],
      ),
    );
  }
}
