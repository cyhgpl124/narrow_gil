import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:narrow_gil/features/bible/models/verse_model.dart';

class BibleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // bibleBookChapters, bibleBookNumbers 맵은 이전과 동일
  // 성경 각 책의 장 수 정보
  static const Map<String, int> bibleBookChapters = {
    '창세기': 50,
    '출애굽기': 40,
    '레위기': 27,
    '민수기': 36,
    '신명기': 34,
    '여호수아': 24,
    '사사기': 21,
    '룻기': 4,
    '사무엘상': 31,
    '사무엘하': 24,
    '열왕기상': 22,
    '열왕기하': 25,
    '역대상': 29,
    '역대하': 36,
    '에스라': 10,
    '느헤미야': 13,
    '에스더': 10,
    '욥기': 42,
    '시편': 150,
    '잠언': 31,
    '전도서': 12,
    '아가': 8,
    '이사야': 66,
    '예레미야': 52,
    '예레미야애가': 5,
    '에스겔': 48,
    '다니엘': 12,
    '호세아': 14,
    '요엘': 3,
    '아모스': 9,
    '오바댜': 1,
    '요나': 4,
    '미가': 7,
    '나훔': 3,
    '하박국': 3,
    '스바냐': 3,
    '학개': 2,
    '스가랴': 14,
    '말라기': 4,
    '마태복음': 28,
    '마가복음': 16,
    '누가복음': 24,
    '요한복음': 21,
    '사도행전': 28,
    '로마서': 16,
    '고린도전서': 16,
    '고린도후서': 13,
    '갈라디아서': 6,
    '에베소서': 6,
    '빌립보서': 4,
    '골로새서': 4,
    '데살로니가전서': 5,
    '데살로니가후서': 3,
    '디모데전서': 6,
    '디모데후서': 4,
    '디도서': 3,
    '빌레몬서': 1,
    '히브리서': 13,
    '야고보서': 5,
    '베드로전서': 5,
    '베드로후서': 3,
    '요한1서': 5,
    '요한2서': 1,
    '요한3서': 1,
    '유다서': 1,
    '요한계시록': 22
  };

  // 성경 책 이름과 DB의 숫자 ID를 매핑하는 맵
  static const Map<String, int> bibleBookNumbers = {
    '창세기': 1,
    '출애굽기': 2,
    '레위기': 3,
    '민수기': 4,
    '신명기': 5,
    '여호수아': 6,
    '사사기': 7,
    '룻기': 8,
    '사무엘상': 9,
    '사무엘하': 10,
    '열왕기상': 11,
    '열왕기하': 12,
    '역대상': 13,
    '역대하': 14,
    '에스라': 15,
    '느헤미야': 16,
    '에스더': 17,
    '욥기': 18,
    '시편': 19,
    '잠언': 20,
    '전도서': 21,
    '아가': 22,
    '이사야': 23,
    '예레미야': 24,
    '예레미야애가': 25,
    '에스겔': 26,
    '다니엘': 27,
    '호세아': 28,
    '요엘': 29,
    '아모스': 30,
    '오바댜': 31,
    '요나': 32,
    '미가': 33,
    '나훔': 34,
    '하박국': 35,
    '스바냐': 36,
    '학개': 37,
    '스가랴': 38,
    '말라기': 39,
    '마태복음': 40,
    '마가복음': 41,
    '누가복음': 42,
    '요한복음': 43,
    '사도행전': 44,
    '로마서': 45,
    '고린도전서': 46,
    '고린도후서': 47,
    '갈라디아서': 48,
    '에베소서': 49,
    '빌립보서': 50,
    '골로새서': 51,
    '데살로니가전서': 52,
    '데살로니가후서': 53,
    '디모데전서': 54,
    '디모데후서': 55,
    '디도서': 56,
    '빌레몬서': 57,
    '히브리서': 58,
    '야고보서': 59,
    '베드로전서': 60,
    '베드로후서': 61,
    '요한1서': 62,
    '요한2서': 63,
    '요한3서': 64,
    '유다서': 65,
    '요한계시록': 66
  };
  static const int totalBibleChapters = 1189;

    // ✨ [추가] 점수 변경 로그를 기록하는 내부 함수
  Future<void> _addScoreLog({
    required WriteBatch batch,
    required String userId,
    required String reason,
    required int scoreChange,
  }) async {
    final logRef = _firestore.collection('users').doc(userId).collection('score_logs').doc();
    batch.set(logRef, {
      'date': FieldValue.serverTimestamp(),
      'reason': reason,
      'scoreChange': scoreChange,
    });
  }

  // --- ▼ [수정] 진행률(double)을 직접 저장하고 불러오도록 수정 ▼ ---

  // 진행 중인 절의 '진행률' 저장
  Future<void> saveInProgressVerse(
      String userId, String book, int chapter, double progress) async {
    final bookNumber = bibleBookNumbers[book];
    if (bookNumber == null) return;
    final progressKey = '$bookNumber-$chapter';

    final userProgressRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('bible_progress')
        .doc('chapters');
    // progress가 0이거나 1이면 저장할 필요 없음 (시작 전 or 완료)
    if (progress > 0 && progress < 1) {
      await userProgressRef.set({
        'in_progress': {progressKey: progress}
      }, SetOptions(merge: true));
    } else {
      // 진행률이 0 또는 1이면 해당 필드를 삭제
      await userProgressRef.set({
        'in_progress': {progressKey: FieldValue.delete()}
      }, SetOptions(merge: true));
    }
  }

  // 진행 중인 절의 '진행률' 불러오기
  Future<double> getInProgressVerse(
      String userId, String book, int chapter) async {
    final bookNumber = bibleBookNumbers[book];
    if (bookNumber == null) return 0.0;
    final progressKey = '$bookNumber-$chapter';

    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('bible_progress')
          .doc('chapters')
          .get();
      if (doc.exists && doc.data()?['in_progress'] != null) {
        // Firestore는 double을 저장해도 num으로 반환할 수 있으므로 .toDouble() 사용
        return (doc.data()!['in_progress'][progressKey] as num? ?? 0.0)
            .toDouble();
      }
    } catch (e) {
      print('진행중인 필사 기록 로딩 오류: $e');
    }
    return 0.0;
  }
  // --- ▲ [수정] 진행률(double)을 직접 저장하고 불러오도록 수정 ▲ ---

  // --- ▼ [추가] 진행중인 모든 장의 진행률 맵을 한번에 가져오는 함수 ▼ ---
  Future<Map<String, double>> getInProgressMap(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('bible_progress')
          .doc('chapters')
          .get();
      if (doc.exists && doc.data()?['in_progress'] != null) {
        // Firestore의 Map<String, dynamic>을 Map<String, double>로 변환
        final inProgressData =
            doc.data()!['in_progress'] as Map<String, dynamic>;
        return inProgressData
            .map((key, value) => MapEntry(key, (value as num).toDouble()));
      }
    } catch (e) {
      print('전체 진행 기록 로딩 오류: $e');
    }
    return {};
  }
  // --- ▲ [추가] 진행중인 모든 장의 진행률 맵을 한번에 가져오는 함수 ▲ ---

  // 완료된 장 목록 가져오기 (이전과 동일)
  Future<Set<String>> getCompletedChapters(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('bible_progress')
          .doc('chapters')
          .get();
      if (doc.exists && doc.data() != null) {
        final completed = List<String>.from(doc.data()!['completed'] ?? []);
        return completed.toSet();
      }
    } catch (e) {
      print('완료 기록 로딩 오류: $e');
    }
    return {};
  }

  // ✨ [수정] 장 완료 시, 누적 카운트를 기반으로 회독 수와 보너스를 처리하도록 로직 변경
  Future<void> completeChapter(
      String userId, String churchName, String book, int chapter) async {
    final bookNumber = bibleBookNumbers[book];
    if (bookNumber == null) return;

    final chapterKey = '$bookNumber-$chapter';
    final userBibleRef = _firestore.collection('users').doc(userId).collection('bible_progress').doc('chapters');
    final memberDocRef = _firestore.collection('approved_members').doc(churchName).collection('members').doc(userId);

    // 트랜잭션을 사용하여 데이터 정합성을 보장합니다.
    await _firestore.runTransaction((transaction) async {
      final progressDoc = await transaction.get(userBibleRef);
      final completedChapters = List<String>.from(progressDoc.data()?['completed'] ?? []);

      // 이미 완료된 장이면 작업을 중단합니다.
      if (completedChapters.contains(chapterKey)) return;

      // 1. +1점 및 로그 기록을 위한 WriteBatch 생성
      final batch = _firestore.batch();
      batch.update(memberDocRef, {'skyScore': FieldValue.increment(1)});
      await _addScoreLog(batch: batch, userId: userId, reason: '$book ${chapter}장 필사 완료', scoreChange: 1);

      // 2. 완료 목록에 현재 장을 추가하고, 진행중 목록에서 삭제합니다.
      batch.set(userBibleRef, {
        'completed': FieldValue.arrayUnion([chapterKey]),
        'in_progress': {chapterKey: FieldValue.delete()}
      }, SetOptions(merge: true));

      // 3. ✨ 누적 완료 장 수를 1 증가시킵니다.
      batch.set(userBibleRef, {'cumulativeCompletedCount': FieldValue.increment(1)}, SetOptions(merge: true));

      await batch.commit();

      // 4. ✨ 누적 카운트를 확인하여 1독 완료 보너스를 지급합니다.
      final updatedProgressDoc = await userBibleRef.get(); // 최신 데이터 다시 읽기
      final cumulativeCount = (updatedProgressDoc.data() as Map<String, dynamic>?)?['cumulativeCompletedCount'] ?? 0;

      if (cumulativeCount > 0 && cumulativeCount % totalBibleChapters == 0) {
        final completionBatch = _firestore.batch();
        // 4-1. 1독 완료 보너스 100점 지급 및 로그 기록
        completionBatch.update(memberDocRef, {'skyScore': FieldValue.increment(100)});
        await _addScoreLog(batch: completionBatch, userId: userId, reason: '성경 1독 완료 보너스', scoreChange: 100);
        // 4-2. 회독 수(bibleReadCount) 1 증가
        completionBatch.set(userBibleRef, {'bibleReadCount': FieldValue.increment(1)}, SetOptions(merge: true));
        await completionBatch.commit();
      }
    });
  }

    // ✨ [수정] 사용자가 직접 필사 기록을 '초기화'하는 함수 (누적 기록은 유지)
  /// 현재 필사 진행률(completed, in_progress)만 초기화합니다.
  Future<void> resetBibleProgress(String userId) async {
      final userBibleRef = _firestore.collection('users').doc(userId).collection('bible_progress').doc('chapters');
      // bibleReadCount와 cumulativeCompletedCount는 유지한 채, 두 필드만 삭제합니다.
      await userBibleRef.update({
        'completed': FieldValue.delete(),
        'in_progress': FieldValue.delete(),
      });
  }

  // 장 전체를 Verse 모델 리스트로 가져오기 (이전과 동일)
  Future<List<Verse>> getChapterVerses(String book, int chapter) async {
    final bookNumber = bibleBookNumbers[book];
    if (bookNumber == null) {
      throw Exception("잘못된 성경 이름입니다: $book");
    }
    try {
      final versesQuery = await _firestore
          .collection("bible_data")
          .doc(bookNumber.toString())
          .collection("chapters")
          .doc(chapter.toString())
          .collection("verses")
          .get();
      if (versesQuery.docs.isEmpty) return [];
      final sortedDocs = versesQuery.docs;
      sortedDocs.sort((a, b) {
        final int verseA = int.tryParse(a.id) ?? 0;
        final int verseB = int.tryParse(b.id) ?? 0;
        return verseA.compareTo(verseB);
      });
      return sortedDocs
          .map((doc) =>
              Verse(number: doc.id, text: doc.data()['text'] as String? ?? ''))
          .toList();
    } catch (e) {
      print("성경 본문을 불러오는 중 오류 발생: $e");
      throw Exception("성경 본문을 불러올 수 없습니다.");
    }
  }
}
