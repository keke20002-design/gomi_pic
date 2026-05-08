import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/classification.dart';
import '../models/history_entry.dart';
import '../services/history_service.dart';
import '../services/location_service.dart';
import '../services/settings_service.dart';
import '../utils/category_style.dart';
import '../widgets/banner_ad_widget.dart';
import 'result_screen.dart';

class HomeTab extends StatefulWidget {
  final ValueListenable<int> version;
  final VoidCallback onSeeAllHistory;
  final int adReloadVersion;

  const HomeTab({
    super.key,
    required this.version,
    required this.onSeeAllHistory,
    this.adReloadVersion = 0,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _historyService = const HistoryService();
  final _locationService = const LocationService();
  final _settingsService = const SettingsService();

  List<HistoryEntry> _history = [];
  List<MapEntry<String, int>> _topItems = [];
  String? _municipality;
  String? _locationError;
  bool _loadingLocation = true;
  bool _nonJapanDismissed = false;
  int _lastVersion = -1;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadDismissFlag();
    _resolveLocation();
    widget.version.addListener(_onVersionChanged);
  }

  @override
  void dispose() {
    widget.version.removeListener(_onVersionChanged);
    super.dispose();
  }

  void _onVersionChanged() {
    if (widget.version.value != _lastVersion) {
      _lastVersion = widget.version.value;
      _loadHistory();
      _resolveLocation();
    }
  }

  Future<void> _loadHistory() async {
    final entries = await _historyService.load();
    final items = await _historyService.topItems(limit: 5);
    if (!mounted) return;
    setState(() {
      _history = entries;
      _topItems = items;
    });
  }

  Future<void> _loadDismissFlag() async {
    final dismissed = await _settingsService.isNonJapanNoticeDismissed();
    if (!mounted) return;
    setState(() => _nonJapanDismissed = dismissed);
  }

  Future<void> _resolveLocation() async {
    setState(() {
      _loadingLocation = true;
      _locationError = null;
    });
    try {
      final result = await _locationService.getCurrentMunicipality();
      if (!mounted) return;
      setState(() {
        _municipality = result.municipality;
        _loadingLocation = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationError = e.toString();
        _loadingLocation = false;
      });
    }
  }

  Future<void> _dismissNonJapanNotice() async {
    await _settingsService.dismissNonJapanNotice();
    if (!mounted) return;
    setState(() => _nonJapanDismissed = true);
  }

  void _openItem(String itemName) {
    final entry = _history
        .where((e) => e.classification.itemName == itemName)
        .firstOrNull;
    if (entry == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          classification: entry.classification,
          imagePath: entry.imagePath,
          readOnly: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recent = _history.take(3).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      children: [
        const _HeroHeader(),
        const SizedBox(height: 18),
        _LocationChip(
          municipality: _municipality,
          error: _locationError,
          loading: _loadingLocation,
          nonJapanDismissed: _nonJapanDismissed,
          onRetry: _resolveLocation,
          onDismissNonJapan: _dismissNonJapanNotice,
        ),
        const SizedBox(height: 22),
        _TipCard(municipality: _municipality),
        const SizedBox(height: 28),
        _FavoritesSection(
          topItems: _topItems,
          onTapItem: _openItem,
        ),
        const SizedBox(height: 28),
        _HistorySection(
          history: recent,
          hasMore: _history.length > recent.length,
          onSeeAll: widget.onSeeAllHistory,
          onTapEntry: (e) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ResultScreen(
                  classification: e.classification,
                  imagePath: e.imagePath,
                  readOnly: true,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        BannerAdWidget(reloadVersion: widget.adReloadVersion),
      ],
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.eco,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'ゴミチェック',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'ゴミを撮るだけで分別完了',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _LocationChip extends StatelessWidget {
  final String? municipality;
  final String? error;
  final bool loading;
  final bool nonJapanDismissed;
  final VoidCallback onRetry;
  final VoidCallback onDismissNonJapan;

  const _LocationChip({
    required this.municipality,
    required this.error,
    required this.loading,
    required this.nonJapanDismissed,
    required this.onRetry,
    required this.onDismissNonJapan,
  });

  bool get _isNonJapanError =>
      error != null && error!.contains('日本の自治体専用');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    if (loading) {
      return _chipShell(
        bg: theme.colorScheme.surfaceContainerHighest,
        fg: theme.colorScheme.onSurfaceVariant,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('位置情報を取得中', style: TextStyle(fontSize: 13)),
          ],
        ),
      );
    }

    if (error != null) {
      if (_isNonJapanError && nonJapanDismissed) {
        return const SizedBox.shrink();
      }
      if (_isNonJapanError) {
        return _chipShell(
          bg: theme.colorScheme.surfaceContainerHighest,
          fg: theme.colorScheme.onSurfaceVariant,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, size: 14),
              const SizedBox(width: 6),
              const Text(
                '日本国内でご利用ください',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: onDismissNonJapan,
                borderRadius: BorderRadius.circular(999),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 14),
                ),
              ),
            ],
          ),
        );
      }
      return _chipShell(
        bg: theme.colorScheme.errorContainer.withValues(alpha: 0.6),
        fg: theme.colorScheme.onErrorContainer,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 14),
            const SizedBox(width: 6),
            const Text(
              '位置情報が取得できません',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 2),
            InkWell(
              onTap: onRetry,
              borderRadius: BorderRadius.circular(999),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.refresh, size: 16),
              ),
            ),
          ],
        ),
      );
    }

    return _chipShell(
      bg: primary.withValues(alpha: 0.12),
      fg: primary,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on, size: 16, color: primary),
          const SizedBox(width: 6),
          Text(
            municipality ?? '不明',
            style: TextStyle(
              color: primary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipShell({
    required Color bg,
    required Color fg,
    required Widget child,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: fg),
          child: IconTheme(
            data: IconThemeData(color: fg),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final String? municipality;
  const _TipCard({required this.municipality});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final label = municipality ?? 'お住まいの地域';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary.withValues(alpha: 0.10),
            primary.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates, size: 18, color: primary),
              const SizedBox(width: 6),
              Text(
                '$label の分別ポイント',
                style: TextStyle(
                  color: primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'ペットボトル',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          _bullet('キャップ・ラベルを外す'),
          const SizedBox(height: 4),
          _bullet('軽くすすぐ'),
          const SizedBox(height: 4),
          _bullet('資源ごみへ'),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Text('👉 ', style: TextStyle(fontSize: 13)),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, height: 1.55),
          ),
        ),
      ],
    );
  }
}

