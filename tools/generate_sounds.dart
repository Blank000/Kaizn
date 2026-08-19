// Generates the app's UI soundset as small PCM16 WAV files — no external
// assets, same philosophy as tools/generate_icon.dart. Run:
//   dart run tools/generate_sounds.dart
//
// Sound design notes: everything is short (<600ms), soft-attack, and tuned
// to a C-major feel so sounds layer without clashing. Volumes are baked
// conservative (peak ~0.5) — UI sounds should whisper, not announce.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const sampleRate = 44100;

void main() {
  final outDir = Directory('assets/sounds');
  outDir.createSync(recursive: true);

  // Task complete: a bright little "dink" — E6 grace into B6, instant joy.
  save('complete', [
    _tone(1318.5, ms: 55, gain: 0.32, decay: 18),
    _tone(1975.5, ms: 140, gain: 0.38, decay: 9, harmonics: true),
  ]);

  // Counter tick: a tiny wooden tap for rolling numbers / beat advances.
  save('tick', [
    _tone(2200, ms: 24, gain: 0.18, decay: 60),
  ]);

  // Celebration: C5-E5-G5-C6 arpeggio, notes overlapping like a strum.
  save('celebrate', [
    _chordArp([523.25, 659.25, 783.99, 1046.5],
        noteMs: 90, tailMs: 380, gain: 0.30),
  ]);

  // Chest open: rising sparkle gliss (E5→E6) with shimmer.
  save('chest', [
    _gliss(659.25, 1318.5, ms: 320, gain: 0.30),
    _tone(1975.5, ms: 200, gain: 0.20, decay: 10, startMs: 260),
  ]);

  // Level up: G4-C5-E5-G5 fanfare, slightly slower and rounder.
  save('levelup', [
    _chordArp([392.0, 523.25, 659.25, 783.99],
        noteMs: 120, tailMs: 420, gain: 0.32),
  ]);

  stdout.writeln('Wrote 5 sounds to assets/sounds/');
}

/// One enveloped sine (with optional soft harmonics), returned as samples
/// starting at [startMs] into the clip.
({List<double> samples, int startMs}) _tone(
  double freq, {
  required int ms,
  required double gain,
  double decay = 12,
  bool harmonics = false,
  int startMs = 0,
}) {
  final n = (sampleRate * ms / 1000).round();
  final out = List<double>.filled(n, 0);
  const attackMs = 4.0;
  const releaseMs = 6.0;
  final attackN = (sampleRate * attackMs / 1000).round();
  final releaseN =
      math.min((sampleRate * releaseMs / 1000).round(), n);
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    var v = math.sin(2 * math.pi * freq * t);
    if (harmonics) {
      v += 0.30 * math.sin(2 * math.pi * freq * 2 * t) +
          0.12 * math.sin(2 * math.pi * freq * 3 * t);
      v /= 1.42;
    }
    final attack = i < attackN ? i / attackN : 1.0;
    // Release taper: every layer ends AT ZERO regardless of phase —
    // exp() alone leaves an audible step at the buffer edge (clicks).
    final release =
        i >= n - releaseN ? (n - 1 - i) / releaseN : 1.0;
    final env = attack * release * math.exp(-decay * t);
    out[i] = v * env * gain;
  }
  return (samples: out, startMs: startMs);
}

/// Overlapping arpeggio: each note starts [noteMs] after the previous and
/// rings for the remainder of the clip.
({List<double> samples, int startMs}) _chordArp(
  List<double> freqs, {
  required int noteMs,
  required int tailMs,
  required double gain,
}) {
  final totalMs = noteMs * freqs.length + tailMs;
  final n = (sampleRate * totalMs / 1000).round();
  final out = List<double>.filled(n, 0);
  for (var k = 0; k < freqs.length; k++) {
    final start = (sampleRate * noteMs * k / 1000).round();
    final noteLenMs = totalMs - noteMs * k;
    final tone = _tone(freqs[k],
        ms: noteLenMs, gain: gain, decay: 6, harmonics: true);
    for (var i = 0; i < tone.samples.length && start + i < n; i++) {
      out[start + i] += tone.samples[i];
    }
  }
  // Soft-clip safety.
  for (var i = 0; i < n; i++) {
    out[i] = out[i].clamp(-0.85, 0.85);
  }
  return (samples: out, startMs: 0);
}

/// Exponential pitch glide from [f0] to [f1].
({List<double> samples, int startMs}) _gliss(
  double f0,
  double f1, {
  required int ms,
  required double gain,
}) {
  final n = (sampleRate * ms / 1000).round();
  final out = List<double>.filled(n, 0);
  final releaseN = math.min((sampleRate * 6 / 1000).round(), n);
  var phase = 0.0;
  for (var i = 0; i < n; i++) {
    final p = i / n;
    final f = f0 * math.pow(f1 / f0, p);
    phase += 2 * math.pi * f / sampleRate;
    final attack = math.min(1.0, i / (sampleRate * 0.004));
    final release =
        i >= n - releaseN ? (n - 1 - i) / releaseN : 1.0;
    final env = attack * release * math.exp(-4 * p);
    out[i] = math.sin(phase) * env * gain;
  }
  return (samples: out, startMs: 0);
}

void save(String name, List<({List<double> samples, int startMs})> layers) {
  // Mix layers at their offsets.
  var totalN = 0;
  for (final l in layers) {
    final start = (sampleRate * l.startMs / 1000).round();
    totalN = math.max(totalN, start + l.samples.length);
  }
  final mix = List<double>.filled(totalN, 0);
  for (final l in layers) {
    final start = (sampleRate * l.startMs / 1000).round();
    for (var i = 0; i < l.samples.length; i++) {
      mix[start + i] += l.samples[i];
    }
  }

  // Belt-and-braces: a global 5ms fade-out on the mixed tail, so the FILE
  // ends at zero even if a future layer forgets its own release.
  final fadeN = math.min((sampleRate * 5 / 1000).round(), totalN);
  for (var i = totalN - fadeN; i < totalN; i++) {
    mix[i] *= (totalN - 1 - i) / fadeN;
  }

  // PCM16 mono WAV.
  final data = ByteData(44 + totalN * 2);
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + totalN * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little); // fmt chunk size
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // mono
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little); // byte rate
  data.setUint16(32, 2, Endian.little); // block align
  data.setUint16(34, 16, Endian.little); // bits per sample
  ascii(36, 'data');
  data.setUint32(40, totalN * 2, Endian.little);
  for (var i = 0; i < totalN; i++) {
    data.setInt16(
        44 + i * 2, (mix[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
  }

  File('assets/sounds/$name.wav')
      .writeAsBytesSync(data.buffer.asUint8List());
  stdout.writeln('  $name.wav (${(totalN / sampleRate * 1000).round()}ms)');
}
