// lib/features/my_page/models/score_log_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class ScoreLog {
  final Timestamp date;
  final String reason;
  final int scoreChange;

  ScoreLog({
    required this.date,
    required this.reason,
    required this.scoreChange,
  });

  factory ScoreLog.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ScoreLog(
      date: data['date'] ?? Timestamp.now(),
      reason: data['reason'] ?? '내역 없음',
      scoreChange: (data['scoreChange'] as num?)?.toInt() ?? 0,
    );
  }
}