import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/ai_config.dart';
import '../../core/services/app_prefs.dart';
import '../../core/services/auth_service.dart';

/// Which route a Pico message takes.
enum AiMode {
  /// The user added their own OpenAI key: call OpenAI directly with their
  /// key and their chosen model. Our server is not involved and no cap
  /// applies.
  ownKey,

  /// No personal key: go through Zuzu's server, which holds the owner's
  /// key and model. The app never sees either. Capped per person per day.
  zuzuServer,

  /// No personal key and no server configured - ask the user for a key.
  unavailable,
}

class AiReply {
  final String text;

  /// Messages left today on the Zuzu server; null for the own-key route.
  final int? remaining;
  const AiReply(this.text, {this.remaining});
}

class AiError implements Exception {
  final String message;

  /// Today's free allowance is used up - the UI can point at "add your own
  /// key" rather than "try again".
  final bool dailyLimit;
  const AiError(this.message, {this.dailyLimit = false});
  @override
  String toString() => message;
}

class AiClient {
  AiClient._();

  /// A personal key always wins - the user chose it deliberately.
  static AiMode get mode {
    if ((AppPrefs.aiApiKeySync ?? '').isNotEmpty) return AiMode.ownKey;
    if (aiServerEnabled) return AiMode.zuzuServer;
    return AiMode.unavailable;
  }

  static Future<AiReply> complete(List<Map<String, String>> messages) {
    switch (mode) {
      case AiMode.ownKey:
        return _viaOwnKey(messages);
      case AiMode.zuzuServer:
        return _viaServer(messages);
      case AiMode.unavailable:
        throw const AiError('Add an OpenAI key to use Pico.');
    }
  }

  // ── Zuzu server ───────────────────────────────────────────────────────────

  static Future<AiReply> _viaServer(List<Map<String, String>> messages,
      {bool retried = false}) async {
    final token = await AuthService.idToken(refresh: retried);
    if (token == null) {
      throw const AiError('Sign in with Google to use Pico.');
    }
    final http.Response resp;
    try {
      resp = await http
          .post(
            Uri.parse(kAiProxyUrl),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'messages': messages}),
          )
          .timeout(const Duration(seconds: 100));
    } catch (_) {
      throw const AiError(
          "Couldn't reach Pico's server. Check your connection and try again.");
    }
    // An ID token lasts about an hour. One refresh, then stop - looping on
    // 401 would hammer Google and the server for a sign-in that is gone.
    if (resp.statusCode == 401 && !retried) {
      return _viaServer(messages, retried: true);
    }
    return parseServerResponse(resp.statusCode, utf8.decode(resp.bodyBytes));
  }

  /// Turn the server's answer into a reply or a sentence a person can act
  /// on. Pure, so every status is unit-tested without a network.
  static AiReply parseServerResponse(int status, String body) {
    Map<String, dynamic> json = const {};
    try {
      final d = jsonDecode(body);
      if (d is Map<String, dynamic>) json = d;
    } catch (_) {}

    if (status == 200) {
      final text = json['reply'];
      if (text is! String || text.isEmpty) {
        throw const AiError('Empty reply from Pico - try again.');
      }
      final rem = json['remaining'];
      return AiReply(text, remaining: rem is int ? rem : null);
    }
    switch (status) {
      case 429:
        throw const AiError(
          "You've used today's $kAiDailyLimit messages. They come back at "
          'midnight - or add your own OpenAI key in Settings for no limit.',
          dailyLimit: true,
        );
      case 401:
        throw const AiError(
            'Your Google sign-in has expired. Sign out and back in from '
            'Settings, then try again.');
      case 413:
        throw const AiError(
            'This chat has grown too long. Start a new chat and carry on.');
    }
    final msg = json['message'];
    throw AiError(msg is String && msg.isNotEmpty
        ? msg
        : 'Pico had a problem ($status). Try again in a moment.');
  }

  // ── The user's own key (unchanged behaviour) ─────────────────────────────

  static Future<AiReply> _viaOwnKey(List<Map<String, String>> messages) async {
    final key = AppPrefs.aiApiKeySync!;
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
      throw const AiError(
          'Could not reach OpenAI - check your internet connection.');
    }
    if (resp.statusCode == 401) {
      throw const AiError(
          'Your API key was rejected - re-check it in Settings.');
    }
    if (resp.statusCode == 429) {
      throw const AiError(
          'Rate/credit limit hit - check billing on platform.openai.com.');
    }
    if (resp.statusCode != 200) {
      // Surface OpenAI's own message (a typo'd model name says so here).
      // Safe on this route: it is the user's own key and model.
      String detail = '';
      try {
        detail = (jsonDecode(utf8.decode(resp.bodyBytes))
                as Map)['error']['message'] as String? ??
            '';
      } catch (_) {}
      throw AiError('OpenAI error ${resp.statusCode}'
          '${detail.isEmpty ? '. Try again.' : ' - $detail'}');
    }
    final data = jsonDecode(utf8.decode(resp.bodyBytes));
    final choices = data is Map ? data['choices'] : null;
    final content = choices is List && choices.isNotEmpty
        ? (choices[0] as Map?)?['message']?['content']
        : null;
    if (content is! String || content.isEmpty) {
      throw const AiError('Empty reply from the model - try again.');
    }
    return AiReply(content);
  }
}
