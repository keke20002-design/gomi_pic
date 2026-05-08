import 'package:flutter/material.dart';

import '../services/settings_service.dart';
import '../widgets/banner_ad_widget.dart';

class SettingsTab extends StatefulWidget {
  final VoidCallback onChanged;
  final int adReloadVersion;

  const SettingsTab({
    super.key,
    required this.onChanged,
    this.adReloadVersion = 0,
  });

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final _service = const SettingsService();
  final _controller = TextEditingController();

  bool _manual = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final value = await _service.getManualMunicipality();
    if (!mounted) return;
    setState(() {
      _manual = value != null;
      _controller.text = value ?? '';
      _loading = false;
    });
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (_manual && text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('自治体名を入力してください')),
      );
      return;
    }
    await _service.setManualMunicipality(_manual ? text : null);
    if (!mounted) return;
    widget.onChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_manual ? '保存しました ($text)' : '自動 (GPS) に戻しました'),
        duration: const Duration(seconds: 2),
      ),
    );
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
        const Text(
          '設定',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 20),
        _SectionLabel(icon: Icons.location_on, label: '現在地設定'),
        const SizedBox(height: 8),
        _Card(
          child: Column(
            children: [
              RadioGroup<bool>(
                groupValue: _manual,
                onChanged: (v) => setState(() => _manual = v ?? false),
                child: const Column(
                  children: [
                    RadioListTile<bool>(
                      value: false,
                      title: Text('自動 (GPS)'),
                      subtitle: Text('現在地から自治体を判定します'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<bool>(
                      value: true,
                      title: Text('手動で指定'),
                      subtitle: Text('例: 渋谷区、横浜市'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              if (_manual) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: '自治体名を入力',
                    prefixIcon: Icon(Icons.edit_location_alt),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('保存'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SectionLabel(icon: Icons.tune, label: 'その他'),
        const SizedBox(height: 8),
        _Card(
          child: Column(
            children: [
              _DisabledRow(
                icon: Icons.notifications_outlined,
                title: '通知',
                subtitle: '収集日前日にお知らせ',
                trailingLabel: 'Coming soon',
              ),
              Divider(height: 1, color: Theme.of(context).dividerColor),
              _DisabledRow(
                icon: Icons.language,
                title: '言語',
                subtitle: '日本語 / English / 한국어',
                trailingLabel: 'Coming soon',
              ),
            ],
          ),
        ),
    ];
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.primary,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}

class _DisabledRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String trailingLabel;

  const _DisabledRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailingLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final faded = theme.colorScheme.onSurface.withValues(alpha: 0.4);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: false,
      leading: Icon(icon, color: faded),
      title: Text(title, style: TextStyle(color: faded)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: faded, fontSize: 12),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          trailingLabel,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
