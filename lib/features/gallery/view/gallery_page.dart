import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:narrow_gil/features/gallery/models/post_model.dart';
import 'package:narrow_gil/features/gallery/services/post_service.dart';
import 'package:narrow_gil/features/gallery/view/create_post_page.dart';
import 'package:narrow_gil/features/gallery/view/post_detail_page.dart';
import 'package:narrow_gil/features/gallery/view/video_player_page.dart';
import 'package:narrow_gil/home/bloc/home_bloc.dart';
import 'package:narrow_gil/home/models/user_profile.dart';
import 'package:carousel_slider/carousel_slider.dart';

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  final PostService _postService = PostService();
  final ScrollController _scrollController = ScrollController();

    // ✨ [수정] 필터 관련 상태 변수들
  List<String> _churchList = []; // 전체 교회 목록을 담을 리스트
  String? _selectedFilter;      // 현재 선택된 필터 (교회 이름 또는 '전체')

  List<Post> _posts = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    // ✨ [수정] 페이지가 시작될 때 교회 목록을 먼저 불러온 후, 게시물을 로드합니다.
    _fetchChurchList().then((_) {
      // 교회 목록 로드가 완료되면, 사용자의 교회를 기본 필터로 설정하고 첫 게시물을 불러옵니다.
      final userProfile = _getUserProfile();
      if (mounted) {
        setState(() {
          _selectedFilter = userProfile.church;
        });
        _loadInitialPosts();
      }
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent * 0.95 &&
          !_isLoadingMore &&
          _hasMore) {
        _loadMorePosts();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  UserProfile _getUserProfile() {
    final homeState = context.read<HomeBloc>().state;
    if (homeState is HomeLoadSuccess) {
      return homeState.userProfile;
    }
    throw Exception("User profile not available.");
  }

  // ✨ [추가] Firestore에서 교회 목록을 가져와 상태에 저장하는 함수
  Future<void> _fetchChurchList() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('churches').get();
      // 문서 ID(교회 이름)를 리스트로 변환하고 정렬합니다.
      final churches = snapshot.docs.map((doc) => doc.id).toList()..sort();
      if (mounted) {
        setState(() {
          // '전체' 옵션을 맨 앞에 추가하여 최종 목록을 만듭니다.
          _churchList = ['전체', ...churches];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('교회 목록을 불러오는 데 실패했습니다: $e')));
      }
    }
  }

  Future<void> _loadInitialPosts() async {

    if (_selectedFilter == null) return;

    setState(() {
      _isLoading = true;
      _hasMore = true;
      _posts = [];
      _lastDocument = null;
    });

    try {

        // ✨ [수정] 선택된 필터에 따라 churchName을 다르게 전달 ('전체'일 경우 null)
        final churchToFetch = (_selectedFilter == '전체') ? null : _selectedFilter;
        final result = await _postService.getPostsPaginated(churchName: churchToFetch);


        if (mounted) {
            setState(() {
                _posts = result['posts'];
                _lastDocument = result['lastDocument'];
                _isLoading = false;
                if ((result['posts'] as List).length < 10) {
                    _hasMore = false;
                }
            });
        }
    } catch (e) {
        if(mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('게시물 로드 오류: $e')));
        }
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore) return;
    setState(() { _isLoadingMore = true; });

    try {
         // ✨ [수정] 선택된 필터에 따라 churchName을 다르게 전달 ('전체'일 경우 null)
        final churchToFetch = (_selectedFilter == '전체') ? null : _selectedFilter;
        final result = await _postService.getPostsPaginated(
          churchName: churchToFetch,
          lastDocument: _lastDocument,
        );

        final List<Post> newPosts = result['posts'];

        if (mounted) {
            setState(() {
                _posts.addAll(newPosts);
                _lastDocument = result['lastDocument'];
                if (newPosts.isEmpty) {
                    _hasMore = false;
                }
            });
        }
    } catch(e) {
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('추가 게시물 로드 오류: $e')));
        }
    } finally {
        if(mounted) {
            setState(() { _isLoadingMore = false; });
        }
    }
  }

  // ✨ [추가] 좋아요 상태를 즉시 UI에 반영하는 함수
  void _handleLikeToggle(Post post) {
    final currentUser = _getUserProfile();
    final isLiked = post.likes.contains(currentUser.uid);

    // UI를 먼저 업데이트 (Optimistic Update)
    setState(() {
      if (isLiked) {
        post.likes.remove(currentUser.uid);
      } else {
        post.likes.add(currentUser.uid);
      }
    });

    // 그 다음 Firestore에 변경사항을 전송
    try {
      _postService.toggleLike(currentUser.church, post.id, currentUser.uid);
    } catch (e) {
      // 만약 Firestore 업데이트가 실패하면, UI를 원래대로 되돌림
      setState(() {
        if (isLiked) {
          post.likes.add(currentUser.uid);
        } else {
          post.likes.remove(currentUser.uid);
        }
      });
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('좋아요 처리에 실패했습니다.')));
      }
    }
  }

  Future<void> _pickAndUploadMedia() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.media,
        allowMultiple: true,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final validFiles = result.files.where((file) {
        return kIsWeb ? file.bytes != null : file.path != null;
      }).toList();

      if (validFiles.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('유효한 파일을 선택하지 않았습니다.')),
          );
        }
        return;
      }

      final userProfile = _getUserProfile();
      final uploadSuccess = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => CreatePostPage(
            files: validFiles,
            userProfile: userProfile,
          ),
        ),
      );

      if (uploadSuccess == true) {
        _loadInitialPosts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('파일 선택 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Future<void> _handleDeletePost(Post post) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('게시물 삭제'),
          content: const Text('정말로 삭제하시겠습니까?'),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('삭제'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    // ✨ [수정] isLoading은 전체 화면 로딩이므로 삭제 후 UI에서 직접 제거
    setState(() {
      _posts.remove(post);
    });

    try {
      final userProfile = _getUserProfile();
      await _postService.deletePost(
        churchName: userProfile.church,
        post: post,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('게시물이 삭제되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        // ✨ [수정] 삭제 실패 시 다시 목록에 추가
        setState(() {
            _loadInitialPosts(); // 목록을 아예 새로고침
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final UserProfile currentUser;
    try {
      currentUser = _getUserProfile();
    } catch (e) {
      return Scaffold(
        appBar: AppBar(title: const Text('밀알스타그램')),
        body: const Center(child: Text('사용자 정보를 불러오는 중입니다...')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('밀알스타그램'),
      ),
      body: Column(
        children: [
          // ✨ [수정] ToggleButtons를 DropdownButtonFormField로 교체
          if (_churchList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
              child: DropdownButtonFormField<String>(
                value: _selectedFilter,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                ),
                items: _churchList.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null && _selectedFilter != newValue) {
                    setState(() {
                      _selectedFilter = newValue;
                    });
                    _loadInitialPosts(); // 필터 변경 시 데이터 새로고침
                  }
                },
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadInitialPosts,
                    child: _posts.isEmpty
                        ? const Center(child: Text("게시물이 없습니다."))
                        : ListView.builder(
                            controller: _scrollController,
                            itemCount: _posts.length + (_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _posts.length) {
                                return _isLoadingMore
                                    ? const Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Center(child: CircularProgressIndicator()),
                                      )
                                    : const SizedBox.shrink();
                              }
                              final post = _posts[index];
                              return PostCard(
                                post: post,
                                currentUser: currentUser,
                                onDelete: () => _handleDeletePost(post),
                                onLike: () => _handleLikeToggle(post),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickAndUploadMedia,
        tooltip: '새 게시물 작성',
        child: const Icon(Icons.add_a_photo_outlined),
      ),
    );
  }
}

class PostCard extends StatelessWidget { // ✨ [수정] 상태가 없으므로 StatelessWidget으로 변경
  final Post post;
  final UserProfile currentUser;
  final VoidCallback onDelete;
  final VoidCallback onLike;

  const PostCard({
    super.key,
    required this.post,
    required this.currentUser,
    required this.onDelete,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasMedia = post.mediaUrls.isNotEmpty;
    final bool isAuthor = post.authorId == currentUser.uid;
    final bool isLiked = post.likes.contains(currentUser.uid);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12.0, 12.0, 4.0, 12.0),
            child: Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    post.authorName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.grey,
                  ),
                  onPressed: onLike,
                ),
                Text('${post.likes.length}'),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.mode_comment_outlined, color: Colors.grey),
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                        value: context.read<HomeBloc>(),
                        child: PostDetailPage(post: post),
                      ),
                    ));
                  },
                ),
                Text('${post.commentCount}'),
                const SizedBox(width: 4),
                if (isAuthor)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: '게시글 삭제',
                    onPressed: onDelete,
                  ),
              ],
            ),
          ),
          if (hasMedia)
            _MediaCarousel(post: post), // ✨ [추가] 미디어 부분을 별도 위젯으로 분리
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post.description),
                const SizedBox(height: 8),
                if (post.location != null && post.location!.isNotEmpty)
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(post.location!, style: TextStyle(color: Colors.grey.shade600)),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('yyyy년 MM월 dd일').format(post.createdAt),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ✨ [추가] PostCard의 미디어 캐러셀 부분을 별도의 StatefulWidget으로 분리
class _MediaCarousel extends StatefulWidget {
  const _MediaCarousel({required this.post});
  final Post post;

