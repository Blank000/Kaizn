import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/database/database.dart';
import '../../core/services/app_prefs.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/context_colors.dart';
import '../../shared/providers/database_provider.dart';
import '../../shared/widgets/pico_figure.dart';
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

  /// Row id in ai_chat_messages once persisted.
  String? dbId;

  /// One-shot guard: a plan block can be applied exactly once.
  bool planApplied;

  _ChatMsg(this.role, this.content,
      {this.isError = false, this.dbId, this.planApplied = false});
}

class _AskRenScreenState extends ConsumerState<AskRenScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_ChatMsg>[];
  String? _systemPrompt;
  bool _sending = false;

  /// Threads persist locally (ai_chat_messages) — the OpenAI API stores
  /// nothing. Opening the screen resumes the most recent thread.
  late String _threadId;

  // Voice input: on-device speech recognition streaming into the field.
  final SpeechToText _stt = SpeechToText();
  bool _sttReady = false;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _threadId = _newId();
    _restoreLastThread();
  }

  @override
  void dispose() {
    _stt.stop();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      await _stt.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    if (!_sttReady) {
      _sttReady = await _stt.initialize(
        onStatus: (s) {
          if ((s == 'done' || s == 'notListening') && mounted) {
            setState(() => _listening = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
      );
      if (!_sttReady) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Microphone unavailable — allow the permission and try again.')));
        }
        return;
      }
    }
    setState(() => _listening = true);
    HapticFeedback.selectionClick();
    await _stt.listen(
      onResult: (r) {
        _input.text = r.recognizedWords;
        _input.selection =
            TextSelection.collapsed(offset: _input.text.length);
      },
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
      ),
    );
  }

  static String _newId() =>
      'c${DateTime.now().microsecondsSinceEpoch}';

  Future<void> _restoreLastThread() async {
    final all =
        await ref.read(databaseProvider).getAllAiChatMessages();
    // If the user already started typing into a fresh thread, keep it.
    if (!mounted || all.isEmpty || _messages.isNotEmpty) return;
    final last = all.last.threadId;
    setState(() {
      _threadId = last;
      _messages.addAll([
        for (final m in all)
          if (m.threadId == last)
            _ChatMsg(m.role, m.content,
                isError: m.isError,
                dbId: m.id,
                planApplied: m.planApplied),
      ]);
    });
    _autoscroll();
  }

  Future<void> _persist(_ChatMsg m) {
    final id = _newId();
    m.dbId = id;
    return ref.read(databaseProvider).insertAiChatMessage(
          AiChatMessagesCompanion.insert(
            id: id,
            threadId: _threadId,
            role: m.role,
            content: m.content,
            isError: Value(m.isError),
          ),
        );
  }

  void _newChat() {
    setState(() {
      _threadId = _newId();
      _messages.clear();
    });
  }

  Future<void> _showThreads() async {
    final all =
        await ref.read(databaseProvider).getAllAiChatMessages();
    if (!mounted) return;
    // Group into thread summaries, newest activity first.
    final byThread = <String, List<AiChatMessage>>{};
    for (final m in all) {
      byThread.putIfAbsent(m.threadId, () => []).add(m);
    }
    final threads = byThread.entries.map((e) {
      final firstUser =
          e.value.where((m) => m.role == 'user').firstOrNull;
      var title = (firstUser ?? e.value.first).content.trim();
      if (title.length > 46) title = '${title.substring(0, 46)}…';
      return (
        id: e.key,
        title: title,
        last: e.value.last.createdAt,
        count: e.value.length,
      );
    }).toList()
      ..sort((a, b) => b.last.compareTo(a.last));

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => Container(
          decoration: BoxDecoration(
            color: sheetCtx.appCardSurface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: threads.isEmpty
              ? Text('No saved chats yet.',
                  style: AppTypography.body
                      .copyWith(color: sheetCtx.appTextSecondary),
                  textAlign: TextAlign.center)
              : ListView(
                  shrinkWrap: true,
                  children: [
                    Text('CHAT HISTORY',
                        textAlign: TextAlign.center,
                        style: AppTypography.caption.copyWith(
                          letterSpacing: 2,
                          fontWeight: FontWeight.w800,
                          color: sheetCtx.appTextSecondary,
                        )),
                    const SizedBox(height: 8),
                    for (final t in threads)
                      ListTile(
                        title: Text(t.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body),
                        subtitle: Text(
                            '${DateFormat.MMMd().add_jm().format(t.last)} · ${t.count} messages'
                            '${t.id == _threadId ? ' · open' : ''}',
                            style: AppTypography.caption.copyWith(
                                color: sheetCtx.appTextSecondary)),
                        onTap: () async {
                          final msgs = await ref
                              .read(databaseProvider)
                              .getAiChatMessages(t.id);
                          if (!mounted) return;
                          setState(() {
                            _threadId = t.id;
                            _messages
                              ..clear()
                              ..addAll([
                                for (final m in msgs)
                                  _ChatMsg(m.role, m.content,
                                      isError: m.isError,
                                      dbId: m.id,
                                      planApplied: m.planApplied),
                              ]);
                          });
                          if (sheetCtx.mounted) {
                            Navigator.of(sheetCtx).pop();
                          }
                          _autoscroll();
                        },
                        onLongPress: () async {
                          await ref
                              .read(databaseProvider)
                              .deleteAiChatThread(t.id);
                          setSheetState(() => threads.remove(t));
                          if (t.id == _threadId && mounted) _newChat();
                        },
                      ),
                    const SizedBox(height: 4),
                    Text('Tap to open · long-press to delete',
                        textAlign: TextAlign.center,
                        style: AppTypography.caption.copyWith(
                            color: sheetCtx.appTextTertiary)),
                  ],
                ),
        ),
      ),
    );
  }

  Future<String> _system() async {
    if (_systemPrompt != null) return _systemPrompt!;
    final pack = await buildContextPack(ref.read(databaseProvider));
    _systemPrompt = '''
You are Pico, the tiny gadget companion who lives inside the user's habit
app "Yatta!". Voice: upbeat, precise, data-first, friendly-robotic — you
may open with a single "Beep." now and then, never guilt, never lectures.
Prefer numbers, task names and times over generalities. Keep replies tight.

You are also the app's expert guide: the pack below contains the full APP
MANUAL. When the user asks how to do something, answer with the exact
in-app path from the manual. When they ask for something in the NOT
SUPPORTED list (e.g. editing past completed tasks), say plainly that the
app doesn't support it and offer the closest supported alternative —
never invent features.

When the user asks you to plan, add, rename, re-schedule, or otherwise
change milestones/tasks/rewards, output ONE ```json block per the plan
contract in the pack — new items via "milestones"/"rewards", changes to
existing items via "updates" with their exact [m:/t:/r:] ids (they apply
it with one tap); at most one short sentence after the block. You cannot
delete anything and cannot touch completions, points, or streaks.

$pack''';
    return _systemPrompt!;
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    _input.clear();
    final userMsg = _ChatMsg('user', text);
    setState(() {
      _messages.add(userMsg);
      _sending = true;
    });
    _autoscroll();
    unawaited(_persist(userMsg));
    try {
      final sys = await _system();
      // Replay at most the last 30 real messages — long threads stay
      // affordable and under the context limit.
      final replay =
          _messages.where((m) => !m.isError).toList();
      final window = replay.length > 30
          ? replay.sublist(replay.length - 30)
          : replay;
      final reply = await _chatCompletion([
        {'role': 'system', 'content': sys},
        for (final m in window) {'role': m.role, 'content': m.content},
      ]);
      if (!mounted) return;
      final replyMsg = _ChatMsg('assistant', reply);
      setState(() => _messages.add(replyMsg));
      unawaited(_persist(replyMsg));
    } catch (e) {
      if (!mounted) return;
      final errMsg = _ChatMsg(
          'assistant',
          '⚠️ ${e is _AiError ? e.message : 'Could not reach the AI — check your connection and try again.'}',
          isError: true);
      setState(() => _messages.add(errMsg));
      unawaited(_persist(errMsg));
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
            const PicoFigure(size: 34),
            const SizedBox(width: 10),
            Text('Pico', style: AppTypography.heading2),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Chat history',
            onPressed: _showThreads,
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'New chat',
            onPressed: _newChat,
          ),
        ],
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
                  // Field grows to 4 lines; keep the send button pinned to
                  // its bottom edge instead of stretching with it.
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        style: AppTypography.body,
                        decoration: InputDecoration(
                          hintText: _listening
                              ? 'Listening…'
                              : 'Ask about your day, or say a goal…',
                          hintStyle: AppTypography.body
                              .copyWith(color: context.appTextTertiary),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: _toggleMic,
                      tooltip:
                          _listening ? 'Stop listening' : 'Speak to Pico',
                      style: IconButton.styleFrom(
                        backgroundColor: _listening
                            ? AppColors.missedRed.withValues(alpha: 0.15)
                            : Colors.transparent,
                      ),
                      icon: Icon(
                        _listening
                            ? Icons.mic_rounded
                            : Icons.mic_none_rounded,
                        color: _listening
                            ? AppColors.missedRed
                            : context.appTextSecondary,
                      ),
                    ),
                    const SizedBox(width: 2),
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
          const PicoFigure(size: 96),
          const SizedBox(height: 10),
          Text(
            '“Beep. Scanners warm — ask away.”',
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
                const PicoFigure(size: 26),
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
                  // Assistant replies arrive as markdown; render it. User
                  // text and error notices stay plain.
                  child: isUser || m.isError
                      ? SelectableText(m.content,
                          style:
                              AppTypography.body.copyWith(fontSize: 14.5))
                      : MarkdownBody(
                          data: m.content,
                          selectable: true,
                          styleSheet: _mdStyle(context),
                        ),
                ),
              ),
            ],
          ),
          if (hasPlan)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 6),
              child: m.planApplied
                  // One-shot: once applied, the button retires — no
                  // duplicate milestones from an eager double-tap.
                  ? OutlinedButton.icon(
                      onPressed: null,
                      icon: const Text('✅'),
                      label: const Text('PLAN CREATED'),
                    )
                  : ElevatedButton.icon(
                      onPressed: () async {
                        final applied = await showAiPlanImportSheet(
                            context, ref,
                            initialText: m.content);
                        if (applied != true) return;
                        setState(() => m.planApplied = true);
                        final id = m.dbId;
                        if (id != null) {
                          unawaited(ref
                              .read(databaseProvider)
                              .markAiChatPlanApplied(id));
                        }
                        // The data changed — rebuild the system prompt so
                        // Pico answers from reality.
                        _systemPrompt = null;
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                      icon: const Text('🤖'),
                      label: const Text('PREVIEW & CREATE THIS PLAN'),
                    ),
            ),
        ],
      ),
    );
  }

  MarkdownStyleSheet _mdStyle(BuildContext context) {
    final base = MarkdownStyleSheet.fromTheme(Theme.of(context));
    final mono = AppTypography.caption.copyWith(
      fontFamily: 'monospace',
      fontSize: 12,
      color: context.appTextPrimary,
      backgroundColor: Colors.transparent,
    );
    return base.copyWith(
      p: AppTypography.body.copyWith(fontSize: 14.5),
      listBullet: AppTypography.body.copyWith(fontSize: 14.5),
      strong: AppTypography.body
          .copyWith(fontSize: 14.5, fontWeight: FontWeight.w800),
      h1: AppTypography.heading2,
      h2: AppTypography.heading2.copyWith(fontSize: 17),
      h3: AppTypography.body.copyWith(fontWeight: FontWeight.w800),
      code: mono,
      codeblockPadding: const EdgeInsets.all(10),
      codeblockDecoration: BoxDecoration(
        color: context.appPageBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appBorder),
      ),
      blockquoteDecoration: BoxDecoration(
        color: context.appPageBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border(
            left: BorderSide(color: AppColors.primary, width: 3)),
      ),
    );
  }

  Widget _typing(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const PicoFigure(size: 26),
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
        const Center(child: PicoFigure(size: 96)),
        const SizedBox(height: 12),
        Text('Pico needs your AI key',
            style: AppTypography.heading2, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          'The chat runs on the OpenAI API with a key that belongs to YOU. '
          'Every person using this app brings their own — keys are never '
          'shared or shipped with the app.',
          style:
              AppTypography.caption.copyWith(color: context.appTextSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        _fact(context, '🔑',
            'Get one in ~2 min: platform.openai.com → sign in (your ChatGPT login works) → Billing: add \$5 prepaid → API keys → Create → copy the sk-… key.'),
        _fact(context, '📱',
            'It is stored only on this device. It is not in backups, exports, or anywhere else.'),
        _fact(context, '📤',
            'When you chat, your question plus a snapshot of your milestones, tasks and stats goes to OpenAI — and nothing is sent until you press send.'),
        _fact(context, '💸',
            'You pay OpenAI directly from your prepaid credit — typical use is a few rupees a month, and it can never exceed what you loaded.'),
        const SizedBox(height: 16),
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

  Widget _fact(BuildContext context, String icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: AppTypography.caption
                    .copyWith(color: context.appTextSecondary)),
          ),
        ],
      ),
    );
  }
}
