// lib/features/announcements/view/announcements_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:narrow_gil/features/announcements/models/announcement_model.dart';
import 'package:narrow_gil/features/announcements/services/announcement_service.dart';
import 'package:narrow_gil/features/announcements/view/announcement_detail_page.dart';
import 'package:narrow_gil/features/announcements/view/widgets/upload_announcement_dialog.dart';
import 'package:narrow_gil/home/bloc/home_bloc.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // ✨ [추가] 웹/모바일 구분을 위해 import


// ✨ [수정] StatelessWidget -> StatefulWidget으로 변경
class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  final AnnouncementService _announcementService = AnnouncementService();

  // ✨ [추가] 페이지네이션 상태 관리를 위한 변수들
  bool _isLoading = true;
  List<Announcement> _announcements = [];
  // 각 페이지의 시작점을 저장하여 '이전' 페이지로 돌아갈 때 사용합니다.
  List<DocumentSnapshot?> _pageStartDocuments = [null];
  int _currentPageIndex = 0;
  bool _hasNextPage = true;


  @override
  void initState() {
    super.initState();
    // 위젯이 생성될 때 첫 페이지 데이터를 불러옵니다.
    _loadAnnouncements();
  }

  /// 공지사항 데이터를 불러오는 핵심 함수
  Future<void> _loadAnnouncements({bool loadNext = false}) async {
    setState(() { _isLoading = true; });

    try {
      final userProfile = (context.read<HomeBloc>().state as HomeLoadSuccess).userProfile;

      DocumentSnapshot? startAfterDoc;
      if (loadNext) {
        // '다음' 페이지 로드: 현재 페이지의 마지막 문서를 시작점으로 사용
        startAfterDoc = _pageStartDocuments.last;
      } else if (_currentPageIndex > 0) {
        // '이전' 페이지 로드: 이전 페이지의 시작점을 사용
        startAfterDoc = _pageStartDocuments[_currentPageIndex - 1];
      } else {
        // 첫 페이지 로드
        startAfterDoc = null;
      }

      final result = await _announcementService.getAnnouncementsPaginated(
        churchName: userProfile.church,
        limit: 10,
        startAfter: startAfterDoc,
      );

      if (mounted) {
        setState(() {
          _announcements = result['announcements'];
          _hasNextPage = result['hasMore'];

          if(loadNext) {
            // 다음 페이지로 이동 시, 새 페이지의 시작점을 리스트에 추가
            _pageStartDocuments.add(result['lastDocument']);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('공지사항 로드 실패: $e')));
      }
    }
  }

  void _navigateToNextPage() {
    if (!_hasNextPage) return;
    setState(() { _currentPageIndex++; });
    _loadAnnouncements(loadNext: true);
  }

  void _navigateToPreviousPage() {
    if (_currentPageIndex == 0) return;
    setState(() { _currentPageIndex--; });
    // '이전' 페이지로 갈 때는, pageStartDocuments 리스트의 마지막 요소를 제거하여 현재 페이지의 시작점을 맞춥니다.
    _pageStartDocuments.removeLast();
    _loadAnnouncements();
  }


  @override
  Widget build(BuildContext context) {
    final userProfile = (context.read<HomeBloc>().state as HomeLoadSuccess).userProfile;

    // --- ▼ [핵심 수정] ---
    // 모바일 환경인지 확인합니다. (kIsWeb이 false이면 모바일)
    final bool isMobile = !kIsWeb && (Theme.of(context).platform == TargetPlatform.android || Theme.of(context).platform == TargetPlatform.iOS);
    // --- ▲ [핵심 수정] ---
    return Scaffold(
      appBar: AppBar(
        title: const Text('공지사항'),
      ),
      // ✨ [수정] StreamBuilder를 Column으로 변경
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _announcements.isEmpty
                      ? const Center(child: Text('등록된 공지사항이 없습니다.'))
                      : GridView.builder(
                          padding: const EdgeInsets.all(16.0),
                          // --- ▼ [핵심 수정] ---
                          // isMobile 값에 따라 그리드 설정을 다르게 적용합니다.
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isMobile ? 2 : 4, // 모바일이면 2열, 아니면 4열
                            crossAxisSpacing: 16.0,
                            mainAxisSpacing: 16.0,
                            childAspectRatio: isMobile ? 0.75 : 0.7, // 모바일에서 세로 비율을 약간 조정
                          ),
                          // --- ▲ [핵심 수정] ---
                          itemCount: _announcements.length,
                          itemBuilder: (context, index) {
                            final announcement = _announcements[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => AnnouncementDetailPage(
                                    announcement: announcement,
                                    churchName: userProfile.church,
                                  ),
                                ));
                              },
                              child: Card(
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: Container(
                                        color: Colors.grey.shade200,
                                        child: announcement.previewImageUrl.isEmpty
                                            ? const Center(child: Icon(Icons.image_not_supported, size: 50, color: Colors.black54))
                                            : Image.network(
                                                announcement.previewImageUrl,
                                                fit: BoxFit.cover,
                                                loadingBuilder: (context, child, progress) =>
                                                    progress == null ? child : const Center(child: CircularProgressIndicator()),
                                                errorBuilder: (context, error, stack) => const Center(child: Icon(Icons.error)),
                                              ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(announcement.title, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${DateFormat('yy.MM.dd').format(announcement.startDate)} - ${DateFormat('yy.MM.dd').format(announcement.endDate)}',
                                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                // ✨ [추가] 페이지네이션 컨트롤러 UI
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios),
                        onPressed: _currentPageIndex > 0 ? _navigateToPreviousPage : null,
                        tooltip: '이전 페이지',
                      ),
                      Text('페이지 ${_currentPageIndex + 1}'),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios),
                        onPressed: _hasNextPage ? _navigateToNextPage : null,
                        tooltip: '다음 페이지',
                      ),
                    ],
                  ),
                )
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // 새 공지 등록 후에는 첫 페이지를 다시 불러옵니다.
          final result = await showDialog<bool>(
            context: context,
            builder: (_) => UploadAnnouncementDialog(
              churchName: userProfile.church,
              authorId: userProfile.uid,
              authorName: userProfile.name,
            ),
          );
          if (result == true && mounted) {
            setState(() {
              _currentPageIndex = 0;
              _pageStartDocuments = [null];
            });
            _loadAnnouncements();
          }
        },
        child: const Icon(Icons.add),
        tooltip: '공지사항 등록',
      ),
    );
  }
}