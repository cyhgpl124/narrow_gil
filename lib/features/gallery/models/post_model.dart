import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String authorId;
  final String authorName;
  final List<String> mediaUrls; // 여러 URL을 저장하도록 변경
  final List<bool> isVideoList;   // 각 URL이 비디오인지 여부를 저장
  final String description;
  final String? location;
  final DateTime createdAt;
  // --- ▼ [추가] 좋아요 및 댓글 수 필드 ---
  final List<String> likes; // 좋아요를 누른 사용자 UID 목록
  final int commentCount;   // 댓글 수
  // --- ▲ [추가] ---

  Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.mediaUrls,
    required this.isVideoList,
    required this.description,
    this.location,
    required this.createdAt,
    this.likes = const [],   // [추가] 기본값을 빈 리스트로 설정
    this.commentCount = 0, // [추가] 기본값을 0으로 설정
  });

  factory Post.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Post(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      mediaUrls: List<String>.from(data['mediaUrls'] ?? []),
      isVideoList: List<bool>.from(data['isVideoList'] ?? []),
      description: data['description'] ?? '',
      location: data['location'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      // --- ▼ [추가] Firestore 문서에서 likes와 commentCount 데이터 읽기 ---
      likes: List<String>.from(data['likes'] ?? []),
      commentCount: data['commentCount'] ?? 0,
      // --- ▲ [추가] ---
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'mediaUrls': mediaUrls,
      'isVideoList': isVideoList,
      'description': description,
      'location': location,
      'createdAt': Timestamp.fromDate(createdAt),
      // --- ▼ [추가] Firestore에 저장할 필드 추가 ---
      'likes': likes,
      'commentCount': commentCount,
      // --- ▲ [추가] ---
    };
  }
}