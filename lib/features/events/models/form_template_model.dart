// lib/features/events/models/form_template_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:narrow_gil/features/events/models/content_block_model.dart';

class FormTemplateModel {
  final String id;
  final String name;
  final ContentBlockModel content;
  final String authorId;

  FormTemplateModel({
    required this.id,
    required this.name,
    required this.content,
    required this.authorId,
  });

  factory FormTemplateModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return FormTemplateModel(
      id: doc.id,
      name: data['name'] ?? '',
      content: ContentBlockModel.fromMap(data['content'] ?? {'blocks': []}),
      authorId: data['authorId'] ?? '',
    );
  }
}