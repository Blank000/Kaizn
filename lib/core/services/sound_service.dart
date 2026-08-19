import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'app_prefs.dart';

/// The app's soundset — five short generated chimes (tools/generate_sounds.dart),
/// tuned to one key so overlaps never clash. OFF BY DEFAULT: sound is a
/// texture the user opts into, never a surprise. Every call is fire-and-
/// forget and swallows platform errors — audio must never break a completion.
enum AppSound {
  complete('sounds/complete.wav'),
  tick('sounds/tick.wav'),
  celebrate('sounds/celebrate.wav'),
  chest('sounds/chest.wav'),
  levelUp('sounds/levelup.wav');

  const AppSound(this.asset);
  final String asset;
}

class SoundService {
  SoundService._();

  // One player per sound: retriggering restarts the clip (correct for UI
  // blips) and rapid different sounds can overlap freely.
  static final _players = <AppSound, AudioPlayer>{};
  static bool _contextConfigured = false;

  static Future<void> play(AppSound sound) async {
    if (!AppPrefs.soundEnabledSync) return;
    try {
      // Configure once, lazily: UI blips must NEVER steal audio focus —
      // without this, every chime pauses the user's music (Android
      // default is AUDIOFOCUS_GAIN) and iOS breaks background audio.
      if (!_contextConfigured) {
        _contextConfigured = true;
        await AudioPlayer.global.setAudioContext(AudioContext(
          android: const AudioContextAndroid(
            audioFocus: AndroidAudioFocus.none,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.assistanceSonification,
          ),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
        ));
      }
      // Awaited on creation so a native failure lands in THIS try/catch
      // instead of escaping as an unhandled async error.
      final isNew = !_players.containsKey(sound);
      final p = _players.putIfAbsent(sound, AudioPlayer.new);
      if (isNew) await p.setReleaseMode(ReleaseMode.stop);
      await p.stop();
      await p.play(AssetSource(sound.asset), mode: PlayerMode.lowLatency);
    } catch (e) {
      // Silent-by-design: a missing codec or focus conflict is not worth
      // more than a debug line.
      debugPrint('SoundService: $e');
    }
  }
}
