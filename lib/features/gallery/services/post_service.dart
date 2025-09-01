import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image/image.dart' as img;
import 'package:narrow_gil/features/gallery/models/comment_model.dart'; // [추가] Comment 모델 import
import 'package:narrow_gil/features/gallery/models/post_model.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import 'package:narrow_gil/features/user/user_service.dart'; // ✨ [추가] UserService import

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final UserService _userService = UserService();

  // --- ▼ [추가] 좋아요 토글 함수 ---
  /// 게시물의 좋아요 상태를 토글(추가/삭제)합니다.
  Future<void> toggleLike(String churchName, String postId, String userId) async {
    final postRef = _firestore
        .collection('churches')
        .doc(churchName)
        .collection('posts')
        .doc(postId);

    final doc = await postRef.get();
    if (doc.exists) {
      final List<String> likes = List<String>.from(doc.data()?['likes'] ?? []);
      if (likes.contains(userId)) {
        // 이미 좋아요를 눌렀으면 취소 (배열에서 사용자 ID 제거)
        await postRef.update({
          'likes': FieldValue.arrayRemove([userId])
        });
      } else {
        // 좋아요를 누르지 않았으면 추가 (배열에 사용자 ID 추가)
        await postRef.update({
          'likes': FieldValue.arrayUnion([userId])
        });
      }
    }
  }
  // --- ▲ [추가] ---

  // --- ▼ [추가] 댓글 목록을 실시간으로 가져오는 함수 ---
  Stream<List<Comment>> getComments(String churchName, String postId) {
    return _firestore
        .collection('churches')
        .doc(churchName)
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('timestamp', descending: false) // 오래된 댓글부터 정렬
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Comment.fromFirestore(doc)).toList());
  }
  // --- ▲ [추가] ---

  // --- ▼ [추가] 댓글 추가 함수 ---
  Future<void> addComment({
    required String churchName,
    required String postId,
    required String text,
    required String authorId,
    required String authorName,
  }) async {
    final postRef = _firestore.collection('churches').doc(churchName).collection('posts').doc(postId);
    final commentRef = postRef.collection('comments').doc();

    final newComment = Comment(
      id: commentRef.id,
      authorId: authorId,
      authorName: authorName,
      text: text,
      timestamp: Timestamp.now(),
    );

    // Batch Write를 사용하여 댓글 추가와 게시물의 댓글 수 증가를 하나의 원자적 작업으로 처리
    final batch = _firestore.batch();
    batch.set(commentRef, newComment.toMap());
    batch.update(postRef, {'commentCount': FieldValue.increment(1)});
    await batch.commit();
  }
  // --- ▲ [추가] ---


  UploadTask _uploadFileTask({
    required String churchName,
    required String fileName,
    required Uint8List fileBytes,
    required String contentType,
  }) {
    final folderPath = '$churchName/';
    final filePath = '$folderPath$fileName';
    final ref = _storage.ref().child(filePath);
    final metadata = SettableMetadata(contentType: contentType);
    return ref.putData(fileBytes, metadata);
  }

  Future<void> createPost({
    required String churchName,
    required String authorId,
    required String authorName,
    required String description,
    required String? location,
    required List<PlatformFile> platformFiles,
    required void Function(double progress) onProgress,
  }) async {
    List<String> mediaUrls = [];
    List<bool> isVideoList = [];

    onProgress(0.0);
    await Future.delayed(const Duration(milliseconds: 100));

    Map<String, Uint8List> filesToUpload = {};
    int totalBytes = 0;

    for (var platformFile in platformFiles) {
      Uint8List? fileBytes;
      if (kIsWeb) {
        fileBytes = platformFile.bytes;
      } else if (platformFile.path != null) {
        fileBytes = await File(platformFile.path!).readAsBytes();
      }

      if (fileBytes == null) continue;

      final isVideo = platformFile.extension?.toLowerCase() == 'mp4' ||
          platformFile.extension?.toLowerCase() == 'mov';

      Uint8List bytesToUpload;
      String fileName;

      if (isVideo) {
        bytesToUpload = fileBytes;
        fileName = '${const Uuid().v4()}_${platformFile.name}';
      } else {
        final image = img.decodeImage(fileBytes);
        if (image == null) continue;
        bytesToUpload = Uint8List.fromList(img.encodeJpg(image, quality: 85));
        fileName = '${const Uuid().v4()}_${p.basenameWithoutExtension(platformFile.name)}.jpg';
      }

      filesToUpload[fileName] = bytesToUpload;
      totalBytes += bytesToUpload.length;
    }

    if (totalBytes == 0) {
      onProgress(1.0);
      throw Exception('업로드할 파일이 없습니다.');
    }

    int uploadedBytes = 0;

    for (var entry in filesToUpload.entries) {
      final fileName = entry.key;
      final fileBytes = entry.value;
      final isVideo = p.extension(fileName).toLowerCase() == '.mp4' ||
          p.extension(fileName).toLowerCase() == '.mov';

      final uploadTask = _uploadFileTask(
        churchName: churchName,
        fileName: fileName,
        fileBytes: fileBytes,
        contentType: isVideo ? 'video/mp4' : 'image/jpeg',
      );

      await for (var snapshot in uploadTask.snapshotEvents) {
        final currentFileProgress = snapshot.bytesTransferred;
        final overallProgress = (uploadedBytes + currentFileProgress) / totalBytes;
        onProgress(overallProgress > 1.0 ? 1.0 : overallProgress);
      }

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      mediaUrls.add(downloadUrl);
      isVideoList.add(isVideo);

      uploadedBytes += fileBytes.length;
    }

    onProgress(1.0);

    final newPost = Post(
      id: const Uuid().v4(),
      authorId: authorId,
      authorName: authorName,
      mediaUrls: mediaUrls,
      isVideoList: isVideoList,
      description: description,
      location: location,
      createdAt: DateTime.now(),
      // likes와 commentCount는 기본값(빈 리스트, 0)으로 생성됨
    );

    await _firestore
        .collection('churches')
        .doc(churchName)
        .collection('posts')
        .doc(newPost.id)
        .set(newPost.toFirestore());

    // ✨ [추가] 2. 게시물 작성 성공 후, 점수 및 로그 기록
    await _userService.addSkyScore(
      userId: authorId,
      church: churchName,
      reason: '밀알스타그램 게시물 작성',
      score: 3, // 3점 부여
    );
  }

  // [수정] getPosts 함수를 페이지네이션이 가능한 형태로 변경합니다.
  Future<Map<String, dynamic>> getPostsPaginated({
    String? churchName,
    DocumentSnapshot? lastDocument, // 마지막으로 로드된 문서
    int limit = 10, // 한 번에 불러올 개수
  }) async {
    // 쿼리 시작
    Query query;
    // ✨ [수정] churchName 유무에 따라 쿼리를 분기합니다.
    if (churchName != null && churchName.isNotEmpty) {
      // churchName이 있으면 -> 특정 교회의 게시물만 쿼리
      query = _firestore
          .collection('churches')
          .doc(churchName)
          .collection('posts')
          .orderBy('createdAt', descending: true);
    } else {
      // churchName이 없으면 (null) -> 모든 교회의 게시물을 쿼리 (Collection Group)
      query = _firestore
          .collectionGroup('posts')
          .orderBy('createdAt', descending: true);
    }

    // lastDocument가 있으면 그 다음부터 쿼리를 시작합니다.
    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    // 지정된 limit만큼 문서를 가져옵니다.
    final querySnapshot = await query.limit(limit).get();

    final posts = querySnapshot.docs
        .map((doc) => Post.fromFirestore(doc))
        .toList();

    // 마지막으로 불러온 문서를 반환하여 다음 페이지 요청에 사용합니다.
    final newLastDocument = querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null;

    return {
      'posts': posts,
      'lastDocument': newLastDocument,
    };
  }



  /// --- ▼ [추가] 단일 게시물 정보를 실시간으로 가져오는 함수 ---
  /// post_detail_page.dart에서 게시물의 좋아요 수 변경 등을 실시간으로 감지하기 위해 사용됩니다.
  Stream<Post> getPostStream(String churchName, String postId) {
    return _firestore
        .collection('churches')
        .doc(churchName)
        .collection('posts')
        .doc(postId)
        .snapshots()
        .map((doc) => Post.fromFirestore(doc));
  }
  /// --- ▲ [추가] ---

  Future<void> deletePost({
    required String churchName,
    required Post post,
  }) async {
    // 1. Storage에서 모든 미디어 파일 삭제
    for (final url in post.mediaUrls) {
      try {
        final ref = _storage.refFromURL(url);
        await ref.delete();
      } catch (e) {
        print('Failed to delete file from storage: $url. Error: $e');
      }
    }

    // 2. Firestore에서 게시물 문서 삭제
    await _firestore
        .collection('churches')
        .doc(churchName)
        .collection('posts')
        .doc(post.id)
        .delete();
  }
}