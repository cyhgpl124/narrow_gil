import 'package:cloud_firestore/cloud_firestore.dart';

class MemberLog {
  final String id;
  final String memberName;
  final String field; // 변경된 필드 (예: 'role')
  final String oldValue; // 이전 값
  final String newValue; // 새 값
  final String editorName; // 수정한 관리자 이름
  final Timestamp editedAt; // 수정 시각
  final String action; // '수정' 또는 '삭제'

  MemberLog({
    required this.id,
    required this.memberName,
    required this.field,
    required this.oldValue,
    required this.newValue,
    required this.editorName,
    required this.editedAt,
    required this.action,
  });

  factory MemberLog.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return MemberLog(
      id: doc.id,
      memberName: data['memberName'] ?? '',
      field: data['field'] ?? '',
      oldValue: data['oldValue'] ?? '',
      newValue: data['newValue'] ?? '',
      editorName: data['editorName'] ?? '',
      editedAt: data['editedAt'] ?? Timestamp.now(),
      action: data['action'] ?? '',
    );
  }

  // --- ▼ [추가] Firestore 저장을 위한 toMap 함수 ---
  Map<String, dynamic> toMap() {
    return {
      'memberName': memberName,
      'field': field,
      'oldValue': oldValue,
      'newValue': newValue,
      'editorName': editorName,
      'editedAt': editedAt,
      'action': action,
    };
  }
}
