// lib/features/events/models/event_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:narrow_gil/features/events/models/schedule_item_model.dart';
import 'package:narrow_gil/features/events/models/content_block_model.dart';

// ✨ [추가] 참석자 정보를 담을 모델
class Attendee {
  final String uid;
  final String name;
  final String church;

  Attendee({required this.uid, required this.name, required this.church});

  factory Attendee.fromMap(Map<String, dynamic> map) {
    return Attendee(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      church: map['church'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'church': church,
    };
  }
}

class EventModel {
  final String id;
  final String title;
  final String description;
  final String authorId;
  final Timestamp createdAt;
  final String church; // ✨ [추가] 행사가 속한 교회
  final List<Attendee> attendees; // ✨ [수정] 참석자 uid 리스트에서 모델 리스트로 변경
  final List<ScheduleItemModel> schedule;
  final ContentBlockModel report;

  EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.authorId,
    required this.createdAt,
    required this.church, // ✨ [추가]
    this.attendees = const [],
    this.schedule = const [],
    required this.report,
  });

  factory EventModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return EventModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      authorId: data['authorId'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      church: data['church'] ?? '', // ✨ [추가]
      // ✨ [수정] Map 리스트를 Attendee 객체 리스트로 변환
      attendees: (data['attendees'] as List<dynamic>? ?? [])
          .map((item) => Attendee.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      schedule: (data['schedule'] as List<dynamic>? ?? [])
          .map((item) => ScheduleItemModel.fromMap(item))
          .toList(),
      report: ContentBlockModel.fromMap(data['report'] ?? {'blocks': []}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'authorId': authorId,
      'createdAt': createdAt,
      'church': church, // ✨ [추가]
      'attendees': attendees.map((item) => item.toMap()).toList(), // ✨ [수정]
      'schedule': schedule.map((item) => item.toMap()).toList(),
      'report': report.toMap(),
    };
  }
}