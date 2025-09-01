// lib/features/accounting/models/event_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String id;
  final String title;
  final Timestamp date;

  EventModel({
    required this.id,
    required this.title,
    required this.date,
  });

  factory EventModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return EventModel(
      id: doc.id,
      title: data['title'] ?? '이름 없음',
      date: data['date'] ?? Timestamp.now(),
    );
  }
}