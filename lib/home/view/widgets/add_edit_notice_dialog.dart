// lib/home/view/widgets/add_edit_notice_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:narrow_gil/home/bloc/home_bloc.dart';
import 'package:narrow_gil/home/models/notice_model.dart';

void showAddEditNoticeDialog(BuildContext context, {Notice? notice}) {
  showDialog(
    context: context,
    builder: (_) => BlocProvider.value(
      value: BlocProvider.of<HomeBloc>(context),
      child: _AddEditNoticeDialog(notice: notice),
    ),
  );
}

class _AddEditNoticeDialog extends StatefulWidget {
  final Notice? notice;
  const _AddEditNoticeDialog({this.notice});

  @override
  State<_AddEditNoticeDialog> createState() => _AddEditNoticeDialogState();
}

class _AddEditNoticeDialogState extends State<_AddEditNoticeDialog> {
  late final TextEditingController _contentController;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.notice?.content);
    // ✨ [수정] D-Day 초기값 설정: 기존 공지가 있으면 해당 날짜, 없으면 오늘 날짜
    _selectedDate = widget.notice?.dueDate.toDate() ?? DateTime.now();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final newDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate!,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (newDate != null) {
      setState(() {
        _selectedDate = newDate;
      });
    }
  }

  void _onSave() {
    final content = _contentController.text.trim();
    // ✨ [수정] 내용과 날짜가 모두 있어야 저장 가능
    if (content.isEmpty || _selectedDate == null) return;

    context.read<HomeBloc>().add(HomeNoticeSaved(
          id: widget.notice?.id,
          content: content,
          dueDate: _selectedDate!, // ✨ '!'를 사용하여 Null이 아님을 명시
        ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.notice == null ? '새 공지 등록' : '공지 수정'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _contentController,
            autofocus: true,
            decoration: const InputDecoration(hintText: '공지 내용을 입력하세요.'),
            maxLines: 3,
            // ✨ [추가] 내용이 바뀔 때마다 UI를 다시 그려서 저장 버튼 활성화 여부 체크
            onChanged: (text) => setState(() {}),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ✨ [수정] _selectedDate는 이제 null일 수 없으므로 '!' 사용
              Text(
                'D-Day: ${DateFormat('yyyy.MM.dd').format(_selectedDate!)}',
                style: const TextStyle(fontSize: 16),
              ),
              IconButton(
                icon: const Icon(Icons.calendar_month),
                tooltip: 'D-Day 선택',
                onPressed: () => _pickDate(context),
              )
            ],
          ),
          // ✨ [제거] 'D-Day 설정 취소' 버튼 제거
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        // ✨ [수정] 내용이 비어있으면 저장 버튼 비활성화
        TextButton(
          onPressed: _contentController.text.trim().isEmpty ? null : _onSave,
          child: const Text('저장'),
        ),
      ],
    );
  }
}