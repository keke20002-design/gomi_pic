import 'package:flutter/material.dart';

import '../screens/camera_screen.dart';
import '../screens/history_screen.dart';
import '../screens/home_screen.dart';
import '../screens/settings_screen.dart';
import '../services/location_service.dart';
import '../utils/quota_gate.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  final ValueNotifier<int> _historyVersion = ValueNotifier(0);

  /// 各タブに渡す広告リロード番号。タブが再選択されるたびに加算し、
  /// 該当タブの BannerAdWidget が didUpdateWidget で新しい広告を読み込む。
  final List<int> _adReloadVersions = [0, 0, 0];

  void _switchTab(int index) {
    setState(() {
      _currentIndex = index;
      _adReloadVersions[index]++;
    });
  }

  @override
  void dispose() {
    _historyVersion.dispose();
    super.dispose();
  }

  void _switchToHistory() {
    _switchTab(1);
  }

  void _bumpVersion() {
    _historyVersion.value++;
  }

  Future<void> _openCamera() async {
    // 撮影クォータチェック（無料 10 回 / 広告で +3、上限 16）。
    final canCapture = await ensureCaptureQuota(context);
    if (!canCapture || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    String municipality;
    try {
      final result = await const LocationService().getCurrentMunicipality();
      municipality = result.municipality;
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CameraScreen(municipality: municipality),
      ),
    );
    if (!mounted) return;
    _bumpVersion();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _currentIndex,
          children: [
            HomeTab(
              version: _historyVersion,
              onSeeAllHistory: _switchToHistory,
              adReloadVersion: _adReloadVersions[0],
            ),
            HistoryTab(
              version: _historyVersion,
              adReloadVersion: _adReloadVersions[1],
            ),
            SettingsTab(
              onChanged: _bumpVersion,
              adReloadVersion: _adReloadVersions[2],
            ),
          ],
        ),
      ),
      floatingActionButton: _CaptureFab(onPressed: _openCamera),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: SafeArea(
        top: false,
        child: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          padding: EdgeInsets.zero,
          color: theme.colorScheme.surface,
          child: SizedBox(
            height: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavButton(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'ホーム',
                  active: _currentIndex == 0,
                  onPressed: () => _switchTab(0),
                ),
                const SizedBox(width: 56),
                _NavButton(
                  icon: Icons.history_outlined,
                  activeIcon: Icons.history,
                  label: '履歴',
                  active: _currentIndex == 1,
                  onPressed: () => _switchTab(1),
                ),
                _NavButton(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings,
                  label: '設定',
                  active: _currentIndex == 2,
                  onPressed: () => _switchTab(2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onPressed;

  const _NavButton({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = active
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.55);
    return Expanded(
      child: InkWell(
        onTap: onPressed,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? activeIcon : icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptureFab extends StatefulWidget {
  final VoidCallback onPressed;

  const _CaptureFab({required this.onPressed});

  @override
  State<_CaptureFab> createState() => _CaptureFabState();
}

class _CaptureFabState extends State<_CaptureFab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Transform.translate(
      offset: const Offset(0, -6),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onPressed();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary,
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.55),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.camera_alt,
              size: 30,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
