import 'package:shared_preferences/shared_preferences.dart';

/// 1 日あたりの撮影回数クォータ管理。
/// 無料枠: [freeLimit] 回。超過後は広告視聴 1 回につき [adBoost] 回追加。
/// 1 日の上限は [hardCap] 回（広告追加は最大 [maxAdUnlocks] 回まで）。
class QuotaService {
  static const int freeLimit = 10;
  static const int adBoost = 3;
  static const int hardCap = 16;
  static const int maxAdUnlocks = (hardCap - freeLimit) ~/ adBoost; // 2

  static const _dateKey = 'capture_quota_date';
  static const _usedKey = 'capture_quota_used';
  static const _adUnlockKey = 'capture_quota_ad_unlocks';

  const QuotaService();

  Future<QuotaStatus> read() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureToday(prefs);
    return QuotaStatus(
      used: prefs.getInt(_usedKey) ?? 0,
      adUnlocks: prefs.getInt(_adUnlockKey) ?? 0,
    );
  }

  Future<QuotaStatus> recordCapture() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureToday(prefs);
    final used = (prefs.getInt(_usedKey) ?? 0) + 1;
    await prefs.setInt(_usedKey, used);
    return QuotaStatus(
      used: used,
      adUnlocks: prefs.getInt(_adUnlockKey) ?? 0,
    );
  }

  Future<QuotaStatus> grantAdUnlock() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureToday(prefs);
    final current = prefs.getInt(_adUnlockKey) ?? 0;
    final next = current >= maxAdUnlocks ? current : current + 1;
    await prefs.setInt(_adUnlockKey, next);
    return QuotaStatus(
      used: prefs.getInt(_usedKey) ?? 0,
      adUnlocks: next,
    );
  }

  /// 日付が変わっていればカウンタをリセット。
  Future<void> _ensureToday(SharedPreferences prefs) async {
    final today = _today();
    if (prefs.getString(_dateKey) != today) {
      await prefs.setString(_dateKey, today);
      await prefs.setInt(_usedKey, 0);
      await prefs.setInt(_adUnlockKey, 0);
    }
  }

  static String _today() {
    final n = DateTime.now();
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    return '${n.year}-$m-$d';
  }
}

class QuotaStatus {
  final int used;
  final int adUnlocks;

  const QuotaStatus({required this.used, required this.adUnlocks});

  int get allowed {
    final a = QuotaService.freeLimit + adUnlocks * QuotaService.adBoost;
    return a > QuotaService.hardCap ? QuotaService.hardCap : a;
  }

  int get remaining {
    final r = allowed - used;
    return r < 0 ? 0 : r;
  }

  bool get hasQuota => used < allowed;

  bool get canBuyMore => adUnlocks < QuotaService.maxAdUnlocks;
}
