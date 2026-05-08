import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/classification.dart';
import '../models/history_entry.dart';
import '../services/ads.dart';
import '../services/gemini_service.dart';
import '../services/history_service.dart';
import '../utils/category_style.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/safe_scaffold.dart';

class ResultScreen extends StatefulWidget {
  final Classification classification;
  final String? imagePath;
  final bool readOnly;
  final Stream<Classification>? stream;

  const ResultScreen({
    super.key,
    required this.classification,
    this.imagePath,
    this.readOnly = false,
    this.stream,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late Classification _classification = widget.classification;
  bool _reclassifying = false;
  StreamSubscription<Classification>? _sub;
  bool _historySaved = false;
  String? _streamError;
  bool _notesUnlocked = false;
  bool _loadingRewardedAd = false;

  @override
  void initState() {
    super.initState();
    final stream = widget.stream;
    if (stream != null) {
      _sub = stream.listen(
        (c) {
          if (!mounted) return;
          setState(() => _classification = c);
          if (c.isComplete) _saveHistoryOnce();
        },
        onError: (Object e) {
          if (!mounted) return;
          setState(() => _streamError = e.toString());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('エラー: $e'),
              duration: const Duration(seconds: 6),
            ),
          );
        },
      );
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _saveHistoryOnce() async {
    if (_historySaved || widget.readOnly) return;
    final path = widget.imagePath;
    if (path == null) return;
    _historySaved = true;
    await const HistoryService().add(HistoryEntry(
      id: const Uuid().v4(),
      timestamp: DateTime.now(),
      classification: _classification,
      imagePath: path,
    ));
  }

  Widget _buildNotesSection(Classification c, bool streaming) {
    const accent = Color(0xFFEF6C00);
    // 履歴からの再表示はすでに一度表示済みなのでロックしない。
    final shouldLock =
        !widget.readOnly && !_notesUnlocked && c.isComplete && c.hasNotes;
    if (shouldLock) {
      return _RewardedNotesGate(
        accent: accent,
        loading: _loadingRewardedAd,
        onTap: _unlockNotesViaAd,
      );
    }
    return _InfoCard(
      icon: Icons.warning_amber_rounded,
      title: '注意事項',
      body: c.notes,
      accent: accent,
      streaming: streaming && !c.hasNotes,
    );
  }

  Future<void> _unlockNotesViaAd() async {
    if (_loadingRewardedAd || _notesUnlocked) return;
    setState(() => _loadingRewardedAd = true);
    try {
      final shown = await showInterstitialAd();
      if (!mounted) return;
      if (shown) {
        setState(() => _notesUnlocked = true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('広告の読み込みに失敗しました: $e'),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingRewardedAd = false);
    }
  }

  Future<void> _compareOther() async {
    final path = widget.imagePath;
    if (path == null) return;
    final input = await showDialog<String>(
      context: context,
      builder: (_) => const _CompareDialog(),
    );
    if (input == null || input.trim().isEmpty) return;
    if (!mounted) return;
    // 進行中のストリームがあれば、別地域判定と競合させないためキャンセル。
    await _sub?.cancel();
    _sub = null;
    setState(() => _reclassifying = true);
    try {
      final next = await GeminiService().classify(
        image: File(path),
        municipality: input.trim(),
      );
      if (!mounted) return;
      if (!widget.readOnly) {
        await const HistoryService().add(HistoryEntry(
          id: const Uuid().v4(),
          timestamp: DateTime.now(),
          classification: next,
          imagePath: path,
        ));
      }
      if (!mounted) return;
      setState(() => _classification = next);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $e')),
      );
    } finally {
      if (mounted) setState(() => _reclassifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _classification;
    final theme = Theme.of(context);
    final streaming = !c.isComplete && _streamError == null;

    return SafeScaffold(
      appBar: AppBar(
        title: const Text('分別結果'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              if (widget.imagePath != null &&
                  File(widget.imagePath!).existsSync())
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    File(widget.imagePath!),
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 16),
              if (streaming) const _StreamingBanner(),
              if (streaming) const SizedBox(height: 12),
              if (c.hasCategory)
                _CategoryBadge(category: c.category!)
              else if (streaming)
                const _SkeletonPill(width: 80)
              else
                _CategoryBadge(category: GarbageCategory.other),
              const SizedBox(height: 12),
              c.hasItemName
                  ? Text(
                      c.itemName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    )
                  : const _SkeletonLine(width: 200, height: 26),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.location_on,
                      size: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  const SizedBox(width: 4),
                  Text(
                    c.municipality,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton.icon(
                    onPressed: _reclassifying ? null : _compareOther,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.compare_arrows, size: 16),
                    label: const Text(
                      '別の地域で調べる',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _InfoCard(
                icon: Icons.recycling,
                title: '出し方',
                body: c.disposalMethod,
                accent: const Color(0xFF4CAF50),
                streaming: streaming && !c.hasDisposalMethod,
              ),
              const SizedBox(height: 12),
              _InfoCard(
                icon: Icons.event,
                title: '収集日',
                body: c.collectionDay,
                accent: const Color(0xFF2196F3),
                streaming: streaming && !c.hasCollectionDay,
              ),
              const SizedBox(height: 12),
              _buildNotesSection(c, streaming),
              const SizedBox(height: 24),
              const BannerAdWidget(),
              const SizedBox(height: 96),
            ],
          ),
          if (_reclassifying)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                alignment: Alignment.center,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      '別の地域で再分類しています...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _StickyHomeButton(
        onPressed: () {
          if (widget.readOnly) {
            Navigator.of(context).pop();
          } else {
            Navigator.of(context).popUntil((r) => r.isFirst);
          }
        },
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final GarbageCategory category;
  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(category);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          category.labelJa,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 13,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color accent;
  final bool streaming;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
    this.streaming = false,
  });

  @override
  State<_InfoCard> createState() => _InfoCardState();
}

class _InfoCardState extends State<_InfoCard> {
  bool _expanded = false;

  String _summary(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return '情報なし';
    final end = trimmed.indexOf('。');
    if (end == -1 || end >= trimmed.length - 1) return trimmed;
    return trimmed.substring(0, end + 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = widget.body.trim();
    final summary = _summary(body);
    final hasMore = body.length > summary.length && !widget.streaming;
    final display = _expanded ? body : summary;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: hasMore ? () => setState(() => _expanded = !_expanded) : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: widget.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(widget.icon, size: 18, color: widget.accent),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: widget.accent,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(),
                  if (widget.streaming)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.accent.withValues(alpha: 0.6),
                      ),
                    )
                  else if (hasMore)
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: widget.accent,
                      size: 22,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                alignment: Alignment.topLeft,
                child: widget.streaming && body.isEmpty
                    ? const _SkeletonLine(width: double.infinity, height: 14)
                    : Text(
                        display,
                        style: const TextStyle(fontSize: 14, height: 1.55),
                      ),
              ),
              if (hasMore && !_expanded) ...[
                const SizedBox(height: 6),
                Text(
                  '詳しく見る ▾',
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StickyHomeButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _StickyHomeButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        height: 52,
        child: FilledButton.icon(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          icon: const Icon(Icons.home_outlined, size: 20),
          label: const Text('ホームに戻る'),
        ),
      ),
    );
  }
}

class _CompareDialog extends StatefulWidget {
  const _CompareDialog();

  @override
  State<_CompareDialog> createState() => _CompareDialogState();
}

class _CompareDialogState extends State<_CompareDialog> {
  final _controller = TextEditingController();
  static const _presets = ['渋谷区', '横浜市', '大阪市', '名古屋市', '札幌市', '福岡市'];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('別の地域で調べる'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '例: 横浜市、渋谷区',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) => Navigator.of(context).pop(v),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final name in _presets)
                  ActionChip(
                    label: Text(name),
                    onPressed: () => Navigator.of(context).pop(name),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('調べる'),
        ),
      ],
    );
  }
}

class _StreamingBanner extends StatelessWidget {
  const _StreamingBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'AIが分別を判定中...結果が順次表示されます',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  final double width;
  final double height;
  const _SkeletonLine({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

class _SkeletonPill extends StatelessWidget {
  final double width;
  const _SkeletonPill({required this.width});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: width,
        height: 26,
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

/// 注意事項を報酬型広告視聴後にアンロックするゲート。
class _RewardedNotesGate extends StatelessWidget {
  final Color accent;
  final bool loading;
  final VoidCallback onTap;

  const _RewardedNotesGate({
    required this.accent,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '注意事項',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: accent,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.lock_outline, size: 18, color: accent),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    if (loading)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: accent,
                        ),
                      )
                    else
                      Icon(Icons.live_tv, size: 22, color: accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        loading ? '広告を読み込んでいます...' : 'ちょっと広告見て、結果を見よう',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ),
                    if (!loading)
                      Icon(Icons.chevron_right, size: 20, color: accent),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '動画を最後まで視聴すると表示されます',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
