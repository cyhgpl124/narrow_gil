// lib/home/view/widgets/notice_details_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:narrow_gil/home/models/notice_model.dart';

void showNoticeDetailsDialog(BuildContext context, Notice notice) {
  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('공지사항 상세보기'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(notice.content),
              const SizedBox(height: 16),
              Text(
                '작성자: ${notice.author}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                '작성일: ${DateFormat('yyyy년 MM월 dd일').format(notice.createdAt.toDate())}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('닫기'),
          ),
        ],
      );
    },
  );
}