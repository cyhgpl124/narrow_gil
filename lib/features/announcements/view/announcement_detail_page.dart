import 'package:carousel_slider/carousel_slider.dart';
import 'package:dots_indicator/dots_indicator.dart';
import 'package:flutter/material.dart';
import 'package:narrow_gil/features/announcements/models/announcement_model.dart';

class AnnouncementDetailPage extends StatefulWidget {
  final Announcement announcement;
  final String churchName;

  const AnnouncementDetailPage({
    super.key,
    required this.announcement,
    required this.churchName,
  });

  @override
  State<AnnouncementDetailPage> createState() => _AnnouncementDetailPageState();
}

class _AnnouncementDetailPageState extends State<AnnouncementDetailPage> {
  // ✨ [1/4 추가] CarouselSlider를 제어하기 위한 컨트롤러
  final CarouselSliderController _carouselController = CarouselSliderController();
  int _currentPage = 0;

  // ✨ [2/4 추가] 이미지를 전체 화면으로 확대해서 보여주는 함수
  void _zoomImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ZoomableImageScreen(imageUrl: imageUrl),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrls = widget.announcement.imageUrls;
    final hasMultipleImages = imageUrls.length > 1;
    // ✨ 고정된 이미지 높이 설정
    final fixedImageHeight = MediaQuery.of(context).size.width * 0.8;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.announcement.title),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✨ [3/4 수정] PageView를 CarouselSlider로 교체
              if (imageUrls.isNotEmpty)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    CarouselSlider.builder(
                      carouselController: _carouselController,
                      itemCount: imageUrls.length,
                      itemBuilder: (context, index, realIndex) {
                        return GestureDetector(
                          onTap: () => _zoomImage(imageUrls[index]),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 5.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12.0),
                              child: Image.network(
                                imageUrls[index],
                                fit: BoxFit.contain, // 이미지 비율 유지
                                loadingBuilder: (context, child, progress) =>
                                    progress == null ? child : const Center(child: CircularProgressIndicator()),
                                errorBuilder: (context, error, stack) =>
                                    const Center(child: Icon(Icons.error)),
                              ),
                            ),
                          ),
                        );
                      },
                      options: CarouselOptions(
                        height: fixedImageHeight,
                        initialPage: 0,
                        enableInfiniteScroll: false, // 무한 스크롤 비활성화
                        enlargeCenterPage: true, // 중앙 이미지 확대 효과 (3D 효과)
                        enlargeFactor: 0.2,
                        onPageChanged: (index, reason) {
                          setState(() {
                            _currentPage = index;
                          });
                        },
                      ),
                    ),

                    // ✨ 좌우 이동 버튼 추가
                    if (hasMultipleImages)
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_ios, color: Colors.black54),
                            onPressed: () => _carouselController.previousPage(),
                          ),
                        ),
                      ),
                    if (hasMultipleImages)
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_forward_ios, color: Colors.black54),
                            onPressed: () => _carouselController.nextPage(),
                          ),
                        ),
                      ),

                    // ✨ 확대 버튼 추가
                    Positioned(
                      bottom: 10,
                      right: 30,
                      child: IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity(0.3)
                        ),
                        icon: const Icon(Icons.zoom_out_map, color: Colors.white),
                        onPressed: () => _zoomImage(imageUrls[_currentPage]),
                        tooltip: '확대보기',
                      ),
                    ),
                  ],
                ),

              // ✨ DotsIndicator (기존과 유사)
              if (hasMultipleImages)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: DotsIndicator(
                      dotsCount: imageUrls.length,
                      position: _currentPage.toDouble(),
                      onTap: (index) {
                        _carouselController.animateToPage(index);
                      },
                    ),
                  ),
                ),

              // ✨ 나머지 상세 정보 및 질문 파트는 기존과 동일
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    Text(widget.announcement.title, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text('연락처: ${widget.announcement.contact}', style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ✨ [4/4 추가] 이미지를 확대해서 보여주는 별도의 스크린
class _ZoomableImageScreen extends StatelessWidget {
  final String imageUrl;

  const _ZoomableImageScreen({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(imageUrl),
        ),
      ),
    );
  }
}