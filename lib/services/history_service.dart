import 'package:shared_preferences/shared_preferences.dart';

import '../models/classification.dart';
import '../models/history_entry.dart';

class HistoryService {
  static const _key = 'gomi_pic_history';
  static const _maxEntries = 20;

  const HistoryService();

  Future<List<HistoryEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final entries = <HistoryEntry>[];
    for (final s in raw) {
      try {
        entries.add(HistoryEntry.decode(s));
      } catch (_) {
        // スキーマ不一致の古いエントリは無視
      }
    }
    return entries;
  }

  Future<void> add(HistoryEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? [];
    final updated = [entry.encode(), ...existing];
    if (updated.length > _maxEntries) {
      updated.removeRange(_maxEntries, updated.length);
    }
    await prefs.setStringList(_key, updated);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Future<List<MapEntry<String, int>>> topCategories({int limit = 4}) async {
    final entries = await load();
    final counts = <String, int>{};
    for (final e in entries) {
      final label = (e.classification.category ?? GarbageCategory.other).labelJa;
      counts[label] = (counts[label] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).toList();
  }

  Future<List<MapEntry<String, int>>> topItems({int limit = 4}) async {
    final entries = await load();
    final counts = <String, int>{};
    for (final e in entries) {
      final name = e.classification.itemName;
      counts[name] = (counts[name] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).toList();
  }

  Future<({int count, String? topCategory})> monthlyStats() async {
    final entries = await load();
    final now = DateTime.now();
    final monthEntries = entries.where((e) =>
        e.timestamp.year == now.year && e.timestamp.month == now.month);
    final counts = <String, int>{};
    for (final e in monthEntries) {
      final label = (e.classification.category ?? GarbageCategory.other).labelJa;
      counts[label] = (counts[label] ?? 0) + 1;
    }
    String? top;
    var topCount = 0;
    for (final entry in counts.entries) {
      if (entry.value > topCount) {
        top = entry.key;
        topCount = entry.value;
      }
    }
    return (count: monthEntries.length, topCategory: top);
  }
}
