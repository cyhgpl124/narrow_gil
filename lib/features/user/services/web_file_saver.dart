// lib/features/user/services/web_file_saver.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:html' as html;

Future<void> saveFile(BuildContext context, Uint8List bytes, String fileName, {String mimeType = 'application/octet-stream'}) async {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute("download", fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('${fileName} 다운로드가 시작되었습니다.')),
  );
}