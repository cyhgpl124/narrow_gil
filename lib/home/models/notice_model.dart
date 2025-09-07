// lib/home/models/notice_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Notice {
  final String id;
  final String content;
  final String author;
  final String authorId;
  final Timestamp createdAt;
  final Timestamp dueDate; // ✨ [수정] Null을 허용하지 않도록 '?' 제거

  Notice({
    required this.id,
    required this.content,
    required this.author,
    required this.authorId,
    required this.createdAt,
    required this.dueDate, // ✨ [수정] required 키워드 추가
  });

  factory Notice.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Notice(
      id: doc.id,
      content: data['content'] ?? '',
      author: data['author'] ?? '',
      authorId: data['authorId'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      // ✨ [수정] dueDate가 없을 경우 현재 시간을 기본값으로 사용하여 오류 방지
      dueDate: data['dueDate'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'content': content,
      'author': author,
      'authorId': authorId,
      'createdAt': createdAt,
      'dueDate': dueDate,
    };
  }
}