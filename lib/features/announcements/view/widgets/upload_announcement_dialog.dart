import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:narrow_gil/features/announcements/services/announcement_service.dart';

class UploadAnnouncementDialog extends StatefulWidget {
  final String churchName;
  final String authorId;
  final String authorName;

  const UploadAnnouncementDialog({
    super.key,
    required this.churchName,
    required this.authorId,
    required this.authorName,
  });

  @override
  State<UploadAnnouncementDialog> createState() => _UploadAnnouncementDialogState();
}

class _UploadAnnouncementDialogState extends State<UploadAnnouncementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contactController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  // ✨ [수정] PDF 대신 여러 이미지 파일을 저장할 리스트
  List<PlatformFile>? _imageFiles;
  bool _isUploading = false;

  // ✨ [수정] 여러 이미지를 선택하는 함수
  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true, // 여러 장 선택 허용
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _imageFiles = result.files;
      });
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate() &&
        _imageFiles != null && _imageFiles!.isNotEmpty &&
        _startDate != null &&
        _endDate != null) {
      setState(() { _isUploading = true; });
      try {
        await AnnouncementService().createAnnouncement(
          churchName: widget.churchName,
          title: _titleController.text,
          startDate: _startDate!,
          endDate: _endDate!,
          contact: _contactController.text,
          // ✨ [수정] 이미지 바이트와 파일 이름을 리스트로 변환하여 전달
          imageBytesList: _imageFiles!.map((file) => file.bytes!).toList(),
          fileNames: _imageFiles!.map((file) => file.name).toList(),
          authorId: widget.authorId,
          authorName: widget.authorName,
        );
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('공지사항이 등록되었습니다.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('업로드 실패: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() { _isUploading = false; });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('새 공지사항 등록'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: '제목'),
                validator: (value) => value!.isEmpty ? '제목을 입력하세요.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contactController,
                decoration: const InputDecoration(labelText: '연락처'),
                validator: (value) => value!.isEmpty ? '연락처를 입력하세요.' : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(_startDate == null || _endDate == null
                    ? '공지 기간 선택'
                    : '${DateFormat('yyyy.MM.dd').format(_startDate!)} - ${DateFormat('yyyy.MM.dd').format(_endDate!)}'),
                onTap: () => _selectDateRange(context),
              ),
              const SizedBox(height: 16),
              // ✨ [수정] PDF 선택 -> 이미지 선택 버튼으로 변경
              ElevatedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.photo_library),
                label: Text(_imageFiles == null ? '이미지 선택' : '${_imageFiles!.length}개 이미지 선택됨'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (_isUploading) const CircularProgressIndicator(),
        TextButton(
          onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: _isUploading ? null : _submit,
          child: const Text('등록'),
        ),
      ],
    );
  }
}