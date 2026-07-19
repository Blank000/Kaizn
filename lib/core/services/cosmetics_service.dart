import 'package:shared_preferences/shared_preferences.dart';

/// Confetti visual styles for celebration moments. `classic` is the default
/// explosive burst everyone starts with; the rest unlock via levels/chests.
enum ConfettiStyle { classic, goldStars, emberRain }

/// One unlockable cosmetic. Cosmetic-ONLY by hard rule — behavior features
/// (queues, timer, stats) are never gated behind progression: the behavior
/// engine is the product.
class Cosmetic {
  final String id;
  final String name;
  final String emoji;

  /// 'confetti' → a ConfettiStyle; 'palette' → an extra milestone color.
  final String kind;

  const Cosmetic(this.id, this.name, this.emoji, this.kind);
}

/// Registry + persistence for cosmetic unlocks (gamification_plan.md §4,
/// Session 2). Unlock sources: every 3rd level-up and weekly chests — both
/// call [unlockNext]. Cosmetics are the inflation-proof payout: they never
/// devalue the user's self-priced reward economy.
class CosmeticsService {
  CosmeticsService._();

  static const _unlockedKey = 'cosmetics_unlocked';
  static const _confettiKey = 'cosmetic_confetti_style';

  /// Ordered unlock track — chests/levels pop the next locked entry.
  static const registry = <Cosmetic>[
    Cosmetic('confetti_gold', 'Gold Rain confetti', '🌟', 'confetti'),
    Cosmetic('palette_lagoon', 'Lagoon milestone color', '🎨', 'palette'),
    Cosmetic('confetti_ember', 'Ember Storm confetti', '🔥', 'confetti'),
    Cosmetic('palette_violet', 'Violet Storm milestone color', '💜', 'palette'),
  ];

  static Future<Set<String>> unlockedIds() async {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList(_unlockedKey) ?? const []).toSet();
  }

  /// Unlock the next locked cosmetic on the track. Returns it, or null when
  /// everything is already unlocked.
  static Future<Cosmetic?> unlockNext() async {
    final p = await SharedPreferences.getInstance();
    final unlocked = (p.getStringList(_unlockedKey) ?? const []).toList();
    for (final c in registry) {
      if (!unlocked.contains(c.id)) {
        unlocked.add(c.id);
        await p.setStringList(_unlockedKey, unlocked);
        return c;
      }
    }
    return null;
  }

  /// Level-ups unlock a cosmetic every 3rd level (3, 6, 9…).
  static Future<Cosmetic?> maybeUnlockForLevel(int level) async {
    if (level % 3 != 0) return null;
    return unlockNext();
  }

  /// Confetti styles the user can pick from (classic + unlocked).
  static Future<List<ConfettiStyle>> availableConfettiStyles() async {
    final unlocked = await unlockedIds();
    return [
      ConfettiStyle.classic,
      if (unlocked.contains('confetti_gold')) ConfettiStyle.goldStars,
      if (unlocked.contains('confetti_ember')) ConfettiStyle.emberRain,
    ];
  }

  static Future<ConfettiStyle> selectedConfettiStyle() async {
    final p = await SharedPreferences.getInstance();
    final name = p.getString(_confettiKey);
    return ConfettiStyle.values
            .where((s) => s.name == name)
            .firstOrNull ??
        ConfettiStyle.classic;
  }

  static Future<void> setConfettiStyle(ConfettiStyle style) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_confettiKey, style.name);
  }

  /// Which extra milestone-palette colors are unlocked (picker gating only —
  /// rendering always resolves any stored index safely via AppColors).
  static Future<Set<String>> unlockedPaletteIds() async {
    final unlocked = await unlockedIds();
    return {
      if (unlocked.contains('palette_lagoon')) 'palette_lagoon',
      if (unlocked.contains('palette_violet')) 'palette_violet',
    };
  }
}
