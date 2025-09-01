// lib/features/my_page/view/phrase_history_page.dart

import 'package:flutter/material.dart';
import 'package:narrow_gil/features/user/user_service.dart';

class PhraseHistoryPage extends StatefulWidget {
  final String userId;
  const PhraseHistoryPage({super.key, required this.userId});

  @override
  State<PhraseHistoryPage> createState() => _PhraseHistoryPageState();
}

class _PhraseHistoryPageState extends State<PhraseHistoryPage> {
  final UserService _userService = UserService();
  late Future<List<String>> _phrasesFuture;

  @override
  void initState() {
    super.initState();
    _phrasesFuture = _userService.getUserPhrases(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('작성한 문구 히스토리'),
      ),
      body: FutureBuilder<List<String>>(
        future: _phrasesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('오류: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('작성한 문구가 없습니다.'));
          }

          final phrases = snapshot.data!.reversed.toList();

          return ListView.separated(
            padding: const EdgeInsets.all(16.0),
            itemCount: phrases.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              return ListTile(
                leading: CircleAvatar(
                  child: Text('${phrases.length - index}'),
                ),
                title: Text(phrases[index]),
              );
            },
          );
        },
      ),
    );
  }
}