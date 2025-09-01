import 'package:cloud_firestore/cloud_firestore.dart';

class Question {
  final String id;
  final String content;
  final String authorId;
  final String authorName;
  final Timestamp createdAt;
  final String? answer;
  final String? answeredBy;
  final Timestamp? answeredAt;

  Question({
    required this.id,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    this.answer,
    this.answeredBy,
    this.answeredAt,
  });

  factory Question.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Question(
      id: doc.id,
      content: data['content'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      answer: data['answer'],
      answeredBy: data['answeredBy'],
      answeredAt: data['answeredAt'],
    );
  }
}