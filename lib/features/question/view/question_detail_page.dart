// lib/features/question/view/question_detail_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:narrow_gil/features/question/models/answer_model.dart';
import 'package:narrow_gil/features/question/models/question_model.dart';
import 'package:narrow_gil/features/question/services/question_service.dart';
import 'package:narrow_gil/features/question/view/add_question_page.dart';
import 'package:narrow_gil/home/bloc/home_bloc.dart';

class QuestionDetailPage extends StatefulWidget {
  final String questionId;
  const QuestionDetailPage({super.key, required this.questionId});

  @override
  State<QuestionDetailPage> createState() => _QuestionDetailPageState();
}

class _QuestionDetailPageState extends State<QuestionDetailPage> {
  final QuestionService _questionService = QuestionService();
  final TextEditingController _answerController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _postAnswer() {
    if (_answerController.text.trim().isEmpty) return;
    final homeState = context.read<HomeBloc>().state;
    if (homeState is HomeLoadSuccess) {
      final user = homeState.userProfile;
      _questionService
          .addAnswer(
        questionId: widget.questionId,
        content: _answerController.text.trim(),
        authorId: user.uid,
        authorName: user.name,
        church: user.church,
      )
          .then((_) {
        _answerController.clear();
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _showDeleteConfirmDialog(String questionId) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('글 삭제'),
              content:
                  const Text('정말로 이 글과 모든 답변을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      await _questionService.deleteQuestion(questionId);
                      Navigator.of(context).pop(); // 다이얼로그 닫기
                      Navigator.of(context).pop(); // 상세 페이지 닫기
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('글이 삭제되었습니다.')));
                    } catch (e) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('삭제 중 오류 발생: $e')));
                    }
                  },
                  child: const Text('삭제', style: TextStyle(color: Colors.red)),
                ),
              ],
            ));
  }

  @override
  void dispose() {
    _answerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // --- ▼ [수정] Bloc 상태를 build 메서드 최상단에서 한 번만 가져오기 ▼ ---
    final homeState = context.watch<HomeBloc>().state;
    if (homeState is! HomeLoadSuccess) {
      return const Scaffold(body: Center(child: Text("사용자 정보를 불러올 수 없습니다.")));
    }
    final user = homeState.userProfile;
    const adminRoles = ['목회자', '서기', '개발자'];
    final bool isAdmin = adminRoles.contains(homeState.userRole);
    // --- ▲ [수정] Bloc 상태를 build 메서드 최상단에서 한 번만 가져오기 ▲ ---

    // --- ▼ [수정] StreamBuilder가 Scaffold 전체를 감싸도록 변경 ▼ ---
    return StreamBuilder<DocumentSnapshot>(
      stream: _questionService.getQuestionStream(widget.questionId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
              appBar: AppBar(),
              body: const Center(child: CircularProgressIndicator()));
        }
        final question = QuestionModel.fromFirestore(snapshot.data!);

        return Scaffold(
          appBar: AppBar(
            title: const Text('글 상세'),
            // --- ▼ [추가] 글 작성자 및 관리자에게만 수정/삭제 아이콘 표시 ▼ ---
            actions: [
              if (question.authorId == user.uid)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BlocProvider.value(
                            value: context.read<HomeBloc>(),
                            // 글 수정 시에는 기존 QuestionModel을 전달
                            child: AddQuestionPage(questionToEdit: question),
                          ),
                        ));
                  },
                  tooltip: '수정하기',
                ),
              if (isAdmin || question.authorId == user.uid)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _showDeleteConfirmDialog(question.id),
                  tooltip: '삭제하기',
                ),
            ],
            // --- ▲ [추가] 글 작성자 및 관리자에게만 수정/삭제 아이콘 표시 ▲ ---
          ),
          body: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverToBoxAdapter(child: _buildQuestionContent(question)),
                    _buildAnswerList(widget.questionId),
                  ],
                ),
              ),
              _buildAnswerInputField(),
            ],
          ),
        );
      },
    );
    // --- ▲ [수정] StreamBuilder가 Scaffold 전체를 감싸도록 변경 ▲ ---
  }

  Widget _buildQuestionContent(QuestionModel question) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목
          Text(
            question.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          // 작성자 및 날짜
          Row(
            children: [
              Text(
                question.authorName,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(width: 8),
              Text(
                DateFormat('yyyy-MM-dd HH:mm')
                    .format(question.createdAt.toDate()),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
          const Divider(height: 32),
          // 내용
          _buildSection('글 내용', question.content),
          _buildSection('글 배경', question.background),
          const Divider(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(fontSize: 16, height: 1.6),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildAnswerList(String questionId) {
    return StreamBuilder<List<AnswerModel>>(
      stream: _questionService.getAnswers(questionId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final answers = snapshot.data!;
        if (answers.isEmpty) {
          return const SliverToBoxAdapter(
            child: Center(
                child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('아직 등록된 답변이 없습니다.'),
            )),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final answer = answers[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(answer.content,
                          style: const TextStyle(fontSize: 15)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            answer.authorName,
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MM-dd HH:mm')
                                .format(answer.createdAt.toDate()),
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
            childCount: answers.length,
          ),
        );
      },
    );
  }

  // ✨ [수정] 답변 입력 UI 전체 수정
  Widget _buildAnswerInputField() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _answerController,
                decoration: InputDecoration(
                  hintText: '답변을 입력하세요...',
                  // ✨ [수정] 텍스트 필드에 외곽선을 추가하여 영역을 명확히 합니다.
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  filled: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                maxLines: 5,
                minLines: 1,
                textInputAction: TextInputAction.newline,
              ),
            ),
            const SizedBox(width: 8),
            // ✨ [수정] IconButton을 ElevatedButton으로 변경하여 더 눈에 띄게 만듭니다.
            ElevatedButton(
              onPressed: _postAnswer,
              style: ElevatedButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(12),
              ),
              child: const Icon(Icons.arrow_upward_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
