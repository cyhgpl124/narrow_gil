// lib/features/user/services/mobile_file_saver.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

Future<void> saveFile(BuildContext context, Uint8List bytes, String fileName, {String? mimeType}) async {
  final directory = await getApplicationDocumentsDirectory();
  final path = '${directory.path}/$fileName';
  final file = File(path);
  await file.writeAsBytes(bytes, flush: true);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('파일이 $path 에 저장되었습니다.'),
      action: SnackBarAction(
        label: '열기',
        onPressed: () => OpenFile.open(path),
      ),
    ),
  );
}