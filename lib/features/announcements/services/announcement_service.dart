// lib/features/announcements/services/announcement_service.dart
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:narrow_gil/features/announcements/models/announcement_model.dart';
import 'package:uuid/uuid.dart';

class AnnouncementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ✨ [삭제] 기존의 실시간 스트림 방식은 페이지네이션과 맞지 않아 삭제합니다.
  // Stream<List<Announcement>> getAnnouncements(String churchName) { ... }

  // ✨ [추가] 페이지네이션을 위해 데이터를 가져오는 새로운 함수
  /// Firestore에서 공지사항 목록을 페이지 단위로 가져옵니다.
  /// [limit]으로 한 페이지에 가져올 개수를 지정하고,
  /// [startAfter]로 다음 페이지를 요청할 기준점을 지정합니다.
  Future<Map<String, dynamic>> getAnnouncementsPaginated({
    required String churchName,
    int limit = 10, // 한 번에 10개씩 불러옵니다.
    DocumentSnapshot? startAfter,
  }) async {
    Query query = _firestore
        .collection('churches')
        .doc(churchName)
        .collection('announcements')
        .orderBy('startDate', descending: true);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final querySnapshot = await query.limit(limit).get();

    final announcements = querySnapshot.docs.map((doc) => Announcement.fromFirestore(doc)).toList();

    // 다음 페이지 요청의 기준이 될 마지막 문서를 저장합니다.
    final lastDocument = querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null;
    // 불러온 개수가 요청한 limit과 동일하면 다음 페이지가 있을 가능성이 있습니다.
    final hasMore = announcements.length == limit;

    return {
      'announcements': announcements,
      'lastDocument': lastDocument,
      'hasMore': hasMore,
    };
  }


  // 공지 생성 함수 (기존과 동일)
  Future<void> createAnnouncement({
    required String churchName,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    required String contact,
    required List<Uint8List> imageBytesList,
    required List<String> fileNames,
    required String authorId,
    required String authorName,
  }) async {
    final announcementId = const Uuid().v4();
    List<String> imageUrls = [];

    for (int i = 0; i < imageBytesList.length; i++) {
      final imageBytes = imageBytesList[i];
      final fileName = fileNames[i];
      final imageRef = _storage.ref('churches/$churchName/announcements/$announcementId/$fileName');
      await imageRef.putData(imageBytes);
      final imageUrl = await imageRef.getDownloadURL();
      imageUrls.add(imageUrl);
    }

    if (imageUrls.isEmpty) {
      throw Exception("업로드할 이미지가 없습니다.");
    }

    final announcement = Announcement(
      id: announcementId,
      title: title,
      imageUrls: imageUrls,
      previewImageUrl: imageUrls.first,
      startDate: startDate,
      endDate: endDate,
      contact: contact,
      authorId: authorId,
      authorName: authorName,
      createdAt: Timestamp.now(),
    );

    await _firestore
        .collection('churches')
        .doc(churchName)
        .collection('announcements')
        .doc(announcementId)
        .set(announcement.toFirestore());
  }
}