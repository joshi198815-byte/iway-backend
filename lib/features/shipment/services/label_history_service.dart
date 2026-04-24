import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

class LabelHistoryEntry {
  final String path;
  final String name;
  final DateTime createdAt;

  const LabelHistoryEntry({
    required this.path,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory LabelHistoryEntry.fromJson(Map<String, dynamic> json) => LabelHistoryEntry(
        path: (json['path'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
      );
}

class LabelHistoryService {
  const LabelHistoryService();

  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/label_history');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _indexFile() async {
    final dir = await _dir();
    return File('${dir.path}/index.json');
  }

  Future<List<LabelHistoryEntry>> loadHistory() async {
    final file = await _indexFile();
    if (!await file.exists()) return const [];
    final raw = await file.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded.whereType<Map<String, dynamic>>().map(LabelHistoryEntry.fromJson).toList();
  }

  Future<List<LabelHistoryEntry>> savePdf(Uint8List bytes, {required String fileName}) async {
    final dir = await _dir();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    final current = await loadHistory();
    final next = [
      LabelHistoryEntry(path: file.path, name: fileName, createdAt: DateTime.now()),
      ...current,
    ];

    final trimmed = next.take(5).toList();
    for (final stale in next.skip(5)) {
      final staleFile = File(stale.path);
      if (await staleFile.exists()) {
        await staleFile.delete();
      }
    }

    final index = await _indexFile();
    await index.writeAsString(jsonEncode(trimmed.map((e) => e.toJson()).toList()), flush: true);
    return trimmed;
  }
}
