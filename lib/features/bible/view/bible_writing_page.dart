// lib/features/bible/view/bible_writing_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:narrow_gil/features/bible/models/bible_chapter_model.dart';
import 'package:narrow_gil/features/bible/models/verse_model.dart';
import 'package:narrow_gil/features/bible/services/bible_service.dart';
import 'package:narrow_gil/home/bloc/home_bloc.dart';

// 실시간 하이라이팅을 위한 컨트롤러 (기능 유지)
class _HighlightingTextController extends TextEditingController {
  String originalText;

  _HighlightingTextController({required this.originalText});

  void updateOriginalText(String newOriginalText) {
    originalText = newOriginalText;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final writtenText = text;
    final originalNormalized = originalText.replaceAll(RegExp(r'\s+'), '');
    final writtenNormalized = writtenText.replaceAll(RegExp(r'\s+'), '');

    int commonPrefixLength = 0;
    while (commonPrefixLength < writtenNormalized.length &&
           commonPrefixLength < originalNormalized.length &&
           writtenNormalized[commonPrefixLength] == originalNormalized[commonPrefixLength]) {
      commonPrefixLength++;
    }

    int correctEndIndex = 0;
    if (commonPrefixLength > 0) {
      int normalizedCount = 0;
      for (int i = 0; i < writtenText.length; i++) {
        if (!RegExp(r'\s').hasMatch(writtenText[i])) {
          normalizedCount++;
        }
        if (normalizedCount >= commonPrefixLength) {
          correctEndIndex = i + 1;
          break;
        }
      }
    }

    int incorrectEndIndex = correctEndIndex;
    if (commonPrefixLength < writtenNormalized.length) {
      for (int i = correctEndIndex; i < writtenText.length; i++) {
        if (!RegExp(r'\s').hasMatch(writtenText[i])) {
          incorrectEndIndex = i + 1;
          break;
        } else {
          incorrectEndIndex = i + 1;
        }
      }
    }

    final List<TextSpan> children = [];
    if (correctEndIndex > 0) {
      children.add(TextSpan(
        text: writtenText.substring(0, correctEndIndex),
        style: style?.copyWith(color: Colors.blueAccent),
      ));
    }
    if (incorrectEndIndex > correctEndIndex) {
      children.add(TextSpan(
        text: writtenText.substring(correctEndIndex, incorrectEndIndex),
        style: style?.copyWith(backgroundColor: Colors.red.withOpacity(0.5)),
      ));
    }
    if (incorrectEndIndex < writtenText.length) {
      children.add(TextSpan(
        text: writtenText.substring(incorrectEndIndex),
        style: style,
      ));
    }

    if (children.isEmpty) {
      return const TextSpan(text: '');
    }
    return TextSpan(style: style, children: children);
  }
}


class BibleWritingPage extends StatefulWidget {
  final BibleChapter chapter;
  const BibleWritingPage({super.key, required this.chapter});

  @override
  State<BibleWritingPage> createState() => _BibleWritingPageState();
}

class _BibleWritingPageState extends State<BibleWritingPage> {
  final BibleService _bibleService = BibleService();
  _HighlightingTextController? _verseInputController;
  final FocusNode _focusNode = FocusNode();

