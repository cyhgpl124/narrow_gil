// lib/features/bible/view/bible_chapter_grid_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:narrow_gil/features/bible/models/bible_chapter_model.dart';
import 'package:narrow_gil/features/bible/services/bible_service.dart';
import 'package:narrow_gil/features/bible/view/bible_writing_page.dart';
import 'package:narrow_gil/home/bloc/home_bloc.dart';

class BibleChapterGridPage extends StatefulWidget {
  final String book;
  const BibleChapterGridPage({super.key, required this.book});

  @override
  State<BibleChapterGridPage> createState() => _BibleChapterGridPageState();
}

class _BibleChapterGridPageState extends State<BibleChapterGridPage> {
  final BibleService _bibleService = BibleService();

  // --- ▼ [수정] 여러 Future를 동시에 관리하기 위해 Future<void>로 변경 ▼ ---
  Future<void>? _loadFuture;
  Set<String> _completedChapters = {};
  final Map<int, double> _partialProgressMap = {};
  // --- ▲ [수정] 여러 Future를 동시에 관리하기 위해 Future<void>로 변경 ▲ ---

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadInitialChapterData();
  }

  // --- ▼ [수정] 완료된 장과 진행중인 장 목록을 모두 불러와서 상태 초기화 ▼ ---
  Future<void> _loadInitialChapterData() async {
    final homeState = context.read<HomeBloc>().state;
    if (homeState is HomeLoadSuccess) {
      final results = await Future.wait([
        _bibleService.getCompletedChapters(homeState.userProfile.uid),
        _bibleService.getInProgressMap(homeState.userProfile.uid),
      ]);

      _completedChapters = results[0] as Set<String>;
      final inProgressMap = results[1] as Map<String, double>;

      final bookId = BibleService.bibleBookNumbers[widget.book]!;

      // 현재 책에 해당하는 부분 진행도를 _partialProgressMap에 채워넣기
      inProgressMap.forEach((key, progress) {
        if (key.startsWith('$bookId-')) {
          final chapter = int.tryParse(key.split('-')[1]);
          if (chapter != null) {
            _partialProgressMap[chapter] = progress;
          }
        }
      });
      if (mounted) setState(() {});
    }
  }

  // --- ▼ [수정] 완료된 장 목록만 새로고침하는 함수 (완료 시 호출) ▼ ---
  Future<void> _refreshCompletedChapters() async {
    final homeState = context.read<HomeBloc>().state;
    if (homeState is HomeLoadSuccess) {
      _completedChapters = await _bibleService.getCompletedChapters(homeState.userProfile.uid);
      if (mounted) setState(() {});
    }
  }
  // --- ▲ [수정] 완료된 장 목록만 새로고침하는 함수 (완료 시 호출) ▲ ---

  void _navigateToWritingPage(BibleChapter chapter) async {
    final homeState = context.read<HomeBloc>().state;
    if (homeState is HomeLoadSuccess) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: BlocProvider.of<HomeBloc>(context),
            child: BibleWritingPage(chapter: chapter),
          ),
        ),
      );

      if (result is double) {
        setState(() {
          if (result == 1.0) {
            _partialProgressMap.remove(chapter.chapter);
            _refreshCompletedChapters(); // 완료 목록만 다시 로드
          } else if (result > 0) {
            _partialProgressMap[chapter.chapter] = result;
          }
        });
      }
    }
  }

  void _popWithProgress() {
    // ... 이전 답변과 동일 (수정 필요 없음) ...
    final bookId = BibleService.bibleBookNumbers[widget.book];
    if (bookId == null) {
      Navigator.of(context).pop(0.0);
      return;
    }
    final totalChapters = BibleService.bibleBookChapters[widget.book]!;
    if (totalChapters == 0) {
      Navigator.of(context).pop(0.0);
      return;
    }
    final completedCount = _completedChapters.where((key) => key.startsWith('$bookId-')).length;
    double partialProgressSum = 0;
    _partialProgressMap.forEach((chapter, progress) {
      final key = '$bookId-$chapter';
      if (!_completedChapters.contains(key)) {
        partialProgressSum += progress;
      }
    });
    final totalProgress = (completedCount + partialProgressSum) / totalChapters;
    Navigator.of(context).pop(totalProgress.clamp(0.0, 1.0));
  }


  @override
  Widget build(BuildContext context) {
    final chapterCount = BibleService.bibleBookChapters[widget.book] ?? 0;
    final bookId = BibleService.bibleBookNumbers[widget.book];

    return WillPopScope(
      onWillPop: () async {
        _popWithProgress();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.book),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _popWithProgress(),
          ),
        ),
        body: FutureBuilder<void>(
          future: _loadFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || bookId == null) {
              return Center(child: Text('오류 발생: ${snapshot.error}'));
            }

            return GridView.builder(
              padding: const EdgeInsets.all(8.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 8.0,
                mainAxisSpacing: 8.0,
              ),
              itemCount: chapterCount,
              itemBuilder: (context, index) {
                final chapterNumber = index + 1;
                final chapter = BibleChapter(book: widget.book, chapter: chapterNumber);
                final key = '$bookId-$chapterNumber';
                final isCompleted = _completedChapters.contains(key);
                final double progress = isCompleted ? 1.0 : (_partialProgressMap[chapterNumber] ?? 0.0);
                final progressColor = Color.lerp(Colors.lightBlue.shade100, Colors.blue.shade700, progress)!;

                return GestureDetector(
                  onTap: () => _navigateToWritingPage(chapter),
                  child: Tooltip(
                    message: '${chapter.book} ${chapter.chapter}장',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(color: Colors.grey.shade300),
                          if (progress > 0)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: constraints.maxWidth * progress,
                                    color: progressColor,
                                  );
                                },
                              ),
                            ),
                          Text(
                            '${chapter.chapter}',
                            style: TextStyle(
                              color: progress > 0.6 ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}