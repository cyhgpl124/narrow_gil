import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:narrow_gil/features/forum/models/forum_model.dart';

class ForumService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- ▼ [수정] 출석 통계 함수: 저장된 총원을 기준으로 계산하도록 변경 ▼ ---
  /// 특정 월의 출석 통계를 계산하여 반환합니다.
  Future<Map<String, dynamic>> getAttendanceStats(
      String churchName, String yearMonth) async {
    try {
      final forumDocRef = _firestore
          .collection('churches')
          .doc(churchName)
          .collection('forums')
          .doc(yearMonth);
      final forumSnapshot = await forumDocRef.get();

      int totalMemberCount = 0;
      if (forumSnapshot.exists) {
        // 1. 포럼 문서에서 '서기' 토픽을 찾아 저장된 총원을 가져옵니다.
        final forumData = forumSnapshot.data() as Map<String, dynamic>;
        final secretaryTopicEntry = forumData.entries.firstWhere(
            (entry) => entry.key.endsWith('_서기'),
            orElse: () => const MapEntry('', null));

        if (secretaryTopicEntry.value != null &&
            secretaryTopicEntry.value['totalMembersForMonth'] != null) {
          totalMemberCount = secretaryTopicEntry.value['totalMembersForMonth'];
        }
      }

      // 2. 만약 저장된 총원이 없다면(이전 버전 호환성), 실시간으로 계산합니다.
      if (totalMemberCount == 0) {
        final membersSnapshot = await _firestore
            .collection('approved_members')
            .doc(churchName)
            .collection('members')
            .where('baptismDate', isGreaterThan: "")
            .get();
        totalMemberCount = membersSnapshot.docs.length-1; // 목회자는 통계제외
      }

      // 3. 실제 출석 인원을 계산합니다.
      final attendanceCollection = _firestore
          .collection('churches')
          .doc(churchName)
          .collection('attendance')
          .doc(yearMonth);

      final attendanceSnapshot = await attendanceCollection.get();
      final attendedMemberCount = attendanceSnapshot.exists
          ? (attendanceSnapshot.data()?.length ?? 0)
          : 0;

      final attendanceRate = totalMemberCount > 0
          ? (attendedMemberCount / totalMemberCount) * 100
          : 0.0;

      return {
        'total': totalMemberCount,
        'attended': attendedMemberCount,
        'rate': attendanceRate,
      };
    } catch (e) {
      debugPrint("출석 통계 계산 중 오류 발생: $e");
      return {'total': 0, 'attended': 0, 'rate': 0.0};
    }
  }
  // --- ▲ [수정] 출석 통계 함수 ▲ ---

  Future<Map<String, List<ForumTopic>>> getForumDataForTwoMonths({
    required String churchName,
    required String currentMonth,
    required String previousMonth,
  }) async {
    final results = await Future.wait([
      _getTopicsForSingleMonth(churchName, currentMonth),
      _getTopicsForSingleMonth(churchName, previousMonth),
    ]);
    return {
      'current': results[0],
      'previous': results[1],
    };
  }

  Future<List<ForumTopic>> _getTopicsForSingleMonth(
      String churchName, String yearMonth) async {
    final forumDocRef = _firestore
        .collection('churches')
        .doc(churchName)
        .collection('forums')
        .doc(yearMonth);
    final snapshot = await forumDocRef.get();

    if (!snapshot.exists || snapshot.data() == null) {
      final churchDoc =
          await _firestore.collection('churches').doc(churchName).get();
      final positions = (churchDoc.data()?['직책'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      await _initializeForumTopics(
          docRef: forumDocRef, positions: positions, churchName: churchName);
      final newSnapshot = await forumDocRef.get();
      if (!newSnapshot.exists || newSnapshot.data() == null) return [];

      final data = newSnapshot.data()!;
      return data.entries
          .map((entry) => ForumTopic.fromMap(entry.key, entry.value))
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));
    }

    final data = snapshot.data()!;
    return data.entries
        .map((entry) => ForumTopic.fromMap(entry.key, entry.value))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
  }

  Future<void> updateForumTopic({
    required String churchName,
    required String yearMonth,
    required String topicId,
    required String thisMonthExecution,
    required String nextMonthPlan,
    required String editorName,
  }) async {
    final docRef = _firestore
        .collection('churches')
        .doc(churchName)
        .collection('forums')
        .doc(yearMonth);
    await docRef.update({
      '$topicId.thisMonthExecution': thisMonthExecution,
      '$topicId.nextMonthPlan': nextMonthPlan,
      '$topicId.lastEditor': editorName,
      '$topicId.lastEditedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateAccountingTopic({
    required String churchName,
    required String yearMonth,
    required String topicId,
    required num broughtForward,
    required num income,
    required num expenditure,
    required String incomeDetails,
    required String expenditureDetails,
    required String editorName,
  }) async {
    final docRef = _firestore
        .collection('churches')
        .doc(churchName)
        .collection('forums')
        .doc(yearMonth);

    final balance = broughtForward + income - expenditure;

    await docRef.update({
      '$topicId.broughtForward': broughtForward,
      '$topicId.income': income,
      '$topicId.expenditure': expenditure,
      '$topicId.balance': balance,
      '$topicId.incomeDetails': incomeDetails,
      '$topicId.expenditureDetails': expenditureDetails,
      '$topicId.lastEditor': editorName,
      '$topicId.lastEditedAt': FieldValue.serverTimestamp(),
    });
  }

  // --- ▼ [추가] 안건토의 업데이트 함수 ▼ ---
  Future<void> updateAgendaTopic({
    required String churchName,
    required String yearMonth,
    required String topicId,
    required String agendaContent,
    required String discussionResult,
    required String actionLog,
    required String editorName,
  }) async {
    final docRef = _firestore
        .collection('churches')
        .doc(churchName)
        .collection('forums')
        .doc(yearMonth);
    await docRef.update({
      '$topicId.agendaContent': agendaContent,
      '$topicId.discussionResult': discussionResult,
      '$topicId.actionLog': actionLog,
      '$topicId.lastEditor': editorName,
      '$topicId.lastEditedAt': FieldValue.serverTimestamp(),
    });
  }
  // --- ▲ [추가] 안건토의 업데이트 함수 ▲ ---

  Future<void> _initializeForumTopics(
      {required DocumentReference docRef,
      required List<String> positions,
      required String churchName}) async {
    // 월초 총원 계산
    final membersSnapshot = await _firestore
        .collection('approved_members')
        .doc(churchName)
        .collection('members')
        .where('baptismDate', isGreaterThan: '') // baptismDate가 빈칸이 아닌 경우만 조회
        .get();
    final totalMemberCount = membersSnapshot.docs.length;

    final Map<String, List<String>> positionToNamesMap = {};
    for (var doc in membersSnapshot.docs) {
      final data = doc.data();
      final name = data['name'] as String?;
      final memberPositionsData = data['role'];
      if (name != null) {
        if (memberPositionsData is List) {
          for (var pos in memberPositionsData) {
            positionToNamesMap.putIfAbsent(pos.toString(), () => []).add(name);
          }
        } else if (memberPositionsData is String) {
          final positionsList =
              memberPositionsData.split(',').map((p) => p.trim()).toList();
          for (var pos in positionsList) {
            positionToNamesMap.putIfAbsent(pos, () => []).add(name);
          }
        }
      }
    }

    final Map<String, Map<String, dynamic>> initialTopics = {};

    for (int i = 0; i < positions.length; i++) {
      final position = positions[i];
      final names = positionToNamesMap[position]?.join(', ') ?? '';
      final title = names.isNotEmpty ? '$position ($names)' : position;
      final topicId = '${(i + 1).toString().padLeft(2, '0')}_$position';

      bool isAccountingTopic = position == '회계' || position == '기금';

      initialTopics[topicId] = {
        'title': title,
        'responsiblePosition': [position],
        'thisMonthExecution': '',
        'nextMonthPlan': '',
        'lastEditor': '',
        'lastEditedAt': Timestamp.now(),
        'broughtForward': isAccountingTopic ? 0 : null,
        'income': isAccountingTopic ? 0 : null,
        'expenditure': isAccountingTopic ? 0 : null,
        'balance': isAccountingTopic ? 0 : null,
        'incomeDetails': isAccountingTopic ? '' : null,
        'expenditureDetails': isAccountingTopic ? '' : null,
        // --- ▼ [수정] 서기 토픽 생성 시 총원 저장 ▼ ---
        'totalMembersForMonth': position == '서기' ? totalMemberCount : null,
      };
    }

    final lastIndex = positions.length;
    // --- ▼ [수정] 안건토의 토픽 초기화 ▼ ---
    initialTopics['${(lastIndex + 1).toString().padLeft(2, '0')}_안건토의'] = {
      'title': '안건토의',
      'responsiblePosition': positions.isNotEmpty ? positions : ['서기'],
      'lastEditor': '',
      'lastEditedAt': Timestamp.now(),
      'agendaContent': '', // 안건내용 필드 추가
      'discussionResult': '', // 토의결과 필드 추가
      'actionLog': '', // 실행내역 필드 추가
    };

    await docRef.set(initialTopics, SetOptions(merge: true));
  }
}
