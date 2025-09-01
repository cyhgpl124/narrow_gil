// lib/features/user/models/score_log_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ScoreLogModel {
  final String reason;
  final int scoreChange;
  final Timestamp date;

  ScoreLogModel({
    required this.reason,
    required this.scoreChange,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'reason': reason,
      'scoreChange': scoreChange,
      'date': date,
    };
  }
}