  List<Verse> _verses = [];
  int _currentVerseIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProgressAndVerses();
  }

  Future<void> _loadProgressAndVerses() async {
    final homeState = context.read<HomeBloc>().state;
    if (homeState is HomeLoadSuccess) {
      try {
        final versesData = await _bibleService.getChapterVerses(
          widget.chapter.book,
          widget.chapter.chapter,
        );

        // --- ▼ [수정] double 진행률을 int 인덱스로 변환하는 로직 ▼ ---
        if (mounted && versesData.isNotEmpty) {
          final savedProgress = await _bibleService.getInProgressVerse(
            homeState.userProfile.uid,
            widget.chapter.book,
            widget.chapter.chapter,
          );

          // 저장된 진행률을 기반으로 시작할 절 인덱스 계산
          final savedIndex = (savedProgress * versesData.length).floor();

          setState(() {
            _verses = versesData;
            // 인덱스가 유효한 범위 내에 있는지 확인
            if (savedIndex < _verses.length) {
              _currentVerseIndex = savedIndex;
            }
            _isLoading = false;
          });
        } else if (mounted) {
           setState(() {
             _verses = versesData;
             _isLoading = false;
           });
        }
        // --- ▲ [수정] double 진행률을 int 인덱스로 변환하는 로직 ▲ ---

      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('데이터 로딩 실패: $e')));
        }
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _verseInputController?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  double get _currentProgress {
    if (_verses.isEmpty) return 0.0;
    return (_currentVerseIndex / _verses.length).clamp(0.0, 1.0);
  }

  void _submitVerse() {
    if (_isLoading || _verses.isEmpty || _verseInputController == null) return;

    final originalVerse = _verses[_currentVerseIndex].text;
    final writtenVerse = _verseInputController!.text;
    final originalNormalized = originalVerse.replaceAll(RegExp(r'\s+'), '');
    final writtenNormalized = writtenVerse.replaceAll(RegExp(r'\s+'), '');

    if (originalNormalized == writtenNormalized) {
      final homeState = context.read<HomeBloc>().state;
      if (homeState is HomeLoadSuccess) {
        setState(() {
          if (_currentVerseIndex < _verses.length - 1) {
            _currentVerseIndex++;
            // --- ▼ [수정] 현재 진행률(double)을 계산하여 저장 ▼ ---
            _bibleService.saveInProgressVerse(
              homeState.userProfile.uid,
              widget.chapter.book,
              widget.chapter.chapter,
              _currentProgress, // 현재 진행률을 직접 전달
            );
            // --- ▲ [수정] 현재 진행률(double)을 계산하여 저장 ▲ ---
            _verseInputController!.updateOriginalText(_verses[_currentVerseIndex].text);
            _verseInputController!.clear();
            _focusNode.requestFocus();
          } else {
            _completeChapterAndExit();
          }
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('내용이 일치하지 않습니다. 빨간 부분을 확인해주세요.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _saveProgressAndPop() async {
    final homeState = context.read<HomeBloc>().state;
    if (homeState is HomeLoadSuccess && _verses.isNotEmpty && _currentVerseIndex < _verses.length) {
      // --- ▼ [수정] 현재 진행률(double)을 계산하여 저장 ▼ ---
      await _bibleService.saveInProgressVerse(
        homeState.userProfile.uid,
        widget.chapter.book,
        widget.chapter.chapter,
        _currentProgress, // 현재 진행률을 직접 전달
      );
      // --- ▲ [수정] 현재 진행률(double)을 계산하여 저장 ▲ ---
    }
    if(mounted) Navigator.of(context).pop(_currentProgress);
  }

  Future<void> _completeChapterAndExit() async {
    setState(() => _isLoading = true);
    try {
      final homeState = context.read<HomeBloc>().state;
      if (homeState is HomeLoadSuccess) {
        await _bibleService.completeChapter(
          homeState.userProfile.uid,
          homeState.userProfile.church,
          widget.chapter.book,
          widget.chapter.chapter,
        );
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('필사를 완료했습니다!')));
        if (mounted) Navigator.of(context).pop(1.0);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류 발생: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _saveProgressAndPop();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _saveProgressAndPop,
          ),
          title: Text('${widget.chapter.book} ${widget.chapter.chapter}장 필사'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4.0),
            child: LinearProgressIndicator(
              value: _currentProgress,
              backgroundColor: Colors.grey.shade300,
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildVerseView(),
      ),
    );
  }

  Widget _buildVerseView() {
    if (_verses.isEmpty) {
      return const Center(child: Text('해당 장의 본문을 찾을 수 없습니다.'));
    }

    if (_verseInputController == null) {
      _verseInputController = _HighlightingTextController(originalText: _verses[_currentVerseIndex].text)
        ..addListener(() => setState(() {}));
    }

    final currentVerse = _verses[_currentVerseIndex];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(12.0),
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.grey.shade800, borderRadius: BorderRadius.circular(8)),
              child: SingleChildScrollView(
                child: Text(
                  _verses.map((v) => '${v.number} ${v.text}').join('\n'),
                  style: const TextStyle(fontSize: 16, height: 1.8, color: Colors.white70),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '${currentVerse.number}. ${currentVerse.text}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.6),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _verseInputController,
            focusNode: _focusNode,
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, height: 1.5),
            maxLines: null,
            decoration: InputDecoration(
              hintText: '이곳에 위 절을 따라 적어주세요',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send),
                onPressed: _submitVerse,
              ),
            ),
            onSubmitted: (_) => _submitVerse(),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}