import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:dots_indicator/dots_indicator.dart';
import 'package:narrow_gil/features/gallery/services/address_search_service.dart';
import 'package:narrow_gil/features/gallery/services/post_service.dart';
import 'package:narrow_gil/home/models/user_profile.dart';
import 'package:carousel_slider/carousel_slider.dart'; // ✨ carousel_slider 패키지 import

class CreatePostPage extends StatefulWidget {
  // ✨ 이 부분은 기존과 완전히 동일합니다.
  final List<PlatformFile> files;
  final UserProfile userProfile;

  const CreatePostPage({super.key, required this.files, required this.userProfile});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  // ✨ 사용자의 기존 변수 선언은 그대로 유지됩니다.
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _postService = PostService();
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  int _currentPageIndex = 0;
  final _addressSearcher = AddressSearcher(); // ✨ AddressSearcher 인스턴스 생성


   @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    // ✨ 사용자의 기존 dispose 함수는 그대로 유지됩니다.
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

    // ✨ 플랫폼에 상관없이 이 한 줄로 주소 검색을 호출합니다.
  Future<void> _searchAddress() async {
    _addressSearcher.search(
      context,
      onAddressSelected: (String address) {
        if (mounted) {
          setState(() {
            _locationController.text = address;
          });
        }
      },
    );
  }

  // ✨ _submitPost 함수는 사용자의 기존 코드를 그대로 유지합니다.
  Future<void> _submitPost() async {
    if (_isUploading) return;
    if (_descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('게시물 내용을 입력해주세요.')));
      return;
    }
    setState(() { _isUploading = true; _uploadProgress = 0.0; });
    try {
      await _postService.createPost(
        churchName: widget.userProfile.church,
        authorId: widget.userProfile.uid,
        authorName: widget.userProfile.name,
        description: _descriptionController.text,
        location: _locationController.text.isNotEmpty ? _locationController.text : null,
        platformFiles: widget.files,
        onProgress: (progress) { if (mounted) { setState(() { _uploadProgress = progress; }); } },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('게시물이 성공적으로 업로드되었습니다! ✅')));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if(mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('게시물 업로드에 실패했습니다: $e'))); }
    } finally {
      if (mounted) { setState(() { _isUploading = false; }); }
    }
  }

  /// ✨ build 함수는 절대로 제거되지 않았습니다. 사용자의 기존 코드를 그대로 유지합니다.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('새 게시물 작성'),
        centerTitle: true,
        leading: _isUploading ? null : IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (!_isUploading)
            TextButton(
              onPressed: _submitPost,
              child: const Text('게시',
                  style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.files.isNotEmpty)
                  Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      // ✨ PageView.builder를 CarouselSlider.builder로 변경
                      CarouselSlider.builder(
                        itemCount: widget.files.length,
                        itemBuilder: (context, index, realIndex) {
                          final file = widget.files[index];
                          return Container(
                            width: double.infinity,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12)),
                            child: kIsWeb
                                ? Image.memory(file.bytes!, fit: BoxFit.contain)
                                : Image.file(File(file.path!), fit: BoxFit.contain),
                          );
                        },
                        options: CarouselOptions(
                          // CarouselSlider의 높이를 직접 지정합니다.
                          height: 250,
                          viewportFraction: 1.0, // 한 번에 하나만 보이게
                          enableInfiniteScroll: false,
                          onPageChanged: (index, reason) {
                            setState(() {
                              _currentPageIndex = index;
                            });
                          },
                        ),
                      ),
                      if (widget.files.length > 1)
                        Positioned( // CarouselSlider는 Stack 내에서 위치 조정이 자유로워 Positioned 사용
                          bottom: 12.0,
                          child: DotsIndicator(
                            dotsCount: widget.files.length,
                            position: _currentPageIndex.toDouble(),
                            decorator: DotsDecorator(
                              color: Colors.white.withOpacity(0.5),
                              activeColor: Colors.white,
                              size: const Size.square(8.0),
                              activeSize: const Size(18.0, 8.0),
                              activeShape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5.0)),
                            ),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 24),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    hintText: '문구를 입력해주세요...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                // ✨ onTap에 수정된 _searchAddress 함수가 연결됩니다.
                TextFormField(
                  controller: _locationController,
                  readOnly: true,
                  onTap: _searchAddress,
                  decoration: InputDecoration(
                    hintText: '장소 추가',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    suffixIcon: _locationController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _locationController.clear();
                              });
                            },
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
          if (_isUploading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('업로드 중...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 200,
                        child: LinearProgressIndicator(
                          value: _uploadProgress,
                          backgroundColor: Colors.grey.shade300,
                          minHeight: 10,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}