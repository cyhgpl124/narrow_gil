// lib/home/view/widgets/add_edit_notice_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:narrow_gil/home/bloc/home_bloc.dart';
import 'package:narrow_gil/home/models/notice_model.dart';

void showAddEditNoticeDialog(BuildContext context, {Notice? notice}) {
  final isEditing = notice != null;
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController(text: notice?.content ?? '');

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(isEditing ? '공지 수정' : '새 공지 등록'),
        content: Form(
          key: _formKey,
          child: TextFormField(
            controller: _contentController,
            autofocus: true,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: '공지 내용',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '내용을 입력해주세요.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                final content = _contentController.text.trim();
                if (isEditing) {
                  context
                      .read<HomeBloc>()
                      .add(HomeNoticeUpdated(notice.id, content));
                } else {
                  context.read<HomeBloc>().add(HomeNoticeAdded(content));
                }
                Navigator.of(dialogContext).pop();
              }
            },
            child: Text(isEditing ? '수정' : '등록'),
          ),
        ],
      );
    },
  );
}