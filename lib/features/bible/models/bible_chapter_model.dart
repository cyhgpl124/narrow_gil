// lib/features/bible/models/bible_chapter_model.dart

class BibleChapter {
  final String book; // 예: "창세기"
  final int chapter; // 예: 1
  bool isCompleted; // 필사 완료 여부

  BibleChapter({
    required this.book,
    required this.chapter,
    this.isCompleted = false,
  });
}