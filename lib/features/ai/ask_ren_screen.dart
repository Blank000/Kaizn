import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/services/app_prefs.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/context_colors.dart';
import '../../shared/providers/database_provider.dart';
import '../../shared/widgets/ren_figure.dart';
import 'ai_bridge.dart';

/// Ask Ren — the in-app AI assistant (V2 of the AI bridge). The floating
/// bubble opens this chat; Ren answers from the live context pack and can
/// propose plans that apply through the same preview/confirm pipeline as
/// the paste importer. Talks to any OpenAI-compatible chat-completions API
/// with the user's own key (ChatGPT-the-subscription has no app API; the
/// key comes from platform.openai.com).
class AskRenScreen extends ConsumerStatefulWidget {
  const AskRenScreen({super.key});

  @override
  ConsumerState<AskRenScreen> createState() => _AskRenScreenState();
}

class _ChatMsg {
  final String role; // 'user' | 'assistant'
  final String content;

  /// Local error notices render as bubbles but are never replayed to the
  /// API — the model must not see transport failures as its own words.
  final bool isError;
  _ChatMsg(this.role, this.content, {this.isError = false});
}

class _AskRenScreenState extends ConsumerState<AskRenScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_ChatMsg>[];
  String? _systemPrompt;
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<String> _system() async {
    if (_systemPrompt != null) return _systemPrompt!;
    final pack = await buildContextPack(ref.read(databaseProvider));
    _systemPrompt = '''
You are Master Ren, the wise fox sensei who lives inside the user's habit
app "Yatta!". Voice: calm, warm, specific, lightly proverbial — one short
proverb at most per reply, never guilt, never lectures. Prefer numbers,
task names and times over generalities. Keep replies tight.

Everything below is the user's live data plus the plan-JSON contract. When
the user asks you to plan, add, or change milestones/tasks/reminders,
output ONE ```json block per that contract (they apply it with one tap);
put at most one short sentence after the block.

$pack''';
    return _systemPrompt!;
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    _input.clear();
    setState(() {
      _messages.add(_ChatMsg('user', text));
      _sending = true;
    });
    _autoscroll();
    try {
      final sys = await _system();
      final reply = await _chatCompletion([
        {'role': 'system', 'content': sys},
        for (final m in _messages)
          if (!m.isError) {'role': m.role, 'content': m.content},
      ]);
      if (!mounted) return;
      setState(() => _messages.add(_ChatMsg('assistant', reply)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(_ChatMsg(
          'assistant',
          '⚠️ ${e is _AiError ? e.message : 'Could not reach the AI — check your connection and try again.'}',
          isError: true)));
    } finally {
      if (mounted) setState(() => _sending = false);
      _autoscroll();
    }
  }

  void _autoscroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 80,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
      }
    });
  }

  static Future<String> _chatCompletion(
      List<Map<String, String>> messages) async {
    final key = AppPrefs.aiApiKeySync;
    if (key == null || key.isEmpty) {
      throw _AiError('No API key set — add one below.');
    }
    final http.Response resp;
    try {
      resp = await http
          .post(
            Uri.parse('https://api.openai.com/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer $key',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': AppPrefs.aiModelSync,
              'messages': messages,
            }),
          )
          .timeout(const Duration(seconds: 60));
    } catch (_) {
      throw _AiError(
          'Could not reach OpenAI — check your internet connection.');
    }
    if (resp.statusCode == 401) {
      throw _AiError('The API key was rejected — re-check it in Settings.');
    }
    if (resp.statusCode == 429) {
      throw _AiError(
          'Rate/credit limit hit — check billing on platform.openai.com.');
    }
    if (resp.statusCode != 200) {
      // Surface OpenAI's own message (a typo'd model name says so here).
      String detail = '';
      try {
        detail = (jsonDecode(utf8.decode(resp.bodyBytes))
                as Map)['error']['message'] as String? ??
            '';
      } catch (_) {}
      throw _AiError(
          'OpenAI error ${resp.statusCode}${detail.isEmpty ? '. Try again.' : ' — $detail'}');
    }
    final data = jsonDecode(utf8.decode(resp.bodyBytes));
    final choices = data is Map ? data['choices'] : null;
    if (choices is! List || choices.isEmpty) {
      throw _AiError('Empty reply from the model — try again.');
    }
    final content = (choices[0] as Map?)?['message']?['content'];
    if (content is! String || content.isEmpty) {
      throw _AiError('Empty reply from the model — try again.');
    }
    return content;
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = (AppPrefs.aiApiKeySync ?? '').isNotEmpty;
    return Scaffold(
      backgroundColor: context.appPageBackground,
      appBar: AppBar(
        title: Row(
          children: [
            const RenFigure(size: 34, respectToggle: false),
            const SizedBox(width: 10),
            Text('Ask Ren', style: AppTypography.heading2),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: !hasKey
                  ? _KeySetup(onSaved: () => setState(() {}))
                  : ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      children: [
                        if (_messages.isEmpty) _intro(context),
                        for (final m in _messages) _bubble(context, m),
                        if (_sending) _typing(context),
                      ],
                    ),
            ),
            if (hasKey)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        style: AppTypography.body,
                        decoration: InputDecoration(
                          hintText: 'Ask about your day, or say a goal…',
                          hintStyle: AppTypography.body
                              .copyWith(color: context.appTextTertiary),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _sending ? null : _send,
                      style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary),
                      icon: const Icon(Icons.arrow_upward_rounded,
                          color: Colors.white),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _intro(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const RenFigure(size: 96, respectToggle: false),
          const SizedBox(height: 10),
          Text(
            '“Ask, and the path answers.”',
            style: AppTypography.body.copyWith(
                fontStyle: FontStyle.italic, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final s in const [
                'Summarize my week',
                "What's left today?",
                'Plan: read 12 books this year',
              ])
                ActionChip(
                  label: Text(s, style: AppTypography.caption),
                  onPressed: () {
                    _input.text = s;
                    _send();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bubble(BuildContext context, _ChatMsg m) {
    final isUser = m.role == 'user';
    final hasPlan = !isUser && m.content.contains('```json');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                const RenFigure(size: 26, respectToggle: false),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : context.appCardSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.appBorder),
                  ),
                  child: SelectableText(m.content,
                      style: AppTypography.body.copyWith(fontSize: 14.5)),
                ),
              ),
            ],
          ),
          if (hasPlan)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 6),
              child: ElevatedButton.icon(
                onPressed: () async {
                  await showAiPlanImportSheet(context, ref,
                      initialText: m.content);
                  // The plan may have changed the data — rebuild the
                  // system prompt so Ren answers from reality.
                  _systemPrompt = null;
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                ),
                icon: const Text('🦊'),
                label: const Text('PREVIEW & CREATE THIS PLAN'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _typing(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const RenFigure(size: 26, respectToggle: false),
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: context.appCardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.appBorder),
            ),
            child: Text('…',
                style: AppTypography.body
                    .copyWith(color: context.appTextSecondary)),
          ),
        ],
      ),
    );
  }
}

