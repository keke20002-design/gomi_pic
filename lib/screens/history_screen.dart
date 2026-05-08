import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/history_entry.dart';
import '../services/history_service.dart';
import '../widgets/banner_ad_widget.dart';
import 'home_screen.dart' show HistoryTile;
import 'result_screen.dart';

class HistoryTab extends StatefulWidget {
  final ValueListenable<int> version;
  final int adReloadVersion;

  const HistoryTab({
    super.key,
    required this.version,
    this.adReloadVersion = 0,
  });

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final _service = const HistoryService();

  List<HistoryEntry> _entries = [];
  int _monthlyCount = 0;
  String? _topCategory;
  bool _loading = true;
  int _lastVersion = -1;

  @override
  void initState() {
    super.initState();
    _load();
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
      _load();
    }
  }

  Future<void> _load() async {
    final entries = await _service.load();
    final stats = await _service.monthlyStats();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _monthlyCount = stats.count;
      _topCategory = stats.topCategory;
      _loading = false;
    });
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('履歴をすべて削除しますか？'),
        content: const Text('この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _service.clear();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        ..._buildListChildren(context),
        const SizedBox(height: 24),
        BannerAdWidget(reloadVersion: widget.adReloadVersion),
      ],
    );
  }

  List<Widget> _buildListChildren(BuildContext context) {
    return [
        Row(
          children: [
            const Text(
              '履歴',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const Spacer(),
            if (_entries.isNotEmpty)
              TextButton.icon(
                onPressed: _confirmClear,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('全削除'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _StatsHeader(count: _monthlyCount, topCategory: _topCategory),
        const SizedBox(height: 20),
        if (_entries.isEmpty)
          const _HistoryEmptyState()
        else
          ...List.generate(_entries.length, (i) {
            final e = _entries[i];
            return Padding(
              padding: EdgeInsets.only(bottom: i == _entries.length - 1 ? 0 : 8),
              child: HistoryTile(
                entry: e,
                onTap: () {
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
            );
          }),
    ];
  }
}

class _StatsHeader extends StatelessWidget {
  final int count;
  final String? topCategory;

  const _StatsHeader({required this.count, required this.topCategory});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary.withValues(alpha: 0.14),
            primary.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatCell(
              icon: Icons.photo_camera,
              label: '今月の撮影',
              value: '$count 件',
              color: primary,
            ),
          ),
          Container(
            width: 1,
            height: 44,
            color: primary.withValues(alpha: 0.2),
          ),
          Expanded(
            child: _StatCell(
              icon: Icons.leaderboard,
              label: '最多カテゴリ',
              value: topCategory ?? '—',
              color: primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color.withValues(alpha: 0.8),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          const Text(
            'まだ履歴がありません',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'カメラボタンから撮影してみましょう',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
