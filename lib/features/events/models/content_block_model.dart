// lib/features/events/models/content_block_model.dart

enum ContentBlockType { text, table, image, divider }

class ContentBlock {
  final ContentBlockType type;
  final dynamic content; // text: String, table: List<List<String>>, image: List<String> (URLs)

  ContentBlock({required this.type, this.content});

  // --- ▼ [수정] Firestore 형식에 맞게 데이터를 변환하고 복원하는 로직 추가 ▼ ---
  factory ContentBlock.fromMap(Map<String, dynamic> map) {
    final type = ContentBlockType.values.firstWhere(
      (e) => e.name == map['type'],
      orElse: () => ContentBlockType.text,
    );
    dynamic finalContent = map['content'];

    // Firestore에 Map으로 저장된 표 데이터를 다시 List<List<String>>으로 변환
    if (type == ContentBlockType.table && finalContent is Map) {
      final Map<String, dynamic> tableMap = Map<String, dynamic>.from(finalContent);
      // 'row_0', 'row_1' ... 순서대로 정렬하여 행 순서 보장
      final sortedKeys = tableMap.keys.toList()
        ..sort((a, b) {
          final aNum = int.tryParse(a.split('_').last) ?? 0;
          final bNum = int.tryParse(b.split('_').last) ?? 0;
          return aNum.compareTo(bNum);
        });

      final List<List<String>> tableData = [];
      for (final key in sortedKeys) {
        if (tableMap[key] is List) {
          tableData.add(List<String>.from(tableMap[key]));
        }
      }
      finalContent = tableData;
    }

    return ContentBlock(
      type: type,
      content: finalContent,
    );
  }

  Map<String, dynamic> toMap() {
    dynamic processedContent = content;

    // 표 데이터를 List<List<String>>에서 Map<String, List<String>>으로 변환
    if (type == ContentBlockType.table && content is List<List<dynamic>>) {
      final tableData = List<List<String>>.from(
          (content as List).map((row) => List<String>.from(row as List)));
      final Map<String, List<String>> tableMap = {};
      for (int i = 0; i < tableData.length; i++) {
        tableMap['row_$i'] = tableData[i];
      }
      processedContent = tableMap;
    }

    return {
      'type': type.name,
      'content': processedContent,
    };
  }
  // --- ▲ [수정] Firestore 형식에 맞게 데이터를 변환하고 복원하는 로직 추가 ▲ ---
}

class ContentBlockModel {
  final List<ContentBlock> blocks;

  ContentBlockModel({this.blocks = const []});

  factory ContentBlockModel.fromMap(Map<String, dynamic> map) {
    return ContentBlockModel(
      blocks: (map['blocks'] as List<dynamic>? ?? [])
          .map((block) => ContentBlock.fromMap(block))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'blocks': blocks.map((block) => block.toMap()).toList(),
    };
  }
}