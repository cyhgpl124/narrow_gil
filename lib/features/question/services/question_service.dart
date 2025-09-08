// lib/features/question/services/question_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:narrow_gil/features/question/models/answer_model.dart';
import 'package:narrow_gil/features/question/models/question_model.dart';
import 'package:narrow_gil/features/user/user_service.dart';

class QuestionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserService _userService = UserService();

  // 새 글 등록
  Future<void> addQuestion({
    required String title,
    required String content,
    required String background,
    required String authorId,
    required String authorName,
    required String church,
  }) async {
    await _firestore.collection('questions').add({
      'title': title,
      'content': content,
      'background': background,
      'authorId': authorId,
      'authorName': authorName,
      'createdAt': FieldValue.serverTimestamp(),
      'likes': [],
      'likesCount': 0, // likesCount 초기화
      'isHidden': false,
    });
    // 점수 및 로그 추가
    await _userService.addSkyScore(
        userId: authorId, church: church, reason: '글 작성');
  }

  // --- ▼ [수정] 좋아요/싫어요 토글 시, 반대 목록에서 자동으로 제거하는 로직 추가 ▼ ---

  // 좋아요 토글 처리
  Future<void> toggleLike(String questionId, String userId) async {
    final docRef = _firestore.collection('questions').doc(questionId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw Exception("Question not found");

      List<String> likes = List<String>.from(snapshot.data()!['likes'] ?? []);
      List<String> dislikes =
          List<String>.from(snapshot.data()!['dislikes'] ?? []);

      if (likes.contains(userId)) {
        // 이미 좋아요를 눌렀으면 취소
        likes.remove(userId);
      } else {
        // 좋아요를 누르지 않았으면 추가하고, 싫어요 목록에서는 제거
        likes.add(userId);
        dislikes.remove(userId);
      }
      transaction.update(docRef,
          {'likes': likes, 'dislikes': dislikes, 'likesCount': likes.length});
    });
  }

  // ✨ [추가] 페이지네이션을 위한 함수들
  /// 초기 데이터를 불러옵니다: 한 달 이내의 인기 글 + 한 달 이전의 최신 글 20개
  Future<Map<String, dynamic>> getInitialQuestions() async {
    final oneMonthAgo =
        Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 30)));

    // 1. "인기" 글 (한 달 이내, 좋아요 순)
    final hotSnapshot = await _firestore
        .collection('questions')
        .where('createdAt', isGreaterThanOrEqualTo: oneMonthAgo)
        .orderBy('likesCount', descending: true)
        .get();
    final hotQuestions = hotSnapshot.docs
        .map((doc) => QuestionModel.fromFirestore(doc))
        .toList();

    // 2. "최신" 글 (한 달 이전, 날짜 순, 첫 페이지)
    final coldSnapshot = await _firestore
        .collection('questions')
        .where('createdAt', isLessThan: oneMonthAgo)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();
    final coldQuestions = coldSnapshot.docs
        .map((doc) => QuestionModel.fromFirestore(doc))
        .toList();
    final lastDocument =
        coldSnapshot.docs.isNotEmpty ? coldSnapshot.docs.last : null;

    return {
      'hotQuestions': hotQuestions,
      'coldQuestions': coldQuestions,
      'lastDocument': lastDocument,
    };
  }

  /// 한 달 이전 글들의 다음 페이지를 불러옵니다.
  Future<Map<String, dynamic>> getMoreOldQuestions(
      DocumentSnapshot startAfter) async {
    final oneMonthAgo =
        Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 30)));
    final snapshot = await _firestore
        .collection('questions')
        .where('createdAt', isLessThan: oneMonthAgo)
        .orderBy('createdAt', descending: true)
        .startAfterDocument(startAfter)
        .limit(20)
        .get();

    final questions =
        snapshot.docs.map((doc) => QuestionModel.fromFirestore(doc)).toList();
    final lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
    final hasMore = questions.length == 20;

    return {
      'questions': questions,
      'lastDocument': lastDocument,
      'hasMore': hasMore,
    };
  }

  // 싫어요 토글 처리
  Future<void> toggleDislike(String questionId, String userId) async {
    final docRef = _firestore.collection('questions').doc(questionId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw Exception("Question not found");

      List<String> likes = List<String>.from(snapshot.data()!['likes'] ?? []);
      List<String> dislikes =
          List<String>.from(snapshot.data()!['dislikes'] ?? []);

      if (dislikes.contains(userId)) {
        // 이미 싫어요를 눌렀으면 취소
        dislikes.remove(userId);
      } else {
        // 싫어요를 누르지 않았으면 추가하고, 좋아요 목록에서는 제거
        dislikes.add(userId);
        likes.remove(userId);
      }

      transaction.update(docRef, {
        'likes': likes,
        'dislikes': dislikes,
        'isHidden': dislikes.length >= 10,
      });
    });
  }
  // --- ▲ [수정] 좋아요/싫어요 토글 시, 반대 목록에서 자동으로 제거하는 로직 추가 ▲ ---

  // --- ▼ [구현] 답변 추가, 답변 목록 조회 함수 추가 ▼ ---

  // 새 답변 등록
  Future<void> addAnswer({
    required String questionId,
    required String content,
    required String authorId,
    required String authorName,
    required String church,
  }) async {
    // 'questions' 컬렉션의 특정 문서 아래에 'answers' 서브 컬렉션을 생성
    await _firestore
        .collection('questions')
        .doc(questionId)
        .collection('answers')
        .add({
      'questionId': questionId,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 답변 작성 시 점수 및 로그 추가
    await _userService.addSkyScore(
        userId: authorId, church: church, reason: '댓글 작성');
  }

  // 특정 글에 대한 모든 답변 목록 실시간으로 가져오기
  Stream<List<AnswerModel>> getAnswers(String questionId) {
    return _firestore
        .collection('questions')
        .doc(questionId)
        .collection('answers')
        .orderBy('createdAt', descending: false) // 오래된 답변부터 순서대로
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AnswerModel.fromFirestore(doc))
            .toList());
  }
  // --- ▲ [구현] 답변 추가, 답변 목록 조회 함수 추가 ▲ ---

  // --- 참고: question_service.dart에 아래 함수가 추가되어야 합니다. ---
  Stream<DocumentSnapshot> getQuestionStream(String questionId) {
    return FirebaseFirestore.instance
        .collection('questions')
        .doc(questionId)
        .snapshots();
  }

  // --- ▼ [추가] 글 수정 및 삭제 함수 ▼ ---
  Future<void> updateQuestion({
    required String questionId,
    required String title,
    required String content,
    required String background,
  }) async {
    await _firestore.collection('questions').doc(questionId).update({
      'title': title,
      'content': content,
      'background': background,
    });
  }

  // --- ▼ [수정] 글 삭제 시 관련 답변도 함께 삭제하는 로직 추가 ▼ ---
  Future<void> deleteQuestion(String questionId) async {
    final questionRef = _firestore.collection('questions').doc(questionId);
    final answersRef = questionRef.collection('answers');

    // 트랜잭션을 사용하여 글과 모든 답변을 원자적으로 삭제
    await _firestore.runTransaction((transaction) async {
      // 1. 해당 글의 모든 답변 문서를 가져와서 삭제
      final answerSnapshot = await answersRef.get();
      for (var doc in answerSnapshot.docs) {
        transaction.delete(doc.reference);
      }
      // 2. 글 문서 자체를 삭제
      transaction.delete(questionRef);
    });
  }
  // --- ▲ [수정] 글 삭제 시 관련 답변도 함께 삭제하는 로직 추가 ▲ ---
  // --- ▲ [추가] 글 수정 및 삭제 함수 ▲ ---
}
