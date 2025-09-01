// lib/home/models/notice_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class Notice extends Equatable {
  final String id;
  final String content;
  final String author;
  final Timestamp createdAt;

  const Notice({
    required this.id,
    required this.content,
    required this.author,
    required this.createdAt,
  });

  factory Notice.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Notice(
      id: doc.id,
      content: data['content'] ?? '',
      author: data['author'] ?? '작성자 없음',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'content': content,
      'author': author,
      'createdAt': createdAt,
    };
  }

  @override
  List<Object?> get props => [id, content, author, createdAt];
}