class _FavoritesSection extends StatelessWidget {
  final List<MapEntry<String, int>> topItems;
  final ValueChanged<String> onTapItem;

  const _FavoritesSection({
    required this.topItems,
    required this.onTapItem,
  });

  static const _fallback = <_QuickItem>[
    _QuickItem('ペットボトル', Icons.local_drink),
    _QuickItem('缶', Icons.liquor),
    _QuickItem('段ボール', Icons.inventory_2),
    _QuickItem('プラ', Icons.kitchen),
    _QuickItem('ビン', Icons.wine_bar),
  ];

  IconData _iconFor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('ペットボトル') || lower.contains('ボトル')) {
      return Icons.local_drink;
    }
    if (lower.contains('缶') ||
        lower.contains('アルミ') ||
        lower.contains('スチール')) {
      return Icons.liquor;
    }
    if (lower.contains('段ボール') ||
        lower.contains('ダンボール') ||
        lower.contains('紙')) {
      return Icons.inventory_2;
    }
    if (lower.contains('プラ')) return Icons.kitchen;
    if (lower.contains('ビン') ||
        lower.contains('瓶') ||
        lower.contains('ガラス')) {
      return Icons.wine_bar;
    }
    if (lower.contains('電池')) return Icons.battery_full;
    if (lower.contains('布') || lower.contains('衣')) return Icons.checkroom;
    if (lower.contains('スマホ') ||
        lower.contains('スマートフォン') ||
        lower.contains('携帯')) {
      return Icons.smartphone;
    }
    if (lower.contains('電子') ||
        lower.contains('家電') ||
        lower.contains('コード')) {
      return Icons.devices_other;
    }
    return Icons.label_outline;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasReal = topItems.isNotEmpty;
    final items = hasReal
        ? topItems.map((e) => _QuickItem(e.key, _iconFor(e.key))).toList()
        : _fallback;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'よく捨てるもの',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            if (hasReal)
              Icon(Icons.star, size: 14, color: theme.colorScheme.primary),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final item = items[i];
              return _QuickItemChip(
                item: item,
                enabled: hasReal,
                onTap: hasReal ? () => onTapItem(item.label) : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _QuickItemChip extends StatelessWidget {
  final _QuickItem item;
  final bool enabled;
  final VoidCallback? onTap;

  const _QuickItemChip({
    required this.item,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: enabled
                  ? primary.withValues(alpha: 0.35)
                  : theme.colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(item.icon, size: 16, color: primary),
              ),
              const SizedBox(width: 8),
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickItem {
  final String label;
  final IconData icon;
  const _QuickItem(this.label, this.icon);
}

class _HistorySection extends StatelessWidget {
  final List<HistoryEntry> history;
  final bool hasMore;
  final VoidCallback onSeeAll;
  final ValueChanged<HistoryEntry> onTapEntry;

  const _HistorySection({
    required this.history,
    required this.hasMore,
    required this.onSeeAll,
    required this.onTapEntry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '最近の記録',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            if (hasMore || history.isNotEmpty)
              TextButton(
                onPressed: onSeeAll,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'もっと見る →',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (history.isEmpty)
          const _EmptyState()
        else
          ...List.generate(history.length, (i) {
            final e = history[i];
            return Padding(
              padding: EdgeInsets.only(bottom: i == history.length - 1 ? 0 : 10),
              child: HistoryTile(entry: e, onTap: () => onTapEntry(e)),
            );
          }),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(Icons.delete_outline, size: 36, color: primary),
          ),
          const SizedBox(height: 16),
          const Text(
            'ゴミを撮るだけで\n分別方法がすぐわかります',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '下のボタンから始めてみましょう',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class HistoryTile extends StatelessWidget {
  final HistoryEntry entry;
  final VoidCallback onTap;

  const HistoryTile({super.key, required this.entry, required this.onTap});

  String _formatTimestamp(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final diffDays = today.difference(day).inDays;
    final time = DateFormat('HH:mm').format(t);
    if (diffDays == 0) return '今日 $time';
    if (diffDays == 1) return '昨日 $time';
    return DateFormat('M月d日 HH:mm', 'ja_JP').format(t);
  }

  @override
  Widget build(BuildContext context) {
    final c = entry.classification;
    final theme = Theme.of(context);
    final catColor = categoryColor(c.category ?? GarbageCategory.other);
    final catLabel = (c.category ?? GarbageCategory.other).labelJa;
    final dateText = _formatTimestamp(entry.timestamp);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: catColor,
                child: Text(
                  catLabel.characters.first,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.itemName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: catColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          catLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: catColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            '  ・  $dateText',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
