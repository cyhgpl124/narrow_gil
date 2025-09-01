import 'package:cloud_firestore/cloud_firestore.dart';

class Announcement {
  final String id;
  final String title;
  // ✨ [수정] pdfUrl -> imageUrls (문자열 리스트)
  final List<String> imageUrls;
  final String previewImageUrl;
  final DateTime startDate;
  final DateTime endDate;
  final String contact;
  final String authorId;
  final String authorName;
  final Timestamp createdAt;

  Announcement({
    required this.id,
    required this.title,
    required this.imageUrls, // ✨ 수정
    required this.previewImageUrl,
    required this.startDate,
    required this.endDate,
    required this.contact,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
  });

  factory Announcement.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Announcement(
      id: doc.id,
      title: data['title'] ?? '',
      // ✨ [수정] Firestore의 List를 List<String>으로 변환
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      previewImageUrl: data['previewImageUrl'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      contact: data['contact'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'imageUrls': imageUrls, // ✨ 수정
      'previewImageUrl': previewImageUrl,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'contact': contact,
      'authorId': authorId,
      'authorName': authorName,
      'createdAt': createdAt,
    };
  }
}