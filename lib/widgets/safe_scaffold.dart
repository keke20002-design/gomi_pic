import 'package:flutter/material.dart';

/// Scaffold wrapper that always respects the system navigation bar area.
/// CLAUDE.md requirement: 하단 네비게이션 바가 시스템 홈/뒤로 버튼 영역과 겹치지 않도록.
class SafeScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Color? backgroundColor;

  const SafeScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      backgroundColor: backgroundColor,
      body: SafeArea(
        top: appBar == null,
        bottom: bottomNavigationBar == null,
        child: body,
      ),
      bottomNavigationBar: bottomNavigationBar == null
          ? null
          : SafeArea(top: false, child: bottomNavigationBar!),
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
    );
  }
}
