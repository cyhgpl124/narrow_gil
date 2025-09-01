// lib/features/events/models/schedule_item_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:narrow_gil/features/events/models/content_block_model.dart';

class ScheduleItemModel {
  final Timestamp date;
  final String time; // 예: "09:00 - 10:00"
  final String detailsTitle;
  final ContentBlockModel detailsContent;

  ScheduleItemModel({
    required this.date,
    required this.time,
    required this.detailsTitle,
    required this.detailsContent,
  });

  factory ScheduleItemModel.fromMap(Map<String, dynamic> map) {
    return ScheduleItemModel(
      date: map['date'] ?? Timestamp.now(),
      time: map['time'] ?? '',
      detailsTitle: map['detailsTitle'] ?? '세부사항',
      detailsContent: ContentBlockModel.fromMap(map['detailsContent'] ?? {'blocks': []}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'time': time,
      'detailsTitle': detailsTitle,
      'detailsContent': detailsContent.toMap(),
    };
  }
}