import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob 本番広告ユニット ID（ユーザー指定）。
/// 注: デバッグ中でも本番広告を要求する。自己クリック／自己インプレッションは
/// AdMob ポリシー違反になるため、動作確認時は広告をタップしないこと。
class AdIds {
  static const String banner = 'ca-app-pub-5381891295736795/1746711022';
  static const String rewardedInterstitial =
      'ca-app-pub-5381891295736795/1803692989';
}

/// 報酬型インタースティシャル広告を 1 回分ロード＆表示する。
/// AdMob 側のユニット種別が「Rewarded Interstitial」のため [RewardedInterstitialAd] を使用。
/// ただし報酬到達（[onUserEarnedReward]）を待たず、広告が表示開始されれば閉じた時点で [true]
/// を返す。5 秒後のスキップボタンで閉じても unlock できる。
Future<bool> showInterstitialAd() async {
  final completer = Completer<bool>();
  var shown = false;

  RewardedInterstitialAd.load(
    adUnitId: AdIds.rewardedInterstitial,
    request: const AdRequest(),
    rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
      onAdLoaded: (ad) {
        ad.fullScreenContentCallback = FullScreenContentCallback(
          onAdShowedFullScreenContent: (_) {
            shown = true;
          },
          onAdDismissedFullScreenContent: (ad) {
            ad.dispose();
            if (!completer.isCompleted) completer.complete(shown);
          },
          onAdFailedToShowFullScreenContent: (ad, error) {
            ad.dispose();
            if (!completer.isCompleted) completer.completeError(error);
          },
        );
        ad.show(
          onUserEarnedReward: (_, reward) {
            // 報酬達成フラグは使わず、閉じた時点で unlock を許可するため無視。
          },
        );
      },
      onAdFailedToLoad: (error) {
        if (!completer.isCompleted) completer.completeError(error);
      },
    ),
  );

  return completer.future;
}