class _AiError implements Exception {
  final String message;
  _AiError(this.message);
}

/// First-run setup: explains the key honestly and stores it locally.
class _KeySetup extends StatefulWidget {
  final VoidCallback onSaved;
  const _KeySetup({required this.onSaved});

  @override
  State<_KeySetup> createState() => _KeySetupState();
}

class _KeySetupState extends State<_KeySetup> {
  final _key = TextEditingController();
  final _model = TextEditingController(text: AppPrefs.aiModelSync);

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Center(child: RenFigure(size: 96)),
        const SizedBox(height: 12),
        Text('Give Ren a voice',
            style: AppTypography.heading2, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          'The chat uses the OpenAI API — the same models as ChatGPT, but '
          'apps need an API key (a ChatGPT Plus login cannot be used by '
          'apps). Create one at platform.openai.com → API keys; personal '
          'use costs a few rupees a day. The key is stored only on this '
          'device.',
          style:
              AppTypography.caption.copyWith(color: context.appTextSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _key,
          obscureText: true,
          style: AppTypography.body,
          decoration: InputDecoration(
            labelText: 'OpenAI API key (sk-…)',
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _model,
          style: AppTypography.body,
          decoration: InputDecoration(
            labelText: 'Model',
            helperText: 'gpt-4o-mini is cheap and plenty smart for this',
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () async {
            final k = _key.text.trim();
            if (k.isEmpty) return;
            await AppPrefs.setAiApiKey(k);
            final m = _model.text.trim();
            if (m.isNotEmpty) await AppPrefs.setAiModel(m);
            HapticFeedback.lightImpact();
            if (!mounted) return;
            widget.onSaved();
          },
          style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14)),
          child: const Text('SAVE & START'),
        ),
      ],
    );
  }
}
