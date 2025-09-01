// lib/features/schedule/models/event_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Event {
  final String id;
  final String title;
  final String? description;
  final DateTime date;
  final List<String> attendees; // 참석자 이름 목록

  Event({
    required this.id,
    required this.title,
    this.description,
    required this.date,
    required this.attendees,
  });

  factory Event.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Event(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'],
      date: (data['date'] as Timestamp).toDate(),
      attendees: List<String>.from(data['attendees'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'date': Timestamp.fromDate(date),
      'attendees': attendees,
    };
  }
}