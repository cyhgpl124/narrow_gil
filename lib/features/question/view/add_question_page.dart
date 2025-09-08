// lib/features/question/view/add_question_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:narrow_gil/features/question/models/question_model.dart';
import 'package:narrow_gil/features/question/services/question_service.dart';
import 'package:narrow_gil/home/bloc/home_bloc.dart';

class AddQuestionPage extends StatefulWidget {
  // --- ▼ [추가] 글 수정을 위해 기존 글 데이터를 전달받는 파라미터 ▼ ---
  final QuestionModel? questionToEdit;
  // --- ▲ [추가] 글 수정을 위해 기존 글 데이터를 전달받는 파라미터 ▲ ---

  const AddQuestionPage({super.key, this.questionToEdit});

  @override
  State<AddQuestionPage> createState() => _AddQuestionPageState();
}

class _AddQuestionPageState extends State<AddQuestionPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _backgroundController = TextEditingController();
  final QuestionService _questionService = QuestionService();

  bool _isLoading = false;
  // 수정 모드인지 확인하는 변수
  bool get _isEditing => widget.questionToEdit != null;

  @override
  void initState() {
    super.initState();
    // --- ▼ [추가] 수정 모드일 경우, 기존 데이터를 컨트롤러에 채워넣는 로직 ▼ ---
    if (_isEditing) {
      _titleController.text = widget.questionToEdit!.title;
      _contentController.text = widget.questionToEdit!.content;
      _backgroundController.text = widget.questionToEdit!.background;
    }
    // --- ▲ [추가] 수정 모드일 경우, 기존 데이터를 컨트롤러에 채워넣는 로직 ▲ ---
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  Future<void> _submitQuestion() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final homeState = context.read<HomeBloc>().state;
      if (homeState is HomeLoadSuccess) {
        final user = homeState.userProfile;

        try {
          if (_isEditing) {
            // 수정 모드일 경우 update 함수 호출
            await _questionService.updateQuestion(
              questionId: widget.questionToEdit!.id,
              title: _titleController.text.trim(),
              content: _contentController.text.trim(),
              background: _backgroundController.text.trim(),
            );
          } else {
            // 생성 모드일 경우 add 함수 호출
            await _questionService.addQuestion(
              title: _titleController.text.trim(),
              content: _contentController.text.trim(),
              background: _backgroundController.text.trim(),
              authorId: user.uid,
              authorName: user.name,
              church: user.church,
            );
          }

          if (mounted) {
            final message = _isEditing ? '글이 수정되었습니다.' : '글이 등록되었습니다.';
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(message)));
            Navigator.of(context).pop();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('오류가 발생했습니다: $e')));
          }
        } finally {
          if (mounted) {
            setState(() => _isLoading = false);
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '글 수정' : '글 작성'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _isLoading
                ? const Center(
                    child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator()))
                : TextButton(
                    onPressed: _submitQuestion,
                    child: Text(_isEditing ? '수정하기' : '등록하기'),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTextField(
                  controller: _titleController,
                  labelText: '글 제목',
                  hintText: '젬고을 입력해주세요.'),
              const SizedBox(height: 16),
              _buildTextField(
                  controller: _contentController,
                  labelText: '글 내용',
                  hintText: '나누고 싶은 글을 상세하게 작성해주세요.',
                  maxLines: 5),
              const SizedBox(height: 16),
              _buildTextField(
                  controller: _backgroundController,
                  labelText: '글 배경',
                  hintText: '이 글을 쓰게 된 계기나 배경을 설명해주세요.',
                  maxLines: 5),
            ],
          ),
        ),
      ),
    );
  }

  // <<< ✨ [수정] 텍스트 필드 위젯 수정 ✨ >>>
  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        border: const OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
      maxLines: maxLines,
      // 1. 여러 줄 입력이 가능할 경우, 키보드 타입을 multiline으로 변경
      keyboardType: maxLines > 1 ? TextInputType.multiline : TextInputType.text,
      // 2. 여러 줄 입력이 가능할 경우, 엔터 키(action)를 줄바꿈(newline)으로 변경
      textInputAction: maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '$labelText 항목을 입력해주세요.';
        }
        return null;
      },
    );
  }
  // <<< ✨ [수정] 여기까지 ✨ >>>
}
