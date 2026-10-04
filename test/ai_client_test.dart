import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:habit_reward_tracker/core/constants/ai_config.dart';
import 'package:habit_reward_tracker/features/ai/ai_client.dart';

/// The app's half of the server contract. The server's half is tested in
/// server/tests/run_tests.php against a real PHP runtime.
void main() {
  String body(Map<String, Object?> m) => jsonEncode(m);

  test('200 -> the reply and the remaining count', () {
    final r = AiClient.parseServerResponse(
        200, body({'reply': 'Hi!', 'remaining': 37, 'limit': 50}));
    expect(r.text, 'Hi!');
    expect(r.remaining, 37);
  });

  test('200 with an empty reply is an error, not a blank bubble', () {
    expect(() => AiClient.parseServerResponse(200, body({'reply': ''})),
        throwsA(isA<AiError>()));
  });

  test('429 -> daily limit, pointing at the own-key escape hatch', () {
    try {
      AiClient.parseServerResponse(429,
          body({'error': 'daily_limit', 'remaining': 0, 'limit': 50}));
      fail('should throw');
    } on AiError catch (e) {
      expect(e.dailyLimit, isTrue);
      expect(e.message, contains('$kAiDailyLimit'));
      expect(e.message, contains('own OpenAI key'));
    }
  });

  test('401 after the retry -> sign in again', () {
    expect(
        () => AiClient.parseServerResponse(401, body({'error': 'auth_invalid'})),
        throwsA(predicate<AiError>((e) => e.message.contains('sign-in'))));
  });

  test('413 -> start a new chat', () {
    expect(
        () => AiClient.parseServerResponse(413, body({'error': 'too_large'})),
        throwsA(predicate<AiError>((e) => e.message.contains('new chat'))));
  });

  test("other failures use the server's own human message", () {
    expect(
        () => AiClient.parseServerResponse(502, body({
              'error': 'upstream',
              'message': 'Pico could not get an answer just now.',
            })),
        throwsA(predicate<AiError>(
            (e) => e.message == 'Pico could not get an answer just now.')));
  });

  test('a non-JSON body (a proxy error page) never crashes', () {
    expect(
        () => AiClient.parseServerResponse(500, '<html>Bad Gateway</html>'),
        throwsA(predicate<AiError>((e) => e.message.contains('500'))));
  });
}
