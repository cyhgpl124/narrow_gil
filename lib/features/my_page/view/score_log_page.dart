// lib/features/my_page/view/score_log_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:narrow_gil/features/my_page/models/score_log_model.dart';
import 'package:narrow_gil/features/user/user_service.dart';
import 'package:narrow_gil/home/bloc/home_bloc.dart';

// ✨ [수정] StatelessWidget -> StatefulWidget으로 변경
class ScoreLogPage extends StatefulWidget {
  const ScoreLogPage({super.key});

  @override
  State<ScoreLogPage> createState() => _ScoreLogPageState();
}

class _ScoreLogPageState extends State<ScoreLogPage> {
  final UserService _userService = UserService();

  // ✨ [추가] 페이지네이션 상태 관리를 위한 변수들
  bool _isLoading = true;         // 초기 로딩 상태
  bool _isLoadingMore = false;    // 추가 로딩 상태
  List<ScoreLog> _scoreLogs = []; // 화면에 표시될 로그 목록
  DocumentSnapshot? _lastDocument; // 다음 페이지를 불러올 기준점
  bool _hasMore = true;           // 더 불러올 데이터가 있는지 여부

  @override
  void initState() {
    super.initState();
    // 위젯이 생성될 때 첫 페이지 데이터를 불러옵니다.
    _loadInitialLogs();
  }

  /// 첫 페이지(100개) 로그를 불러오는 함수
  Future<void> _loadInitialLogs() async {
    setState(() {
      _isLoading = true;
      _hasMore = true;
      _scoreLogs = [];
      _lastDocument = null;
    });

    final homeState = context.read<HomeBloc>().state;
    if (homeState is HomeLoadSuccess) {
      try {
        final result = await _userService.getScoreLogsPaginated(
          userId: homeState.userProfile.uid,
          limit: 100,
        );
        if (mounted) {
          setState(() {
            _scoreLogs = result['logs'];
            _lastDocument = result['lastDocument'];
            _hasMore = result['hasMore'];
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// '더 보기' 버튼을 눌렀을 때 다음 페이지(100개)를 불러오는 함수
  Future<void> _loadMoreLogs() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    final homeState = context.read<HomeBloc>().state;
    if (homeState is HomeLoadSuccess) {
      try {
        final result = await _userService.getScoreLogsPaginated(
          userId: homeState.userProfile.uid,
          limit: 100,
          startAfter: _lastDocument,
        );
        if (mounted) {
          setState(() {
            _scoreLogs.addAll(result['logs']); // 기존 목록에 새로 불러온 데이터를 추가
            _lastDocument = result['lastDocument'];
            _hasMore = result['hasMore'];
            _isLoadingMore = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isLoadingMore = false);
      }
    } else {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('하늘점수 획득 내역'),
      ),
      // ✨ [수정] FutureBuilder를 로딩 상태에 따라 UI를 직접 구성하는 방식으로 변경
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _scoreLogs.isEmpty
              ? const Center(child: Text('점수 획득 내역이 없습니다.'))
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: _scoreLogs.length,
                        itemBuilder: (context, index) {
                          final log = _scoreLogs[index];
                          final isPositive = log.scoreChange >= 0;
                          final scoreText = isPositive ? '+${log.scoreChange}' : '${log.scoreChange}';

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            child: ListTile(
                              leading: Icon(
                                isPositive ? Icons.star_rounded : Icons.star_border_rounded,
                                color: isPositive ? Colors.amber.shade700 : Colors.grey,
                              ),
                              title: Text(log.reason),
                              subtitle: Text(DateFormat('yyyy년 MM월 dd일 HH:mm').format(log.date.toDate())),
                              trailing: Text(
                                scoreText,
                                style: TextStyle(
                                  color: isPositive ? Colors.blueAccent : Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // ✨ [추가] 추가 로딩 중일 때 로딩 인디케이터 표시
                    if (_isLoadingMore)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    // ✨ [추가] 더 불러올 데이터가 있을 때만 '더 보기' 버튼 표시
                    if (_hasMore && !_isLoadingMore)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextButton(
                          onPressed: _loadMoreLogs,
                          child: const Text('다음 100개 보기'),
                        ),
                      )
                  ],
                ),
    );
  }
}