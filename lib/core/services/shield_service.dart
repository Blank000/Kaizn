import 'package:shared_preferences/shared_preferences.dart';

/// Tracks points spent on Streak Shields.
/// Used by totalPointsProvider to subtract from the balance.
class ShieldService {
  static const _key = 'shield_total_spent';
  static const shieldCost = 50;

  static Future<int> getTotalSpent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key) ?? 0;
  }

  static Future<void> useShield() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_key) ?? 0;
    await prefs.setInt(_key, current + shieldCost);
  }
}