  @override
  State<_MediaCarousel> createState() => __MediaCarouselState();
}

class __MediaCarouselState extends State<_MediaCarousel> {
  int _currentPage = 0;
  final CarouselSliderController _controller = CarouselSliderController();

  @override
  Widget build(BuildContext context) {
    final bool showDots = widget.post.mediaUrls.length > 1;
    final bool showArrows = widget.post.mediaUrls.length > 1 && !kIsWeb;

    return Stack(
      alignment: Alignment.center,
      children: [
        CarouselSlider.builder(
          carouselController: _controller,
          itemCount: widget.post.mediaUrls.length,
          itemBuilder: (context, index, realIndex) {
            final url = widget.post.mediaUrls.elementAt(index);
            final isVideo = widget.post.isVideoList.elementAt(index);
            return GestureDetector(
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<HomeBloc>(),
                    child: PostDetailPage(
                      post: widget.post,
                      initialPage: _currentPage,
                    ),
                  ),
                ));
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    color: Colors.black.withOpacity(0.1),
                    child: Image.network(
                      isVideo ? widget.post.mediaUrls[index] : url, // 비디오면 썸네일, 아니면 이미지
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) =>
                          progress == null ? child : const Center(child: CircularProgressIndicator()),
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
                    ),
                  ),
                  if (isVideo)
                    const Icon(Icons.play_circle_outline, color: Colors.white, size: 60),
                ],
              ),
            );
          },
          options: CarouselOptions(
            height: 300,
            viewportFraction: 1.0,
            enableInfiniteScroll: false,
            onPageChanged: (index, reason) {
              setState(() { _currentPage = index; });
            },
          ),
        ),
        if (showArrows)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                  onPressed: () => _controller.previousPage(),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
                child: IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                  onPressed: () => _controller.nextPage(),
                ),
              ),
            ],
          ),
        if (showDots)
          Positioned(
            bottom: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(widget.post.mediaUrls.length, (int index) {
                return Container(
                  width: 8.0,
                  height: 8.0,
                  margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 2.0),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index ? Colors.blueAccent : Colors.white.withOpacity(0.8)),
                );
              }),
            ),
          ),
      ],
    );
  }
}