// lib/features/events/services/event_service.dart
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:narrow_gil/features/events/models/content_block_model.dart';
import 'package:narrow_gil/features/events/models/event_model.dart';
import 'package:narrow_gil/features/events/models/form_template_model.dart';
import 'package:narrow_gil/features/user/user_service.dart';
import 'package:narrow_gil/home/models/user_profile.dart';
import 'package:url_launcher/url_launcher.dart';

class EventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserService _userService = UserService();
  // --- ▼ [추가] Firebase Storage 인스턴스 생성 ▼ ---
  final FirebaseStorage _storage = FirebaseStorage.instance;
  // --- ▲ [추가] Firebase Storage 인스턴스 생성 ▲ ---

  // 새 행사 생성
  Future<String> createEvent({
    required String title,
    required String description,
    required String authorId,
    required String church,
  }) async {
    final docRef = await _firestore.collection('events').add({
      'title': title,
      'description': description,
      'authorId': authorId,
      'createdAt': FieldValue.serverTimestamp(),
      'church': church, // ✨ church 필드 추가
      'attendees': [],
      'schedule': [],
      'report': {'blocks': []},
    });
    await _userService.addSkyScore(userId: authorId, church: church, reason: '$title행사 생성', score: 5);
    return docRef.id;
  }

  Stream<List<EventModel>> getEvents({String? churchName, required int year}) {
    // 1. 쿼리 시작
    Query query = _firestore.collection('events');

    // 2. 연도 필터링: 해당 연도의 시작과 끝 Timestamp를 계산
    final startOfYear = Timestamp.fromDate(DateTime(year, 1, 1));
    final endOfYear = Timestamp.fromDate(DateTime(year + 1, 1, 1));
    query = query.where('createdAt', isGreaterThanOrEqualTo: startOfYear)
                 .where('createdAt', isLessThan: endOfYear);

    // 3. 교회 필터링
    if (churchName != null && churchName != '전체') {
      query = query.where('church', isEqualTo: churchName);
    }

    // 4. 최종적으로 생성일 기준 내림차순 정렬
    // Firestore에서는 범위(<, >) 쿼리와 정렬을 같은 필드로 해야 합니다.
    query = query.orderBy('createdAt', descending: true);

    return query.snapshots().map(
        (snapshot) => snapshot.docs.map((doc) => EventModel.fromFirestore(doc)).toList());
  }

  // 특정 행사 정보 실시간으로 가져오기
  Stream<EventModel> getEventStream(String eventId) {
    return _firestore.collection('events').doc(eventId).snapshots()
        .map((snapshot) => EventModel.fromFirestore(snapshot));
  }

  // ✨ [수정] 행사 참석 시 이름과 교회 정보를 함께 저장
  Future<void> toggleAttendance(String eventId, UserProfile user) async {
    final docRef = _firestore.collection('events').doc(eventId);
    final doc = await docRef.get();
    if (doc.exists) {
      final attendees = (doc.data()!['attendees'] as List<dynamic>? ?? [])
          .map((item) => Attendee.fromMap(Map<String, dynamic>.from(item)))
          .toList();

      final isAttending = attendees.any((attendee) => attendee.uid == user.uid);

      if (isAttending) {
        // 참석 취소: 사용자 uid와 일치하는 항목 제거
        docRef.update({
          'attendees': FieldValue.arrayRemove([attendees.firstWhere((a) => a.uid == user.uid).toMap()])
        });
      } else {
        // 참석: 새로운 Attendee 객체 추가
        final newAttendee = Attendee(uid: user.uid, name: user.name, church: user.church);
        docRef.update({
          'attendees': FieldValue.arrayUnion([newAttendee.toMap()])
        });
      }
    }
  }

  // 시간표 항목 추가/수정/삭제 (업데이트는 전체 스케줄을 덮어쓰는 방식)
  Future<void> updateSchedule(String eventId, List<Map<String, dynamic>> newSchedule) async {
    await _firestore.collection('events').doc(eventId).update({'schedule': newSchedule});
  }

    // --- ▼ [추가] 특정 시간표 항목의 내용만 업데이트하는 함수 ▼ ---
  Future<void> updateSingleScheduleItem({
    required String eventId,
    required int scheduleIndex,
    required Map<String, dynamic> newContent,
  }) async {
    final docRef = _firestore.collection('events').doc(eventId);
    final doc = await docRef.get();

    if (doc.exists) {
      List<dynamic> schedule = List.from(doc.data()!['schedule'] ?? []);

      if (schedule.isNotEmpty && scheduleIndex < schedule.length) {
        // 기존 스케줄 아이템을 맵으로 변환
        Map<String, dynamic> itemToUpdate = Map<String, dynamic>.from(schedule[scheduleIndex]);
        // 세부 내용을 새 내용으로 교체
        itemToUpdate['detailsContent'] = newContent;
        // 리스트에서 해당 아이템을 업데이트
        schedule[scheduleIndex] = itemToUpdate;
        // 업데이트된 전체 스케줄 리스트를 저장
        await docRef.update({'schedule': schedule});
      } else {
        throw Exception('Invalid schedule index: $scheduleIndex');
      }
    } else {
       throw Exception('Event not found: $eventId');
    }
  }
  // --- ▲ [추가] 특정 시간표 항목의 내용만 업데이트하는 함수 ▲ ---

  // 보고서 업데이트
  Future<void> updateReport(String eventId, Map<String, dynamic> reportContent) async {
    await _firestore.collection('events').doc(eventId).update({'report': reportContent});
  }

  // 기존 양식 목록 가져오기
  Future<List<FormTemplateModel>> getFormTemplates() async {
    // 예시 데이터 추가 (최초 1회만 실행되도록)
    final check = await _firestore.collection('form_templates').limit(1).get();
    if (check.docs.isEmpty) {
        await _firestore.collection('form_templates').add({'name': '주간 보고서 양식', 'authorId': 'system', 'content': {'blocks': []}});
        await _firestore.collection('form_templates').add({'name': '월간 결산 양식', 'authorId': 'system', 'content': {'blocks': []}});
    }
    final snapshot = await _firestore.collection('form_templates').get();
    return snapshot.docs.map((doc) => FormTemplateModel.fromFirestore(doc)).toList();
  }

   // --- ▼ [수정] 새 양식 저장 시, 이미지 블록은 내용 없이 구조만 저장하도록 변경 ▼ ---
  Future<void> saveNewFormTemplate({
    required String name,
    required ContentBlockModel contentModel, // Map 대신 모델 객체를 직접 받음
    required String authorId,
    required String church,
  }) async {
    // 이미지 블록의 content를 빈 리스트로 교체하여 구조만 저장
    final templateBlocks = contentModel.blocks.map((block) {
      if (block.type == ContentBlockType.image) {
        return ContentBlock(type: ContentBlockType.image, content: []);
      }
      return block;
    }).toList();

    final templateContent = ContentBlockModel(blocks: templateBlocks);

    await _firestore.collection('form_templates').add({
      'name': name,
      'content': templateContent.toMap(), // 모델을 Map으로 변환하여 저장
      'authorId': authorId,
    });
     await _userService.addSkyScore(userId: authorId, church: church, reason: '새 양식 등록', score: 3);
  }
  // --- ▲ [수정] 새 양식 저장 시, 이미지 블록은 내용 없이 구조만 저장하도록 변경 ▲ ---


  // 보고서 이메일 제출
  Future<void> sendReportByEmail({
    required String toEmail,
    required String eventTitle,
    required String reportContent, // 보고서 내용을 텍스트로 변환하여 전달
  }) async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: toEmail,
      query: 'subject=${Uri.encodeComponent('$eventTitle 보고서')}&body=${Uri.encodeComponent(reportContent)}',
    );
    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    } else {
      throw 'Could not launch $emailLaunchUri';
    }
  }

   // --- ▼ [추가] 이미지를 Firebase Storage에 업로드하는 함수 ▼ ---
  Future<String> uploadImage({
    required String eventId,
    required Uint8List imageBytes,
  }) async {
    try {
      // 1. 저장 경로 및 파일 이름 생성 (중복 방지를 위해 현재 시간 사용)
      final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storagePath = 'events/$eventId/$fileName';

      // 2. Storage에 파일 업로드
      final ref = _storage.ref().child(storagePath);
      await ref.putData(imageBytes);

      // 3. 업로드된 파일의 다운로드 URL 반환
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } on FirebaseException catch (e) {
      // Storage 관련 오류 처리
      print('Firebase Storage 오류 발생: $e');
      throw Exception('이미지 업로드에 실패했습니다. 네트워크 상태를 확인하거나 잠시 후 다시 시도해 주세요.');
    } catch (e) {
      // 기타 오류 처리
      print('알 수 없는 오류 발생: $e');
      throw Exception('알 수 없는 오류로 이미지 업로드에 실패했습니다.');
    }
  }
  // --- ▲ [추가] 이미지를 Firebase Storage에 업로드하는 함수 ▲ ---
}