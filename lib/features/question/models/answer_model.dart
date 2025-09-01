// lib/features/question/models/answer_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AnswerModel {
  final String id;
  final String questionId;
  final String content;
  final String authorId;
  final String authorName;
  final Timestamp createdAt;

  AnswerModel({
    required this.id,
    required this.questionId,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
  });

   factory AnswerModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AnswerModel(
      id: doc.id,
      questionId: data['questionId'] ?? '',
      content: data['content'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }
}