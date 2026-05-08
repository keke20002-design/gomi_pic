import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'widgets/main_scaffold.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await initializeDateFormatting('ja_JP');
  // BannerAd が初期化前に load されないよう完了を待つ。
  await MobileAds.instance.initialize();
  runApp(const GomiPicApp());
}

class GomiPicApp extends StatelessWidget {
  const GomiPicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ゴミチェック',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFFBF9F3),
        useMaterial3: true,
      ),
      locale: const Locale('ja', 'JP'),
      supportedLocales: const [Locale('ja', 'JP')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const MainScaffold(),
      debugShowCheckedModeBanner: false,
    );
  }
}
