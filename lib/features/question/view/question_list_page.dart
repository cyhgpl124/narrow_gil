// lib/features/question/view/question_list_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:narrow_gil/features/question/models/question_model.dart';
import 'package:narrow_gil/features/question/services/question_service.dart';
import 'package:narrow_gil/features/question/view/add_question_page.dart';
import 'package:narrow_gil/features/question/view/question_detail_page.dart';
import 'package:narrow_gil/home/bloc/home_bloc.dart';

class QuestionListPage extends StatefulWidget {
  const QuestionListPage({super.key});

  @override
  State<QuestionListPage> createState() => _QuestionListPageState();
}

class _QuestionListPageState extends State<QuestionListPage> {
  final QuestionService _questionService = QuestionService();
  final ScrollController _scrollController = ScrollController();

  // 페이지네이션 상태 관리 변수
  bool _isLoading = true;
  bool _isLoadingMore = false;
  List<QuestionModel> _questions = [];
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  String? _errorMessage; // ✨ [추가] 오류 메시지를 저장할 상태 변수

  @override
  void initState() {
    super.initState();
    _loadInitialQuestions();

    // 스크롤 리스너 추가
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          _hasMore) {
        _loadMoreQuestions();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ✨ [수정] try-catch 구문에 오류 메시지를 상태에 저장하는 로직 추가
  Future<void> _loadInitialQuestions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null; // 로딩 시작 시 이전 오류 메시지 초기화
      _questions = [];
      _lastDocument = null;
      _hasMore = true;
    });
    try {
      final result = await _questionService.getInitialQuestions();
      if (mounted) {
        setState(() {
          _questions = [...result['hotQuestions'], ...result['coldQuestions']];
          _lastDocument = result['lastDocument'];
          _isLoading = false;
          if ((result['coldQuestions'] as List).length < 20) {
            _hasMore = false;
          }
        });
      }
    } catch (e) {
      debugPrint("질문 로딩 실패: $e");
      if(mounted) {
        setState(() {
          _isLoading = false;
          // Firestore 오류 메시지 전체를 저장하여 화면에 표시
          _errorMessage = "데이터를 불러오는 데 실패했습니다.\n\n오류 원인:\n$e";
        });
      }
    }
  }

  Future<void> _loadMoreQuestions() async {
    if (_lastDocument == null) return;
    setState(() => _isLoadingMore = true);

    try {
      final result = await _questionService.getMoreOldQuestions(_lastDocument!);
      if (mounted) {
        setState(() {
          _questions.addAll(result['questions']);
          _lastDocument = result['lastDocument'];
          _hasMore = result['hasMore'];
          _isLoadingMore = false;
        });
      }
    } catch (e) {
       if(mounted) setState(() => _isLoadingMore = false);
    }
  }

  // <<< 🚀 [추가] 좋아요/싫어요 실시간 반영을 위한 함수들 시작 🚀 >>>

  /// 좋아요 버튼 토글 핸들러
  void _toggleLike(String questionId, String userId) {
    // 1. UI에 즉시 반영할 데이터의 복사본 생성
    final int index = _questions.indexWhere((q) => q.id == questionId);
    if (index == -1) return;

    final QuestionModel oldQuestion = _questions[index];
    final List<String> newLikes = List<String>.from(oldQuestion.likes);
    final List<String> newDislikes = List<String>.from(oldQuestion.dislikes);
    bool isLiked = newLikes.contains(userId);

    if (isLiked) {
      newLikes.remove(userId);
    } else {
      newLikes.add(userId);
      newDislikes.remove(userId); // 싫어요 목록에서 제거
    }

    final QuestionModel newQuestion = QuestionModel(
      id: oldQuestion.id,
      title: oldQuestion.title,
      content: oldQuestion.content,
      background: oldQuestion.background,
      authorId: oldQuestion.authorId,
      authorName: oldQuestion.authorName,
      createdAt: oldQuestion.createdAt,
      isHidden: oldQuestion.isHidden,
      likes: newLikes,
      dislikes: newDislikes,
      likesCount: newLikes.length, // 좋아요 수 업데이트
    );

    // 2. setState를 호출하여 화면을 즉시 갱신 (Optimistic Update)
    setState(() {
      _questions[index] = newQuestion;
    });

    // 3. 백그라운드에서 Firestore 데이터 업데이트 시도
    _questionService.toggleLike(questionId, userId).catchError((error) {
      // 4. 만약 오류가 발생하면 원래 상태로 롤백하고 사용자에게 알림
      if(mounted) {
        setState(() {
          _questions[index] = oldQuestion;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')),
        );
      }
    });
  }

  /// 싫어요 버튼 토글 핸들러
  void _toggleDislike(String questionId, String userId) {
    final int index = _questions.indexWhere((q) => q.id == questionId);
    if (index == -1) return;

    final QuestionModel oldQuestion = _questions[index];
    final List<String> newLikes = List<String>.from(oldQuestion.likes);
    final List<String> newDislikes = List<String>.from(oldQuestion.dislikes);
    bool isDisliked = newDislikes.contains(userId);

    if (isDisliked) {
      newDislikes.remove(userId);
    } else {
      newDislikes.add(userId);
      newLikes.remove(userId); // 좋아요 목록에서 제거
    }

    final QuestionModel newQuestion = QuestionModel(
        id: oldQuestion.id,
        title: oldQuestion.title,
        content: oldQuestion.content,
        background: oldQuestion.background,
        authorId: oldQuestion.authorId,
        authorName: oldQuestion.authorName,
        createdAt: oldQuestion.createdAt,
        isHidden: newDislikes.length >= 10, // 싫어요 10개 이상이면 숨김 처리
        likes: newLikes,
        dislikes: newDislikes,
        likesCount: newLikes.length);

    setState(() {
      _questions[index] = newQuestion;
    });

    _questionService.toggleDislike(questionId, userId).catchError((error) {
       if(mounted) {
        setState(() {
          _questions[index] = oldQuestion;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')),
        );
      }
    });
  }
  // <<< 🚀 [추가] 좋아요/싫어요 실시간 반영을 위한 함수들 끝 🚀 >>>



  @override
  Widget build(BuildContext context) {
    final homeState = context.watch<HomeBloc>().state;
    if (homeState is! HomeLoadSuccess) {
      return const Scaffold(body: Center(child: Text("사용자 정보를 불러올 수 없습니다.")));
    }
    final user = homeState.userProfile;
    final userRole = homeState.userRole;
    const adminRoles = ['목회자', '서기', '개발자'];
    final bool isAdmin = adminRoles.contains(userRole);

    return Scaffold(
      appBar: AppBar(
        title: const Text('신앙토론 질문'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadInitialQuestions,
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _questions.length + (_isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _questions.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final question = _questions[index];
                  if (question.isHidden && !isAdmin) {
                    return const SizedBox.shrink();
                  }
                  return _buildQuestionCard(context, question, user.uid, isAdmin);
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push<bool>(context, MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: BlocProvider.of<HomeBloc>(context),
                child: const AddQuestionPage(),
              ),
            ),
          );
          // 새 질문 작성 후 목록을 새로고침합니다.
          if (result == true) {
            _loadInitialQuestions();
          }
        },
        child: const Icon(Icons.add),
        tooltip: '질문하기',
      ),
    );
  }

  Widget _buildQuestionCard(BuildContext context, QuestionModel question, String currentUserId, bool isAdmin) {
    final bool isLiked = question.likes.contains(currentUserId);
    final bool isHiddenAndVisible = question.isHidden && isAdmin;
    // --- ▼ [추가] 현재 사용자가 싫어요를 눌렀는지 확인 ▼ ---
    final bool isDisliked = question.dislikes.contains(currentUserId);
    // --- ▲ [추가] 현재 사용자가 싫어요를 눌렀는지 확인 ▲ ---

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isHiddenAndVisible ? Colors.grey.shade300 : null,
      child: InkWell(
        onTap: () {
          // --- ▼ [수정] BlocProvider.value를 사용하여 HomeBloc 전달 ▼ ---
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: BlocProvider.of<HomeBloc>(context), // 현재 context의 HomeBloc을
                child: QuestionDetailPage(questionId: question.id), // QuestionDetailPage로 전달
              ),
            ),
          );
          // --- ▲ [수정] BlocProvider.value를 사용하여 HomeBloc 전달 ▲ ---
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isHiddenAndVisible)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    '[숨김 처리됨]',
                    style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold),
                  ),
                ),
              Text(
                question.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    question.authorName,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('yyyy-MM-dd').format(question.createdAt.toDate()),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    // <<< ✨ [수정] 새로 만든 핸들러 함수 호출
                    onPressed: () => _toggleLike(question.id, currentUserId),
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.red : Colors.grey,
                    ),
                    label: Text(
                      question.likes.length.toString(),
                      style: TextStyle(color: isLiked ? Colors.red : Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    // <<< ✨ [수정] 새로 만든 핸들러 함수 호출
                    onPressed: () => _toggleDislike(question.id, currentUserId),
                    icon: Icon(
                      isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                      color: isDisliked ? Colors.blue : Colors.grey,
                    ),
                    tooltip: '싫어요',
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}