// lib/features/bible/view/bible_grid_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:narrow_gil/features/bible/models/bible_chapter_model.dart';
import 'package:narrow_gil/features/bible/services/bible_service.dart';
import 'package:narrow_gil/features/bible/view/bible_writing_page.dart';
import 'package:narrow_gil/home/bloc/home_bloc.dart';

class BibleGridPage extends StatefulWidget {
  const BibleGridPage({super.key});

  @override
  State<BibleGridPage> createState() => _BibleGridPageState();
}

class _BibleGridPageState extends State<BibleGridPage> {
  final BibleService _bibleService = BibleService();
  late Future<Set<String>> _completedChaptersFuture;
  final List<BibleChapter> _allChapters = [];

  @override
  void initState() {
    super.initState();
    final homeState = context.read<HomeBloc>().state;
    if (homeState is HomeLoadSuccess) {
      _completedChaptersFuture = _bibleService.getCompletedChapters(homeState.userProfile.uid);
    }

    // 성경 전체 장 목록 생성
    BibleService.bibleBookChapters.forEach((book, chapterCount) {
      for (int i = 1; i <= chapterCount; i++) {
        _allChapters.add(BibleChapter(book: book, chapter: i));
      }
    });
  }

  void _navigateToWritingPage(BibleChapter chapter) {
     final homeState = context.read<HomeBloc>().state;
     if(homeState is HomeLoadSuccess) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: BlocProvider.of<HomeBloc>(context),
              child: BibleWritingPage(chapter: chapter),
            ),
          ),
        ).then((_) {
          // 필사 페이지에서 돌아왔을 때, 그리드를 갱신하여 완료된 장의 색상을 변경
          setState(() {
            _completedChaptersFuture = _bibleService.getCompletedChapters(homeState.userProfile.uid);
          });
        });
     }
  }

  void _startRandomChapter(Set<String> completed) {
    final uncompletedChapters = _allChapters.where((ch) {
      final key = '${ch.book}-${ch.chapter}';
      return !completed.contains(key);
    }).toList();

    if (uncompletedChapters.isNotEmpty) {
      uncompletedChapters.shuffle();
      _navigateToWritingPage(uncompletedChapters.first);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 성경 필사를 완료하셨습니다! 축하합니다!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('성경 필사'),
        actions: [
          FutureBuilder<Set<String>>(
            future: _completedChaptersFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.shuffle),
                onPressed: () => _startRandomChapter(snapshot.data!),
                tooltip: '랜덤으로 시작하기',
              );
            }
          ),
        ],
      ),
      body: FutureBuilder<Set<String>>(
        future: _completedChaptersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('오류 발생: ${snapshot.error}'));
          }

          final completedSet = snapshot.data ?? {};
          final totalChapters = _allChapters.length;
          final completedCount = completedSet.length;
          final progress = totalChapters > 0 ? completedCount / totalChapters : 0.0;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text('진행률: $completedCount / $totalChapters (${(progress * 100).toStringAsFixed(2)}%)',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(4.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 20, // 가로에 20개의 네모
                    crossAxisSpacing: 2.0,
                    mainAxisSpacing: 2.0,
                  ),
                  itemCount: totalChapters,
                  itemBuilder: (context, index) {
                    final chapter = _allChapters[index];
                    final key = '${chapter.book}-${chapter.chapter}';
                    final isCompleted = completedSet.contains(key);

                    return GestureDetector(
                      onTap: () => _navigateToWritingPage(chapter),
                      child: Tooltip(
                        message: '${chapter.book} ${chapter.chapter}장',
                        child: Container(
                          color: isCompleted ? Colors.blueAccent : Colors.grey.shade800,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}