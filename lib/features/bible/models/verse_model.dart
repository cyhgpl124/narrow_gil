// lib/features/bible/models/verse_model.dart

class Verse {
  final String number; // 절 번호 (예: "1", "2")
  final String text;   // 절 본문

  Verse({required this.number, required this.text});
}