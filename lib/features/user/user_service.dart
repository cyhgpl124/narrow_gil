// lib/features/user/user_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:narrow_gil/features/question/models/score_log_model.dart';
import 'package:narrow_gil/home/models/notice_model.dart';
import 'package:narrow_gil/models/church_model.dart';
import 'package:narrow_gil/features/my_page/models/score_log_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- ▼ [추가] 공지사항 관련 함수들 ▼ ---

  /// 특정 교회의 공지사항 목록을 실시간으로 가져옵니다.
  Stream<List<Notice>> getNotices(String churchId) {
    return _firestore
        .collection('churches')
        .doc(churchId)
        .collection('notices')
        .orderBy('createdAt', descending: true)
        .limit(3) // 최대 3개만 가져오기
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Notice.fromFirestore(doc)).toList());
  }

  /// 새로운 공지를 추가합니다.
  Future<void> addNotice(
      String churchId, String content, String author) async {
    final notice = {
      'content': content,
      'author': author,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await _firestore
        .collection('churches')
        .doc(churchId)
        .collection('notices')
        .add(notice);
  }

  /// 기존 공지를 수정합니다.
  Future<void> updateNotice(
      String churchId, String noticeId, String newContent) async {
    await _firestore
        .collection('churches')
        .doc(churchId)
        .collection('notices')
        .doc(noticeId)
        .update({'content': newContent});
  }

  /// 공지를 삭제합니다.
  Future<void> deleteNotice(String churchId, String noticeId) async {
    await _firestore
        .collection('churches')
        .doc(churchId)
        .collection('notices')
        .doc(noticeId)
        .delete();
  }
  // --- ▲ [추가] 공지사항 관련 함수들 ▲ ---

  // ✨ [추가] 페이지네이션이 적용된 점수 로그 조회 함수
  /// Firestore에서 사용자의 점수 로그를 페이지 단위로 가져옵니다.
  /// [limit]으로 한 페이지에 가져올 개수를 지정하고,
  /// [startAfter]로 다음 페이지를 요청할 기준점을 지정합니다.
  Future<Map<String, dynamic>> getScoreLogsPaginated({
    required String userId,
    int limit = 100, // 한 번에 100개씩 불러오도록 설정
    DocumentSnapshot? startAfter,
  }) async {
    // 쿼리 시작
    Query query = _firestore
        .collection('users')
        .doc(userId)
        .collection('score_logs')
        .orderBy('date', descending: true);

    // startAfter 문서가 있으면 그 다음부터 쿼리를 시작합니다.
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    // 지정된 limit만큼 문서를 가져옵니다.
    final querySnapshot = await query.limit(limit).get();

    final logs = querySnapshot.docs.map((doc) => ScoreLog.fromFirestore(doc)).toList();

    // 다음 페이지 요청의 기준이 될 마지막 문서를 저장합니다.
    final lastDocument = querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null;
    // 불러온 개수가 요청한 limit과 동일하면 다음 페이지가 있을 가능성이 있습니다.
    final hasMore = logs.length == limit;

    return {
      'logs': logs,
      'lastDocument': lastDocument,
      'hasMore': hasMore,
    };
  }

   // --- ▼ [추가] 교회의 상세 정보를 업데이트하는 함수 ---
  Future<void> updateChurchDetails(String churchName, Map<String, dynamic> data) async {
    // 업데이트할 데이터가 있을 경우에만 Firestore에 쓰기 작업을 수행합니다.
    if (data.isNotEmpty) {
      await _firestore.collection('churches').doc(churchName).update(data);
    }
  }
  // --- ▲ [추가] ---

  // --- ▼ [추가] 교회의 상세 정보를 가져오는 함수 ---
  Future<Church?> getChurchDetails(String churchName) async {
    final doc = await _firestore.collection('churches').doc(churchName).get();
    if (doc.exists) {
      return Church.fromFirestore(doc);
    }
    return null;
  }
  // --- ▲ [추가] ---
  // --- ▼ [추가] 랭킹 조회 함수들 ▼ ---

  // 교회 내 순위 조회
  Future<Map<String, int>> getChurchRank(
      String userId, String churchName) async {
    try {
      // 해당 교회의 모든 멤버를 skyScore(skyScore) 기준으로 내림차순 정렬
      final querySnapshot = await _firestore
          .collection('approved_members')
          .doc(churchName)
          .collection('members')
          .orderBy('skyScore', descending: true)
          .get();

      final members = querySnapshot.docs;
      // 사용자의 순위를 찾음 (Firestore 문서 ID가 userId와 일치하는 문서의 인덱스)
      final userRank = members.indexWhere((doc) => doc.id == userId) + 1;
      final totalMembers = members.length;

      if (userRank > 0) {
        return {'rank': userRank, 'total': totalMembers};
      }
    } catch (e) {
      print('교회 내 순위 조회 오류: $e');
    }
    return {'rank': 0, 'total': 0};
  }

  // 전체 순위 조회
  Future<Map<String, int>> getTotalRank(String userId, int userScore) async {
    try {
      // 1. 전체 사용자 수 조회
      final totalUsersSnapshot = await _firestore.collectionGroup('members').count().get();
      final totalUsers = totalUsersSnapshot.count;

      // 2. 나보다 점수가 높은 사용자 수 조회
      final higherRankUsersSnapshot = await _firestore
          .collectionGroup('members')
          .where('skyScore', isGreaterThan: userScore)
          .count()
          .get();

      final int higherRankCount = higherRankUsersSnapshot.count ?? 0;

      // 나의 등수 = (나보다 점수 높은 사람 수) + 1 (count는 null이 될 수 없으므로 ! 제거)
      final myRank = higherRankCount + 1;

      return {'rank': myRank, 'total': totalUsers!};
    } catch (e) {
      print('전체 순위 조회 오류: $e');
    }
    return {'rank': 0, 'total': 0};
  }
  // --- ▲ [추가] 랭킹 조회 함수들 ▲ ---

  Future<void> addUserPhrase(String userId, String phrase) async {
    final userDocRef = _firestore.collection('users').doc(userId);
    await userDocRef.update({
      'phrases': FieldValue.arrayUnion([phrase])
    });
  }

  Future<List<String>> getUserPhrases(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null && doc.data()!['phrases'] != null) {
        return List<String>.from(doc.data()!['phrases']);
      }
      return [];
    } catch (e) {
      print('문구 히스토리 로딩 오류: $e');
      return [];
    }
  }

  Future<void> updateUserProfile({
    required String userId,
    required String churchName,
    required String newName,
    required String newPhoneNumber,
    required String newHouseHoldHead,
  }) async {
    final userDocRef = _firestore.collection('users').doc(userId);
    final memberDocRef = _firestore
        .collection('approved_members')
        .doc(churchName)
        .collection('members')
        .doc(userId);

    final batch = _firestore.batch();
    batch.update(userDocRef, {'name': newName, 'phoneNumber': newPhoneNumber});
    batch
        .update(memberDocRef, {'name': newName, 'phoneNumber': newPhoneNumber, 'houseHoldHead': newHouseHoldHead});
    await batch.commit();
  }

  Future<void> withdrawUser(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      throw Exception('사용자 정보를 찾을 수 없습니다.');
    }
    final churchName = userDoc.data()!['church'];

    final userDocRef = _firestore.collection('users').doc(userId);
    final memberDocRef = _firestore
        .collection('approved_members')
        .doc(churchName)
        .collection('members')
        .doc(userId);

    final batch = _firestore.batch();
    batch.delete(userDocRef);
    batch.delete(memberDocRef);
    await batch.commit();
  }

   // --- ▼ [추가] 하늘점수 추가 및 로그 기록 함수 ▼ ---
  Future<void> addSkyScore({
    required String userId,
    required String church,
    required String reason,
    int score = 1,
  }) async {
    final memberRef = _firestore.collection('approved_members').doc(church).collection('members').doc(userId);
    final userRef = _firestore.collection('users').doc(userId);
    final logRef = userRef.collection('score_logs').doc();

    final newLog = ScoreLogModel(
      reason: reason,
      scoreChange: score,
      date: Timestamp.now(),
    );

    final batch = _firestore.batch();
    // approved_members 점수 업데이트
    batch.update(memberRef, {'skyScore': FieldValue.increment(score)});
    // users 점수 업데이트
    batch.update(userRef, {'skyScore': FieldValue.increment(score)});
    // 점수 로그 기록
    batch.set(logRef, newLog.toMap());

    await batch.commit();
  }
  // --- ▲ [추가] 하늘점수 추가 및 로그 기록 함수 ▲ ---
}
