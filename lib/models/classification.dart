import 'dart:convert';

enum GarbageCategory {
  burnable,    // 可燃ごみ
  nonBurnable, // 不燃ごみ
  recyclable,  // 資源ごみ
  oversized,   // 粗大ごみ
  other;       // その他

  String get labelJa => switch (this) {
        GarbageCategory.burnable => '可燃ごみ',
        GarbageCategory.nonBurnable => '不燃ごみ',
        GarbageCategory.recyclable => '資源ごみ',
        GarbageCategory.oversized => '粗大ごみ',
        GarbageCategory.other => 'その他',
      };

  static GarbageCategory fromJa(String? value) {
    switch (value?.trim()) {
      case '可燃':
      case '可燃ごみ':
        return GarbageCategory.burnable;
      case '不燃':
      case '不燃ごみ':
        return GarbageCategory.nonBurnable;
      case '資源':
      case '資源ごみ':
        return GarbageCategory.recyclable;
      case '粗大':
      case '粗大ごみ':
        return GarbageCategory.oversized;
      default:
        return GarbageCategory.other;
    }
  }
}

class Classification {
  final String itemName;
  final GarbageCategory? category;
  final String disposalMethod;
  final String collectionDay;
  final String notes;
  final String municipality;

  /// ストリーミング受信中は false。全フィールドが確定すると true。
  final bool isComplete;

  const Classification({
    required this.itemName,
    required this.category,
    required this.disposalMethod,
    required this.collectionDay,
    required this.notes,
    required this.municipality,
    this.isComplete = true,
  });

  /// ストリーミング途中の部分結果を表現する。未到達のフィールドは空文字 / null。
  const Classification.partial({
    this.itemName = '',
    this.category,
    this.disposalMethod = '',
    this.collectionDay = '',
    this.notes = '',
    required this.municipality,
  }) : isComplete = false;

  factory Classification.fromJson(Map<String, dynamic> json, String municipality) {
    return Classification(
      itemName: (json['itemName'] ?? '不明') as String,
      category: GarbageCategory.fromJa(json['category'] as String?),
      disposalMethod: (json['disposalMethod'] ?? '') as String,
      collectionDay: (json['collectionDay'] ?? '') as String,
      notes: (json['notes'] ?? '') as String,
      municipality: municipality,
    );
  }

  bool get hasItemName => itemName.trim().isNotEmpty;
  bool get hasCategory => category != null;
  bool get hasDisposalMethod => disposalMethod.trim().isNotEmpty;
  bool get hasCollectionDay => collectionDay.trim().isNotEmpty;
  bool get hasNotes => notes.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'itemName': itemName,
        'category': (category ?? GarbageCategory.other).labelJa,
        'disposalMethod': disposalMethod,
        'collectionDay': collectionDay,
        'notes': notes,
        'municipality': municipality,
      };

  String encode() => jsonEncode(toJson());

  factory Classification.decode(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return Classification.fromJson(map, (map['municipality'] ?? '') as String);
  }
}
