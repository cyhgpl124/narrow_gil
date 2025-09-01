import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:narrow_gil/features/gallery/models/comment_model.dart';
import 'package:narrow_gil/features/gallery/models/post_model.dart';
import 'package:narrow_gil/features/gallery/services/post_service.dart';
import 'package:narrow_gil/features/gallery/view/video_player_page.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:narrow_gil/home/bloc/home_bloc.dart';

class PostDetailPage extends StatefulWidget {
  final Post post;
  final int initialPage;

  const PostDetailPage({
    super.key,
    required this.post,
    this.initialPage = 0,
  });

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final PostService _postService = PostService();
  final TextEditingController _commentController = TextEditingController();
  late final CarouselSliderController _carouselController;

  @override
  void initState() {
    super.initState();
    _carouselController = CarouselSliderController();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  /// 댓글을 Firestore에 추가하는 함수
  void _addComment() {
    final userProfile = (context.read<HomeBloc>().state as HomeLoadSuccess).userProfile;
    final text = _commentController.text.trim();
    if (text.isNotEmpty) {
      _postService.addComment(
        churchName: userProfile.church,
        postId: widget.post.id,
        text: text,
        authorId: userProfile.uid,
        authorName: userProfile.name,
      );
      _commentController.clear();
      FocusScope.of(context).unfocus(); // 댓글 작성 후 키보드 숨기기
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = (context.watch<HomeBloc>().state as HomeLoadSuccess).userProfile;

    // --- ▼ [수정] StreamBuilder를 사용하여 게시물 데이터(좋아요 등)를 실시간으로 감지 ---
    return StreamBuilder<Post>(
      stream: _postService.getPostStream(userProfile.church, widget.post.id),
      builder: (context, snapshot) {
        // 스트림으로부터 최신 post 데이터를 가져옵니다. 데이터가 없으면 기존 widget.post를 사용합니다.
        final post = snapshot.hasData ? snapshot.data! : widget.post;
        final isLiked = post.likes.contains(userProfile.uid);

        return Scaffold(
          appBar: AppBar(
            title: Text('${post.authorName}님의 게시물'),
          ),
          body: Column(
            children: [
              // --- ▼ [수정] 게시물 내용과 댓글 목록을 스크롤 가능하게 구성 ---
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 미디어 캐러셀
                      if (post.mediaUrls.isNotEmpty)
                        CarouselSlider.builder(
                          carouselController: _carouselController,
                          itemCount: post.mediaUrls.length,
                          itemBuilder: (context, index, realIndex) {
                            final url = post.mediaUrls[index];
                            final isVideo = post.isVideoList[index];
                            if (isVideo) {
                              return GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayerPage(videoUrl: url))),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Image.network(url, fit: BoxFit.contain), // 썸네일 역할
                                    const Icon(Icons.play_circle_outline, color: Colors.white70, size: 60),
                                  ],
                                ),
                              );
                            } else {
                              return InteractiveViewer(
                                child: Center(child: Image.network(url, fit: BoxFit.contain)),
                              );
                            }
                          },
                          options: CarouselOptions(
                            height: 350,
                            viewportFraction: 1.0,
                            enableInfiniteScroll: false,
                            initialPage: widget.initialPage,
                          ),
                        ),

                      // 본문 및 액션 버튼 (좋아요 등)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(post.description),
                            const SizedBox(height: 8),
                            Text(
                              DateFormat('yyyy년 MM월 dd일').format(post.createdAt),
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                            ),
                            const Divider(height: 24),
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    isLiked ? Icons.favorite : Icons.favorite_border,
                                    color: isLiked ? Colors.red : null,
                                  ),
                                  onPressed: () => _postService.toggleLike(userProfile.church, post.id, userProfile.uid),
                                ),
                                Text('${post.likes.length}'),
                                const SizedBox(width: 16),
                                Icon(Icons.mode_comment_outlined, color: Colors.grey.shade600),
                                const SizedBox(width: 8),
                                Text('${post.commentCount}'),
                              ],
                            ),
                            const Divider(height: 24),
                          ],
                        ),
                      ),

                      // 댓글 목록
                      _buildCommentList(userProfile.church, post.id),
                    ],
                  ),
                ),
              ),
              // --- ▲ [수정] ---

              // --- ▼ [추가] 댓글 입력창 ---
              _buildCommentInputField(),
              // --- ▲ [추가] ---
            ],
          ),
        );
      },
    );
    // --- ▲ [수정] ---
  }

  // --- ▼ [추가] 댓글 목록 UI를 생성하는 위젯 ---
  Widget _buildCommentList(String churchName, String postId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('댓글', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          StreamBuilder<List<Comment>>(
            stream: _postService.getComments(churchName, postId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Text('첫 댓글을 작성해보세요!'),
                ));
              }
              final comments = snapshot.data!;
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  final comment = comments[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(child: Text(comment.authorName.substring(0, 1))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(comment.authorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(comment.text),
                            ],
                          ),
                        ),
                        Text(
                          DateFormat('MM.dd').format(comment.timestamp.toDate()),
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
  // --- ▲ [추가] ---

  // --- ▼ [추가] 댓글 입력창 UI를 생성하는 위젯 ---
  Widget _buildCommentInputField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Colors.grey.shade800)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: const InputDecoration(
                  hintText: '댓글을 입력하세요...',
                  border: InputBorder.none,
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _addComment(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _addComment,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ],
        ),
      ),
    );
  }
  // --- ▲ [추가] ---
}