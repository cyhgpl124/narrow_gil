// lib/features/question/models/question_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class QuestionModel {
  final String id;
  final String title;
  final String content;
  final String background;
  final String authorId;
  final String authorName;
  final Timestamp createdAt;
  final List<String> likes;
  // --- ▼ [수정] dislikeCount를 dislikes 리스트로 변경 ▼ ---
  final List<String> dislikes;
  // --- ▲ [수정] dislikeCount를 dislikes 리스트로 변경 ▲ ---
  final int likesCount; // ✨ [추가] 좋아요 수 저장을 위한 필드
  final bool isHidden;

  QuestionModel({
    required this.id,
    required this.title,
    required this.content,
    required this.background,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    this.likes = const [],
    // --- ▼ [수정] dislikes 필드 추가 ▼ ---
    this.dislikes = const [],
    // --- ▲ [수정] dislikes 필드 추가 ▲ ---
    this.likesCount = 0, // ✨ [추가]
    this.isHidden = false,
  });

  factory QuestionModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return QuestionModel(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      background: data['background'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      likes: List<String>.from(data['likes'] ?? []),
      // --- ▼ [수정] Firestore에서 dislikes 리스트를 읽어오도록 변경 ▼ ---
      dislikes: List<String>.from(data['dislikes'] ?? []),
      // --- ▲ [수정] Firestore에서 dislikes 리스트를 읽어오도록 변경 ▲ ---
      likesCount: data['likesCount'] ?? 0, // ✨ [추가]
      isHidden: data['isHidden'] ?? false,
    );
  }
}