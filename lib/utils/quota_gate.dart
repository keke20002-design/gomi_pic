import 'package:flutter/material.dart';

import '../services/ads.dart';
import '../services/quota_service.dart';

enum _QuotaAction { cancel, watchAd }

/// 撮影前に呼び出してクォータを確認する。
/// 残量があれば true をそのまま返し、無ければ広告視聴ダイアログを出す。
/// ユーザーが広告を見て報酬を獲得すればクォータを追加して true を返す。
/// キャンセル／失敗／上限到達時は false。
Future<bool> ensureCaptureQuota(BuildContext context) async {
  const service = QuotaService();
  var status = await service.read();
  if (status.hasQuota) return true;
  if (!context.mounted) return false;

  if (!status.canBuyMore) {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('本日の撮影上限に達しました'),
        content: Text(
          '本日は${status.used}回撮影されました。\n'
          '1日の上限は${QuotaService.hardCap}回です。明日またご利用ください。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return false;
  }

  final action = await showDialog<_QuotaAction>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('無料分なくなりました'),
      content: Text(
        '広告を見ると、もう${QuotaService.adBoost}回使えます',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _QuotaAction.cancel),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _QuotaAction.watchAd),
          child: const Text('👉 広告を見る'),
        ),
      ],
    ),
  );

  if (action != _QuotaAction.watchAd) return false;
  if (!context.mounted) return false;

  try {
    final shown = await showInterstitialAd();
    if (!shown) return false;
    await service.grantAdUnlock();
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('広告の読み込みに失敗しました: $e'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
    return false;
  }
}
