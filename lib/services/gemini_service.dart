import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/classification.dart';
import 'image_compression.dart';

/// Gemini を直接 REST で呼び出し、Google Search Grounding を有効化する。
/// google_generative_ai Dart SDK は現行バージョンで google_search ツールを露出していないため REST で実装。
/// 2.x 系では tool 名は google_search（1.5 系の google_search_retrieval は非対応）。
class GeminiService {
  static const _model = 'gemini-flash-latest';
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';
  static const _streamEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:streamGenerateContent';
  static const _maxAttempts = 3;

  static String? _cachedKey;

  final http.Client _client;
  GeminiService({http.Client? client}) : _client = client ?? http.Client();

  Future<String> _fetchApiKey() async {
    if (_cachedKey != null) return _cachedKey!;
    final serverUrl = dotenv.env['SERVER_URL'] ?? '';
    if (serverUrl.isEmpty) {
      throw const GeminiException('SERVER_URL が .env に設定されていません');
    }
    final response = await _client.get(Uri.parse('$serverUrl/gemini-key'));
    if (response.statusCode != 200) {
      throw GeminiException('API キー取得失敗: ${response.statusCode}');
    }
    _cachedKey = (jsonDecode(response.body) as Map<String, dynamic>)['api_key'] as String;
    return _cachedKey!;
  }

