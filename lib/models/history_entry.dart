import 'dart:convert';

import 'classification.dart';

class HistoryEntry {
  final String id;
  final DateTime timestamp;
  final Classification classification;
  final String? imagePath;

  const HistoryEntry({
    required this.id,
    required this.timestamp,
    required this.classification,
    this.imagePath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'classification': classification.toJson(),
        'imagePath': imagePath,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    final classMap = json['classification'] as Map<String, dynamic>;
    return HistoryEntry(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      classification: Classification.fromJson(
        classMap,
        (classMap['municipality'] ?? '') as String,
      ),
      imagePath: json['imagePath'] as String?,
    );
  }

  String encode() => jsonEncode(toJson());

  factory HistoryEntry.decode(String raw) =>
      HistoryEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
