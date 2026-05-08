import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/classification.dart';
import '../services/gemini_service.dart';
import '../services/quota_service.dart';
import '../utils/quota_gate.dart';
import '../widgets/safe_scaffold.dart';
import 'result_screen.dart';

class CameraScreen extends StatefulWidget {
  final String municipality;
  const CameraScreen({super.key, required this.municipality});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _initializing = true;
  bool _capturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    if (!mounted) return;
    setState(() {
      _initializing = true;
      _error = null;
    });
    try {
      final status = await Permission.camera.request();
      if (status != PermissionStatus.granted) {
        throw Exception(
          'カメラの許可が必要です。設定 > アプリ > ゴミチェック から「カメラ」を許可してください。',
        );
      }
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('利用可能なカメラが見つかりません');
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _initializing = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) {
      return;
    }
    // 毎ショット前にクォータ確認（広告視聴で追加も可）。
    final canCapture = await ensureCaptureQuota(context);
    if (!canCapture || !mounted) return;

    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      // 撮影成功時のみカウントアップ。
      await const QuotaService().recordCapture();
      if (!mounted) return;
      // ストリーミング判定: HTTP は ResultScreen が subscribe した時点で開始。
      // 履歴保存も ResultScreen 側で最終結果が揃ったときに 1 度だけ行う。
      final stream = GeminiService().classifyStream(
        image: File(file.path),
        municipality: widget.municipality,
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            classification:
                Classification.partial(municipality: widget.municipality),
            imagePath: file.path,
            stream: stream,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _capturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('エラー: $e'),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeScaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('撮影'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        color: Colors.black,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _capture,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  color: _capturing ? Colors.grey : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _initCamera);
    }
    final controller = _controller;
    if (_initializing || controller == null || !controller.value.isInitialized) {
      return const _InitializingState();
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: CameraPreview(controller),
          ),
        ),
        if (_capturing) const _CapturingOverlay(),
      ],
    );
  }
}

class _InitializingState extends StatelessWidget {
  const _InitializingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'カメラを起動しています...',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off,
                color: Colors.white70, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('再試行'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: openAppSettings,
              child: const Text(
                'アプリ設定を開く',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapturingOverlay extends StatelessWidget {
  const _CapturingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black87,
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 4,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'AIが分別を判定しています...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '通信環境により30秒ほどかかることがあります',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