  Future<Classification> classify({
    required File image,
    required String municipality,
  }) async {
    final imageBytes = await compressForUpload(image);
    final imageBase64 = base64Encode(imageBytes);

    final prompt = '''
あなたは日本のゴミ分別コンシェルジュです。
写真のゴミを識別し、「$municipality」の公式ルールに基づき分別方法を返してください。
Google検索で最新の自治体情報を参照してください。不明な点は推測せず「要確認」と書いてください。

必ず次のJSON形式のみで回答してください（説明文やコードブロックは不要）:
{
  "itemName": "品目名",
  "category": "可燃|不燃|資源|粗大|その他のいずれか",
  "disposalMethod": "具体的な出し方",
  "collectionDay": "収集曜日または頻度",
  "notes": "注意事項"
} 
''';

    final body = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': 'image/jpeg',
                'data': imageBase64,
              }
            },
          ]
        }
      ],
      'tools': [
        {'google_search': {}}
      ],
      'generationConfig': {
        'temperature': 0.2,
      }
    };

    final apiKey = await _fetchApiKey();
    final uri = Uri.parse('$_endpoint?key=$apiKey');
    final response = await _postWithRetry(uri, jsonEncode(body));

    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final text = _extractText(decoded);
    final classJson = _parseJsonFromText(text);
    return Classification.fromJson(classJson, municipality);
  }

  /// 撮影 → AI 判定までの体感待ち時間を縮めるためのストリーミング版。
  /// SSE で受信したテキストから、JSON フィールドが確定するたびに部分結果を emit する。
  /// 最後に完全な [Classification] （isComplete=true）を必ず 1 度 emit する。
  Stream<Classification> classifyStream({
    required File image,
    required String municipality,
  }) async* {
    final imageBytes = await compressForUpload(image);
    final imageBase64 = base64Encode(imageBytes);
    final body = jsonEncode(_buildRequestBody(imageBase64, municipality));

    final apiKey = await _fetchApiKey();
    final uri = Uri.parse('$_streamEndpoint?alt=sse&key=$apiKey');
    final request = http.Request('POST', uri)
      ..headers['Content-Type'] = 'application/json'
      ..body = body;

    http.StreamedResponse response;
    try {
      response = await _client
          .send(request)
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const GeminiException(
        '応答が30秒以内に始まりませんでした。通信環境を確認して再試行してください。',
      );
    }

    if (response.statusCode != 200) {
      final bodyText = await response.stream.bytesToString();
      throw GeminiException(
        'Gemini API エラー (${response.statusCode}): $bodyText',
      );
    }

    final buffer = StringBuffer();
    final emitted = <String>{};
    Classification partial = Classification.partial(municipality: municipality);

    final lineStream = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .timeout(const Duration(seconds: 90));

    try {
      await for (final line in lineStream) {
        if (!line.startsWith('data:')) continue;
        final payload = line.substring(5).trim();
        if (payload.isEmpty || payload == '[DONE]') continue;

        Map<String, dynamic> chunk;
        try {
          chunk = jsonDecode(payload) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }
        final text = _extractText(chunk);
        if (text.isEmpty) continue;
        buffer.write(text);

        final next = _extractPartial(buffer.toString(), partial, emitted);
        if (next != null) {
          partial = next;
          yield partial;
        }
      }
    } on TimeoutException {
      throw const GeminiException(
        '応答が90秒以内に完了しませんでした。通信環境を確認して再試行してください。',
      );
    }

    final fullText = buffer.toString();
    try {
      final classJson = _parseJsonFromText(fullText);
      yield Classification.fromJson(classJson, municipality);
    } catch (e) {
      // パース失敗時は部分結果が 1 件でも emit 済みなら isComplete=false のまま終了。
      // まったく emit されていなければエラーを投げる。
      if (emitted.isEmpty) {
        throw GeminiException('Gemini 応答が JSON ではありません: $fullText');
      }
      rethrow;
    }
  }

  Map<String, dynamic> _buildRequestBody(String imageBase64, String municipality) {
    final prompt = '''
あなたは日本のゴミ分別コンシェルジュです。
写真のゴミを識別し、「$municipality」の公式ルールに基づき分別方法を返してください。
Google検索で最新の自治体情報を参照してください。不明な点は推測せず「要確認」と書いてください。

必ず次のJSON形式のみで回答してください（説明文やコードブロックは不要）:
{
  "itemName": "品目名",
  "category": "可燃|不燃|資源|粗大|その他のいずれか",
  "disposalMethod": "具体的な出し方",
  "collectionDay": "収集曜日または頻度",
  "notes": "注意事項"
}
''';
    return {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': 'image/jpeg',
                'data': imageBase64,
              }
            },
          ]
        }
      ],
      'tools': [
        {'google_search': {}}
      ],
      'generationConfig': {
        'temperature': 0.2,
      }
    };
  }

  /// バッファ内で「閉じ終わった文字列値」として確定した JSON フィールドを抽出し、
  /// 新規確定があれば次の [Classification.partial] を返す。何も増えていなければ null。
  Classification? _extractPartial(
    String buffer,
    Classification current,
    Set<String> emitted,
  ) {
    String itemName = current.itemName;
    GarbageCategory? category = current.category;
    String disposalMethod = current.disposalMethod;
    String collectionDay = current.collectionDay;
    String notes = current.notes;
    var changed = false;

    String? pick(String key) {
      if (emitted.contains(key)) return null;
      // キーの後に : "...閉じ" が揃っている場合のみマッチ。
      // 値内の \" は許容。閉じクォートの直後に , または } or 改行が続く前提。
      final escaped = RegExp.escape(key);
      final pattern = RegExp(
        '"$escaped"\\s*:\\s*"((?:\\\\.|[^"\\\\])*)"\\s*[,}\\r\\n]',
      );
      final m = pattern.firstMatch(buffer);
      if (m == null) return null;
      emitted.add(key);
      return _unescapeJsonString(m.group(1) ?? '');
    }

    final v1 = pick('itemName');
    if (v1 != null) {
      itemName = v1;
      changed = true;
    }
    final v2 = pick('category');
    if (v2 != null) {
      category = GarbageCategory.fromJa(v2);
      changed = true;
    }
    final v3 = pick('disposalMethod');
    if (v3 != null) {
      disposalMethod = v3;
      changed = true;
    }
    final v4 = pick('collectionDay');
    if (v4 != null) {
      collectionDay = v4;
      changed = true;
    }
    final v5 = pick('notes');
    if (v5 != null) {
      notes = v5;
      changed = true;
    }

    if (!changed) return null;
    return Classification.partial(
      itemName: itemName,
      category: category,
      disposalMethod: disposalMethod,
      collectionDay: collectionDay,
      notes: notes,
      municipality: current.municipality,
    );
  }

  String _unescapeJsonString(String raw) {
    // 簡易 JSON 文字列アンエスケープ（\" \\ \n \t \r のみ対応）
    return raw
        .replaceAll(r'\"', '"')
        .replaceAll(r'\\', r'\')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\r')
        .replaceAll(r'\t', '\t');
  }

  Future<http.Response> _postWithRetry(Uri uri, String body) async {
    var attempt = 0;
    while (true) {
      attempt++;
      final http.Response response;
      try {
        response = await _client
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: body,
            )
            .timeout(const Duration(seconds: 60));
      } on TimeoutException {
        throw const GeminiException(
          '応答が60秒以内に返ってきませんでした。通信環境を確認して再試行してください。',
        );
      }

      if (response.statusCode == 200) return response;

      final transient = response.statusCode == 503 ||
          response.statusCode == 429 ||
          response.statusCode == 500;
      if (transient && attempt < _maxAttempts) {
        final waitSec = 1 << attempt; // 2s, 4s, ...
        await Future<void>.delayed(Duration(seconds: waitSec));
        continue;
      }

      if (response.statusCode == 503) {
        throw const GeminiException(
          'Geminiが混み合っています。少し待ってから再試行してください。',
        );
      }
      throw GeminiException(
        'Gemini API エラー (${response.statusCode}): ${response.body}',
      );
    }
  }

  String _extractText(Map<String, dynamic> response) {
    final candidates = response['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw const GeminiException('Gemini 応答に候補がありません');
    }
    final content = (candidates.first as Map)['content'] as Map?;
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw const GeminiException('Gemini 応答に parts がありません');
    }
    final buffer = StringBuffer();
    for (final part in parts) {
      final text = (part as Map)['text'];
      if (text is String) buffer.write(text);
    }
    return buffer.toString();
  }

  Map<String, dynamic> _parseJsonFromText(String text) {
    var cleaned = text.trim();
    // Gemini が ```json ... ``` で囲むことがある
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
      cleaned = cleaned.replaceFirst(RegExp(r'\s*```\s*$'), '');
    }
    // 最初の { から最後の } までを抜き出す（前後の雑文対策）
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      throw GeminiException('Gemini 応答が JSON ではありません: $text');
    }
    final jsonStr = cleaned.substring(start, end + 1);
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      throw GeminiException('JSON パース失敗: $e\n元の応答: $text');
    }
  }
}

class GeminiException implements Exception {
  final String message;
  const GeminiException(this.message);
  @override
  String toString() => message;
}
