import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:dots_indicator/dots_indicator.dart';
import 'package:narrow_gil/features/gallery/services/post_service.dart';
import 'package:narrow_gil/home/models/user_profile.dart';
import 'package:carousel_slider/carousel_slider.dart'; // ✨ carousel_slider 패키지 import

// ✨ [수정] 웹뷰 및 웹 팝업 통신을 위한 import
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:html' as html;

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

  @override
  void initState() {
    super.initState();

    // ✨ [수정] 웹에서 카카오 주소 검색 팝업의 결과를 받기 위한 리스너
    if (kIsWeb) {
      html.window.addEventListener('message', (event) {
        final data = (event as html.MessageEvent).data;
        // 카카오 API는 data['address'] 형태로 값을 전달합니다.
        if (data != null && data['address'] != null) {
          if (mounted) {
            setState(() {
              _locationController.text = data['address'];
            });
          }
        }
      }, false);
    }
    // PageController 리스너는 CarouselSlider의 onPageChanged로 대체되므로 제거합니다.
  }

  @override
  void dispose() {
    // ✨ 사용자의 기존 dispose 함수는 그대로 유지됩니다.
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  /// ✨ [최종 수정] 안정적인 카카오 주소 검색 기능을 플랫폼에 맞게 구현
  Future<void> _searchAddress() async {
   if (kIsWeb) {
      // --- 웹(Web) 환경: 프로젝트에 추가한 postcode.html 파일을 팝업으로 엽니다. ---
      html.window.open('assets/postcode.html', 'address-search-popup', 'width=600,height=700');
      } else {
      // --- 모바일(Android/iOS) 환경: webview_flutter를 사용한 방식 ---
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddressSearchWebView(
            onAddressSelected: (String address) {
              setState(() {
                _locationController.text = address;
              });
            },
          ),
        ),
      );
    }
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


/// ✨ [추가] 모바일에서 카카오 주소 검색을 표시하기 위한 별도의 위젯
class AddressSearchWebView extends StatefulWidget {
  final Function(String address) onAddressSelected;
  const AddressSearchWebView({super.key, required this.onAddressSelected});

  @override
  State<AddressSearchWebView> createState() => _AddressSearchWebViewState();
}

class _AddressSearchWebViewState extends State<AddressSearchWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // 웹페이지의 `postMessage`를 Flutter에서 받기 위한 채널 설정
      ..addJavaScriptChannel('messageHandler', onMessageReceived: (JavaScriptMessage message) {
        widget.onAddressSelected(message.message);
        Navigator.pop(context);
      })
      ..loadHtmlString(_getHtmlForAddressSearch());
  }

  String _getHtmlForAddressSearch() {
    return '''
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>주소 검색</title>
        <script src="//t1.daumcdn.net/mapjsapi/bundle/postcode/prod/postcode.v2.js"></script>
      </head>
      <body style="height: 100vh; margin: 0; display: flex; align-items: center; justify-content: center;">
        <script type="text/javascript">
          new daum.Postcode({
            oncomplete: function(data) {
              // 'messageHandler' 채널을 통해 Flutter의 onMessageReceived로 데이터를 전달
              window.messageHandler.postMessage(data.address);
            },
            width: '100%',
            height: '100%'
          }).embed(document.body);
        </script>
      </body>
    </html>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('주소 검색')),
      body: WebViewWidget(controller: _controller),
    );
  }
}