import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ads.dart';

/// AdMob バナー。[reloadVersion] が変わるたびに広告を再読み込みする。
class BannerAdWidget extends StatefulWidget {
  final int reloadVersion;

  const BannerAdWidget({super.key, this.reloadVersion = 0});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant BannerAdWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadVersion != widget.reloadVersion) {
      _load();
    }
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  void _load() {
    _ad?.dispose();
    setState(() {
      _ad = null;
      _loaded = false;
    });
    final ad = BannerAd(
      adUnitId: AdIds.banner,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _ad = null;
            _loaded = false;
          });
          if (kDebugMode) {
            debugPrint('[BannerAd] failed: $error');
          }
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  Widget build(BuildContext context) {
    // 読み込み前後で高さが跳ねないように 50dp を固定確保。
    return SizedBox(
      width: double.infinity,
      height: AdSize.banner.height.toDouble(),
      child: _loaded && _ad != null
          ? AdWidget(ad: _ad!)
          : const SizedBox.shrink(),
    );
  }
}
