// lib/features/bible/view/bible_book_list_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:narrow_gil/features/bible/services/bible_service.dart';
import 'package:narrow_gil/features/bible/view/bible_chapter_grid_page.dart';
import 'package:narrow_gil/home/bloc/home_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BibleBookListPage extends StatefulWidget {
  const BibleBookListPage({super.key});

  @override
  State<BibleBookListPage> createState() => _BibleBookListPageState();
}

class _BibleBookListPageState extends State<BibleBookListPage> {
  final BibleService _bibleService = BibleService();
  final List<String> _bibleBooks = BibleService.bibleBookChapters.keys.toList();

  Future<void>? _initialLoadFuture;
  final Map<String, double> _bookProgressMap = {};
  Set<String> _completedChapters = {};
  int _bibleReadCount = 0;

  @override
  void initState() {
    super.initState();
    _initialLoadFuture = _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final homeState = context.read<HomeBloc>().state;
    if (homeState is HomeLoadSuccess) {
      final progressDocRef = FirebaseFirestore.instance.collection('users').doc(homeState.userProfile.uid).collection('bible_progress').doc('chapters');
      final results = await Future.wait([
        _bibleService.getCompletedChapters(homeState.userProfile.uid),
        _bibleService.getInProgressMap(homeState.userProfile.uid),
        progressDocRef.get(),
      ]);

      _completedChapters = results[0] as Set<String>;
      final inProgressMap = results[1] as Map<String, double>;
      final progressDoc = results[2] as DocumentSnapshot;

      _bibleReadCount = (progressDoc.data() as Map<String, dynamic>?)?['bibleReadCount'] ?? 0;

      for (final book in _bibleBooks) {
        final bookId = BibleService.bibleBookNumbers[book]!;
        final totalChapters = BibleService.bibleBookChapters[book]!;
        if (totalChapters == 0) continue;

        final completedCount = _completedChapters.where((key) => key.startsWith('$bookId-')).length;
        double partialProgressSum = 0;
        inProgressMap.forEach((key, progress) {
          if (key.startsWith('$bookId-')) { partialProgressSum += progress; }
        });
        _bookProgressMap[book] = (completedCount + partialProgressSum) / totalChapters;
      }
      if (mounted) setState(() {});
    }
  }

  void _navigateToChapterGrid(String book) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(value: context.read<HomeBloc>(), child: BibleChapterGridPage(book: book)),
      ),
    );
    setState(() { _initialLoadFuture = _loadInitialData(); });
  }

  // ✨ [수정] 초기화 버튼을 눌렀을 때 실행될 함수
  Future<void> _handleResetProgress() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('진행률 초기화'),
        content: const Text('현재 필사 진행 기록을 초기화하시겠습니까?\n(전체 회독 수와 누적 기록은 그대로 유지됩니다.)'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('초기화'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final homeState = context.read<HomeBloc>().state;
      if (homeState is HomeLoadSuccess) {
        try {
          await _bibleService.resetBibleProgress(homeState.userProfile.uid);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('진행 기록이 초기화되었습니다.')),
          );
          setState(() {
            _initialLoadFuture = _loadInitialData();
          });
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('초기화 실패: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_bibleReadCount > 0 ? '성경 목록 (${_bibleReadCount}독)' : '성경 목록'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '진행률 초기화',
            onPressed: _handleResetProgress,
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _initialLoadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('오류 발생: ${snapshot.error}'));
          }

          return ListView.builder(
            itemCount: _bibleBooks.length,
            itemBuilder: (context, index) {
              final book = _bibleBooks[index];
              final double totalProgress = _bookProgressMap[book] ?? 0.0;
              final progressColor = Color.lerp(Colors.lightBlue.shade100, Colors.blue.shade700, totalProgress)!;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  title: Text(book, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('진행률: ${(totalProgress * 100).toStringAsFixed(1)}%'),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: totalProgress,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  ),
                  onTap: () => _navigateToChapterGrid(book),
                ),
              );
            },
          );
        },
      ),
    );
  }
}