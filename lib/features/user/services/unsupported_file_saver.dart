// lib/features/user/services/unsupported_file_saver.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';

Future<void> saveFile(BuildContext context, Uint8List bytes, String fileName, {String? mimeType}) async {
  throw UnsupportedError('File saving is not supported on this platform.');
}