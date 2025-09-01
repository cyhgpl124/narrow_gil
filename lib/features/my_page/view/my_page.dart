// lib/features/my_page/view/my_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:narrow_gil/features/my_page/view/edit_profile_page.dart';
import 'package:narrow_gil/features/my_page/view/phrase_history_page.dart';
import 'package:narrow_gil/features/my_page/view/score_log_page.dart';
import 'package:narrow_gil/features/user/user_service.dart';
import 'package:narrow_gil/home/bloc/home_bloc.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  final UserService _userService = UserService();

  // --- ▼ [추가] 교회 정보 수정을 위한 컨트롤러들 ---
  final TextEditingController _zoomController = TextEditingController();
  final TextEditingController _driveController = TextEditingController();
  final TextEditingController _districtsController = TextEditingController();
  final TextEditingController _presbyteryController = TextEditingController();
  final TextEditingController _businessNumberController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _positionsController = TextEditingController();
  // --- ▲ [추가] ---

  final TextEditingController _phraseController = TextEditingController();
  bool _isPhraseSaving = false;

  // --- ▼ [추가] 랭킹 데이터를 비동기적으로 관리할 Future ▼ ---
  Future<Map<String, Map<String, int>>>? _rankFuture;
  // --- ▲ [추가] 랭킹 데이터를 비동기적으로 관리할 Future ▲ ---

  @override
  void initState() {
    super.initState();
    final homeState = context.read<HomeBloc>().state;
    if (homeState is HomeLoadSuccess) {
      // --- ▼ [추가] 페이지가 시작될 때 랭킹 데이터 로드를 시작 ▼ ---
      _rankFuture = _loadRankings(homeState);
      // --- ▲ [추가] 페이지가 시작될 때 랭킹 데이터 로드를 시작 ▲ ---
      // [추가] 컨트롤러 초기화
      final church = homeState.churchInfo;
      if (church != null) {
        _zoomController.text = church.zoomLink;
        _driveController.text = church.driveLink;
        _districtsController.text = church.districts.join(', ');
        _presbyteryController.text = church.presbytery;
        _businessNumberController.text = church.businessNumber;
        _addressController.text = church.address;
        _positionsController.text = church.positions.join(', ');
      }
    }
  }

  // --- ▼ [추가] 교회 내 순위와 전체 순위를 동시에 불러오는 함수 ▼ ---
  Future<Map<String, Map<String, int>>> _loadRankings(
      HomeLoadSuccess state) async {
    final user = state.userProfile;
    final results = await Future.wait([
      _userService.getChurchRank(user.uid, user.church),
      _userService.getTotalRank(user.uid, user.heavenlyScore),
    ]);
    return {
      'church': results[0],
      'total': results[1],
    };
  }
  // --- ▲ [추가] 교회 내 순위와 전체 순위를 동시에 불러오는 함수 ▲ ---

  @override
  void dispose() {
    _phraseController.dispose();
    _driveController.dispose();
    _zoomController.dispose();
    _districtsController.dispose();
    _presbyteryController.dispose();
    _businessNumberController.dispose();
    _addressController.dispose();
    _positionsController.dispose();
    super.dispose();
  }

  // --- ▼ [추가] 교회 정보 저장 로직 ---
  void _saveChurchInfo() {
    final Map<String, dynamic> updatedData = {
      'drive': _driveController.text.trim(),
      'zoom': _zoomController.text.trim(),
      '구역': _districtsController.text.split(',').map((e) => e.trim()).toList(),
      '노회명': _presbyteryController.text.trim(),
      '사업자번호': _businessNumberController.text.trim(),
      '주소': _addressController.text.trim(),
      '직책': _positionsController.text.split(',').map((e) => e.trim()).toList(),
    };
    context.read<HomeBloc>().add(HomeChurchInfoSubmitted(updatedData));
    FocusScope.of(context).unfocus(); // 키보드 숨기기
     ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('교회 정보가 업데이트되었습니다.')),
    );
  }
  // --- ▲ [추가] ---

  // --- ▼ [수정] _savePhrase 함수를 Bloc 이벤트를 보내도록 단순화 ---
  void _savePhrase() {
    if (_phraseController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('문구를 입력해주세요.')));
      return;
    }
    // Bloc에 새로운 이벤트를 전달하면, Bloc이 모든 로직을 처리합니다.
    context
        .read<HomeBloc>()
        .add(HomePhraseSubmitted(_phraseController.text.trim()));
    _phraseController.clear();
  }

  // --- ▲ [수정] ---
  Future<void> _showWithdrawalDialog(String userId) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('회원 탈퇴 확인'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('정말로 회원 탈퇴를 하시겠습니까?'),
                SizedBox(height: 8),
                Text(
                  '탈퇴 후 재가입 시에는 교회의 새로운 승인이 필요합니다.',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('탈퇴하기', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                try {
                  await _userService.withdrawUser(userId);
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('회원 탈퇴가 완료되었습니다.')),
                  );
                } catch (e) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('회원 탈퇴 중 오류가 발생했습니다: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- ▼ [수정] BlocListener를 추가하여 Bloc 상태와 로컬 상태를 안전하게 동기화 ---
    // BlocBuilder를 사용하여 HomeBloc의 상태가 바뀔 때마다 UI를 다시 그립니다.
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        if (state is! HomeLoadSuccess) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final user = state.userProfile;

        // --- ▼ [수정] Bloc 상태에서 직접 현재 문구를 가져옵니다. ---
        final currentPhrase =
            user.phrases.isNotEmpty ? user.phrases.last : '아직 작성된 문구가 없습니다.';
        // --- ▲ [수정] ---
        const adminRoles = ['목회자', '서기', '개발자'];
        final isAdmin = adminRoles.contains(state.userRole);

        return Scaffold(
          appBar: AppBar(title: const Text('마이페이지')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 사용자 정보 카드
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.person,
                            size: 40, color: Colors.blueAccent),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.name,
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(user.phoneNumber,
                                  style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade600)),
                              Text(user.church,
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade500)),
                              Text('세대주:${user.houseHoldHead}',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.grey),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      EditProfilePage(userProfile: user)),
                            ).then((_) {
                              context
                                  .read<HomeBloc>()
                                  .add(HomeProfileRefreshed());
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 오늘의 다짐 문구 카드
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('오늘의 다짐 문구',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        // --- ▼ [수정] Bloc 상태에서 직접 가져온 문구를 표시 ---
                        Text(
                          '현재 문구: "$currentPhrase"',
                          style: TextStyle(
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic),
                        ),
                        // --- ▲ [수정] ---
                        const SizedBox(height: 16),
                        TextField(
                          controller: _phraseController,
                          decoration: InputDecoration(
                            hintText: '홈 화면에 보일 문구를 작성하세요...',
                            border: const OutlineInputBorder(),
                            suffixIcon: _isPhraseSaving
                                ? const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.0))
                                : IconButton(
                                    icon: const Icon(Icons.save),
                                    onPressed: _savePhrase,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        PhraseHistoryPage(userId: user.uid)),
                              );
                            },
                            child: const Text('히스토리 보기'),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // skyScore 랭킹 섹션
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('하늘점수',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        FutureBuilder<Map<String, Map<String, int>>>(
                          future: _rankFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            if (snapshot.hasError) {
                              return const Center(
                                  child: Text('순위를 불러오는 데 실패했습니다.'));
                            }
                            if (!snapshot.hasData) {
                              return const Center(child: Text('순위 정보가 없습니다.'));
                            }

                            final churchRank = snapshot.data!['church']!;
                            final totalRank = snapshot.data!['total']!;

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildRankingInfo(
                                    '내 점수', '${user.heavenlyScore}점'),
                                _buildRankingInfo('교회 내 순위',
                                    '${churchRank['rank']}위 / ${churchRank['total']}명'),
                                _buildRankingInfo('전체 순위',
                                    '${totalRank['rank']}위 / ${totalRank['total']}명'),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.history),
                            label: const Text('점수 획득 내역 보기'),
                            onPressed: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                  builder: (_) => BlocProvider.value(
                                    // 현재 MyPage가 사용하고 있는 HomeBloc 인스턴스를
                                    // ScoreLogPage에 그대로 전달합니다.
                                    value: BlocProvider.of<HomeBloc>(context),
                                    child: const ScoreLogPage(),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // --- ▼ [추가] 관리자일 경우에만 교회 정보 관리 카드 표시 ---
                if (isAdmin) ...[
                  const SizedBox(height: 24),
                  _buildAdminCard(),
                ],
                // --- ▲ [추가] ---
                const SizedBox(height: 24),
                Center(
                  child: TextButton(
                    onPressed: () => _showWithdrawalDialog(user.uid),
                    child: const Text('회원 탈퇴',
                        style: TextStyle(
                            color: Colors.grey,
                            decoration: TextDecoration.underline)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ); // Removed the extra semicolon here
  }

  // --- ▼ [추가] 교회 정보 관리 카드 UI 위젯 ---
  Widget _buildAdminCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('교회 정보 관리',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.save, color: Colors.blueAccent),
                  onPressed: _saveChurchInfo,
                  tooltip: '교회 정보 저장',
                )
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(_zoomController, '줌(Zoom) 주소'),
            _buildTextField(_driveController, '구글드라이브 주소'),
            _buildTextField(_districtsController, '구역 목록 (,로 구분)'),
            _buildTextField(_positionsController, '직책 목록 (,로 구분)'),
            _buildTextField(_presbyteryController, '노회명'),
            _buildTextField(_businessNumberController, '사업자번호'),
            _buildTextField(_addressController, '주소'),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
  // --- ▲ [추가] ---

  Widget _buildRankingInfo(String title, String value) {
    return Column(
      children: [
        Text(title,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
