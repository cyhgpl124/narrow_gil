import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:narrow_gil/features/forum/models/forum_model.dart';
import 'package:narrow_gil/features/forum/services/forum_service.dart';
import 'package:narrow_gil/features/forum/view/widgets/edit_forum_dialog.dart';
import 'package:narrow_gil/home/bloc/home_bloc.dart';
import 'package:narrow_gil/home/models/user_profile.dart';

import 'package:excel/excel.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:screenshot/screenshot.dart';
import 'package:universal_html/html.dart' as html;
import 'package:device_info_plus/device_info_plus.dart'; // <-- 추가
import 'package:permission_handler/permission_handler.dart'; // <-- 추가

class ForumPage extends StatefulWidget {
  const ForumPage({super.key});

  @override
  State<ForumPage> createState() => _ForumPageState();
}

class _ForumPageState extends State<ForumPage> {
  DateTime _selectedDate = DateTime.now();
  final ForumService _forumService = ForumService();

  List<String> _userPositions = [];
  bool _isLoadingPosition = true;

  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchUserPosition();
      }
    });
  }

  Future<void> _fetchUserPosition() async {
    /* 기존과 동일 */
    if (!mounted) return;
    final homeState = context.read<HomeBloc>().state;
    if (homeState is! HomeLoadSuccess) return;
    final userProfile = homeState.userProfile;
    final phoneNumber = userProfile.phoneNumber;
    final church = userProfile.church;
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('approved_members')
            .doc(church)
            .collection('members')
            .where('phoneNumber', isEqualTo: phoneNumber)
            .limit(1)
            .get();
        if (querySnapshot.docs.isNotEmpty) {
          final memberData = querySnapshot.docs.first.data();
          final positionData = memberData['role'];
          if (mounted) {
            setState(() {
              if (positionData is List)
                _userPositions = positionData.map((e) => e.toString()).toList();
              else if (positionData is String)
                _userPositions =
                    positionData.split(',').map((p) => p.trim()).toList();
            });
          }
        }
      } catch (e) {
        debugPrint("role 정보를 불러오는 데 실패했습니다: $e");
      }
    }
    if (mounted) setState(() => _isLoadingPosition = false);
  }

  void _previousMonth() {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1);
    });
  }

  Future<bool> _requestPermission() async {
  // 웹 환경에서는 권한이 필요 없으므로 항상 true를 반환합니다.
  if (kIsWeb) {
    return true;
  }

  // iOS 플랫폼일 경우 사진첩 접근 권한을 요청합니다.
  if (Platform.isIOS) {
    final status = await Permission.photos.request();
    return status.isGranted;
  }

  // Android 플랫폼일 경우 SDK 버전에 따라 다른 권한을 요청합니다.
  if (Platform.isAndroid) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    PermissionStatus status;

    // Android 13 (API 33) 이상에서는 사진/동영상에 대한 개별 권한을 요청해야 합니다.
    if (androidInfo.version.sdkInt >= 33) {
      status = await Permission.photos.request();
    } else {
      // 그 이전 버전에서는 일반 저장소 권한을 요청합니다.
      status = await Permission.storage.request();
    }
    return status.isGranted;
  }

  // 기타 다른 플랫폼에서는 일단 true를 반환합니다.
  return true;
}

  Future<void> _captureAndSaveImage() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('이미지로 저장 중입니다...')));

    try {
      final imageBytes = await _screenshotController.capture(
          delay: const Duration(milliseconds: 100));
      if (imageBytes == null) return;

      final fileName =
          '제직회의_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.png';

      if (kIsWeb) {
        final blob = html.Blob([imageBytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('이미지 다운로드 시작: $fileName')));
      } else {
        final hasPermission = await _requestPermission();
        if (!hasPermission) throw Exception('저장 권한이 거부되었습니다.');

        final directory = await getApplicationDocumentsDirectory();
        final imagePath = await File('${directory.path}/$fileName').create();
        await imagePath.writeAsBytes(imageBytes);

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('이미지 저장 완료: $fileName'),
          action: SnackBarAction(
              label: '열기', onPressed: () => OpenFile.open(imagePath.path)),
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('이미지 저장 실패: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

// ✨ [수정] 엑셀 저장 함수가 출석 통계 데이터를 인자로 받도록 변경
  Future<void> _createAndSaveExcel(
    List<ForumTopic> currentTopics,
    List<ForumTopic> previousTopics,
    Map<String, dynamic> attendanceStats, // ✨ 추가된 인자
  ) async {
    if (_isSaving) return;
    if (currentTopics.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('저장할 데이터가 없습니다.')));
      return;
    }
    setState(() => _isSaving = true);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('엑셀 파일 생성 중입니다...')));

    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['제직회의'];
      CellStyle headerStyle = CellStyle(
          bold: true,
          verticalAlign: VerticalAlign.Center,
          horizontalAlign: HorizontalAlign.Center);

      final headers = [
        TextCellValue('구분'),
        TextCellValue('이전달계획/재정/안건'),
        TextCellValue('이번달실행/수입내역/토의결과'),
        TextCellValue('다음달계획/지출내역/실행내역')
      ];
      sheetObject.appendRow(headers);
      for (var i = 0; i < headers.length; i++) {
        var cell = sheetObject
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.cellStyle = headerStyle;
      }

      final previousPlansMap = {
        for (var topic in previousTopics)
          topic.id.split('_').last: topic.nextMonthPlan
      };

      for (var topic in currentTopics) {
        final topicKey = topic.id.split('_').last;
        List<CellValue> rowData = [];

        // ✨ [수정] '서기' 토픽일 경우, 인자로 받은 출석 통계 데이터를 사용하여 셀을 구성
        if (topicKey == '서기') {
          final statsText = '총원 ${attendanceStats['total']}명 / 출석 ${attendanceStats['attended']}명\n(${(attendanceStats['rate'] as double).toStringAsFixed(1)}%)';
          rowData = [
            TextCellValue(topic.title),
            TextCellValue(statsText), // 이전달 계획 대신 통계 정보 삽입
            TextCellValue(topic.thisMonthExecution),
            TextCellValue(topic.nextMonthPlan),
          ];
        } else if (topicKey == '회계' || topicKey == '기금') {
          final financeReport =
              '이월: ${topic.broughtForward}\n수입: ${topic.income}\n지출: ${topic.expenditure}\n잔액: ${topic.balance}';
          rowData = [
            TextCellValue(topic.title),
            TextCellValue(financeReport),
            TextCellValue(topic.incomeDetails),
            TextCellValue(topic.expenditureDetails)
          ];
        } else if (topicKey == '안건토의') {
          rowData = [
            TextCellValue(topic.title),
            TextCellValue(topic.agendaContent),
            TextCellValue(topic.discussionResult),
            TextCellValue(topic.actionLog)
          ];
        } else {
          rowData = [
            TextCellValue(topic.title),
            TextCellValue(previousPlansMap[topicKey] ?? ''),
            TextCellValue(topic.thisMonthExecution),
            TextCellValue(topic.nextMonthPlan)
          ];
        }
        sheetObject.appendRow(rowData);
      }

      final fileBytes = excel.save();
      if (fileBytes == null) return;

      final fileName =
          '제직회의_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';

      if (kIsWeb) {
        final blob = html.Blob([
          fileBytes
        ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('엑셀 파일 다운로드 시작: $fileName')));
      } else {
        final hasPermission = await _requestPermission();
        if (!hasPermission) throw Exception('저장 권한이 거부되었습니다.');
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$fileName';
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('엑셀 저장 완료: $fileName'),
          action: SnackBarAction(
              label: '열기', onPressed: () => OpenFile.open(filePath)),
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('엑셀 저장 실패: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeState = context.watch<HomeBloc>().state;
    if (homeState is! HomeLoadSuccess) {
      return const Scaffold(
        body: Center(child: Text("사용자 정보를 불러올 수 없습니다.")),
      );
    }

    final userProfile = homeState.userProfile;
    final currentMonthString = DateFormat('yyyy-MM').format(_selectedDate);
    final previousMonth = DateTime(_selectedDate.year, _selectedDate.month - 1);
    final previousMonthString = DateFormat('yyyy-MM').format(previousMonth);

    return _isLoadingPosition
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : FutureBuilder<Map<String, List<ForumTopic>>>(
            future: _forumService.getForumDataForTwoMonths(
              churchName: userProfile.church,
              currentMonth: currentMonthString,
              previousMonth: previousMonthString,
            ),
            builder: (context, snapshot) {
              Widget bodyWidget;
              List<ForumTopic> currentTopics = [];
              List<ForumTopic> previousTopics = [];

              if (snapshot.connectionState == ConnectionState.waiting &&
                  !_isSaving) {
                bodyWidget = const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                bodyWidget = Center(child: Text('오류: ${snapshot.error}'));
              } else if (!snapshot.hasData ||
                  snapshot.data!.values.every((list) => list.isEmpty)) {
                bodyWidget = Center(
                    child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('해당 월의 제직회의 데이터가 없습니다.'),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      child: const Text('데이터 생성 및 새로고침'),
                    )
                  ],
                ));
              } else {
                currentTopics = snapshot.data!['current'] ?? [];
                previousTopics = snapshot.data!['previous'] ?? [];

                bodyWidget = Screenshot(
                  controller: _screenshotController,
                  child: Container(
                    color: Colors.black,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildForumContent(context, currentTopics,
                          previousTopics, userProfile, previousMonthString),
                    ),
                  ),
                );
              }

              return Scaffold(
                backgroundColor: Colors.black,
                appBar: AppBar(
                  title: Text(
                      '${DateFormat('yyyy년 M월').format(_selectedDate)} ${userProfile.church} 제직회의'),
                  backgroundColor: Colors.black,
                  elevation: 1,
                  actions: [
                    if (_isSaving)
                      const Padding(
                          padding: EdgeInsets.only(right: 16.0),
                          child: Center(
                              child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 3)))),
                    if (!_isSaving)
                      IconButton(
                          icon: const Icon(Icons.image),
                          onPressed: _captureAndSaveImage,
                          tooltip: '이미지로 저장'),
                    if (!_isSaving)
                      IconButton(
                          icon: const Icon(Icons.description),
                          onPressed: () async {
                            // 1. 먼저 출석 통계를 비동기적으로 불러옵니다.
                            final stats = await _forumService.getAttendanceStats(userProfile.church, currentMonthString);
                            // 2. 불러온 통계 데이터와 함께 엑셀 생성 함수를 호출합니다.
                            _createAndSaveExcel(currentTopics, previousTopics, stats);
                          },
                          tooltip: '엑셀로 저장'),
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _previousMonth,
                      tooltip: '이전 달',
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _nextMonth,
                      tooltip: '다음 달',
                    ),
                  ],
                ),
                body: bodyWidget,
              );
            },
          );
  }

  Widget _buildForumContent(
    BuildContext context,
    List<ForumTopic> currentTopics,
    List<ForumTopic> previousTopics,
    UserProfile userProfile,
    String previousMonthString,
  ) {
    final defaultTopics = currentTopics
        .where((topic) =>
            !topic.id.endsWith('_안건토의') && !topic.id.endsWith('_기타보고'))
        .toList();
    final agendaTopic = currentTopics.firstWhere(
        (topic) => topic.id.endsWith('_안건토의'),
        orElse: () => ForumTopic(
            id: '',
            title: '',
            responsiblePosition: [],
            thisMonthExecution: '',
            nextMonthPlan: '',
            lastEditor: '',
            lastEditedAt: Timestamp.now()));
    final etcTopic = currentTopics.firstWhere(
        (topic) => topic.id.endsWith('_기타보고'),
        orElse: () => ForumTopic(
            id: '',
            title: '',
            responsiblePosition: [],
            thisMonthExecution: '',
            nextMonthPlan: '',
            lastEditor: '',
            lastEditedAt: Timestamp.now()));

    return Column(
      children: [
        _buildForumTable(context, defaultTopics, previousTopics, userProfile,
            previousMonthString),
        if (agendaTopic.id.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildAgendaTable(context, agendaTopic, userProfile),
        ],
        if (etcTopic.id.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildForumTable(context, [etcTopic], previousTopics, userProfile,
              previousMonthString,
              showHeader: false),
        ]
      ],
    );
  }

  Widget _buildForumTable(
      BuildContext context,
      List<ForumTopic> topics,
      List<ForumTopic> previousTopics,
      UserProfile userProfile,
      String previousMonthString,
      {bool showHeader = true}) {
    final previousPlansMap = {
      for (var topic in previousTopics)
        topic.id.split('_').last: topic.nextMonthPlan
    };

    return Card(
      color: Colors.grey[900],
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Table(
        border: TableBorder.all(color: Colors.grey.shade800, width: 1.5),
        columnWidths: const {
          0: IntrinsicColumnWidth(flex: 1.5),
          1: FlexColumnWidth(2.5),
          2: FlexColumnWidth(3),
          3: FlexColumnWidth(3),
        },
        children: [
          if (showHeader)
            TableRow(
              decoration: BoxDecoration(color: Colors.grey[800]),
              children: [
                _buildHeaderCell('구분'),
                _buildHeaderCell('이전달계획'),
                _buildHeaderCell('이번달실행'),
                _buildHeaderCell('다음달계획'),
              ],
            ),
          ...topics.map((topic) {
            final bool isDeveloper = _userPositions.contains('개발자');
            final bool isResponsible = _userPositions
                .any((userPos) => topic.responsiblePosition.contains(userPos));
            final bool isEditable = isDeveloper || isResponsible;
            final topicKey = topic.id.split('_').last;

            bool isSecretaryTopic = topicKey == '서기';
            bool isAccountingTopic = topicKey == '회계' || topicKey == '기금';

            if (isSecretaryTopic) {
              return _buildSecretaryRow(
                  context, topic, userProfile, previousMonthString, isEditable);
            } else if (isAccountingTopic) {
              return _buildAccountingRow(
                  context, topic, userProfile, isEditable);
            } else {
              return _buildDefaultRow(context, topic, userProfile,
                  previousPlansMap[topicKey] ?? '', isEditable);
            }
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildAgendaTable(
      BuildContext context, ForumTopic topic, UserProfile userProfile) {
    final bool isDeveloper = _userPositions.contains('개발자');
    final bool isResponsible =
        _userPositions.any((pos) => topic.responsiblePosition.contains(pos));
    final bool isEditable = isDeveloper || isResponsible;

    return Card(
      color: Colors.grey[900],
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Table(
        border: TableBorder.all(color: Colors.grey.shade800, width: 1.5),
        columnWidths: const {
          0: IntrinsicColumnWidth(flex: 1.5),
          1: FlexColumnWidth(3),
          2: FlexColumnWidth(3),
          3: FlexColumnWidth(3),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: Colors.grey[800]),
            children: [
              _buildHeaderCell('구분'),
              _buildHeaderCell('안건내용'),
              _buildHeaderCell('토의결과'),
              _buildHeaderCell('실행내역'),
            ],
          ),
          _buildAgendaRow(context, topic, userProfile, isEditable),
        ],
      ),
    );
  }

  TableRow _buildAgendaRow(BuildContext context, ForumTopic topic,
      UserProfile userProfile, bool isEditable) {
    return TableRow(
      children: [
        _buildTitleCell(topic.title),
        _buildEditableCell(context, topic.agendaContent, isEditable,
            () => _showEditDialog(context, topic, userProfile)),
        _buildEditableCell(context, topic.discussionResult, isEditable,
            () => _showEditDialog(context, topic, userProfile)),
        _buildEditableCell(context, topic.actionLog, isEditable,
            () => _showEditDialog(context, topic, userProfile)),
      ],
    );
  }

  TableRow _buildDefaultRow(BuildContext context, ForumTopic topic,
      UserProfile userProfile, String previousPlan, bool isEditable) {
    return TableRow(
      decoration: BoxDecoration(color: Colors.grey[900]),
      children: [
        _buildTitleCell(topic.title),
        _buildContentCell(previousPlan),
        _buildEditableCell(context, topic.thisMonthExecution, isEditable,
            () => _showEditDialog(context, topic, userProfile)),
        _buildEditableCell(context, topic.nextMonthPlan, isEditable,
            () => _showEditDialog(context, topic, userProfile)),
      ],
    );
  }

  TableRow _buildSecretaryRow(BuildContext context, ForumTopic topic,
      UserProfile userProfile, String previousMonthString, bool isEditable) {
    return TableRow(
      children: [
        _buildTitleCell(topic.title),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: FutureBuilder<Map<String, dynamic>>(
              future: _forumService.getAttendanceStats(
                  userProfile.church, previousMonthString),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)));
                }
                if (!snapshot.hasData || snapshot.hasError) {
                  return const Text('출석정보 없음',
                      style: TextStyle(color: Colors.orangeAccent));
                }
                final stats = snapshot.data!;
                final text =
                    '총원 ${stats['total']}명 / 출석 ${stats['attended']}명\n(${(stats['rate'] as double).toStringAsFixed(1)}%)';
                return Text(text,
                    style: TextStyle(color: Colors.grey.shade300),
                    textAlign: TextAlign.center);
              },
            ),
          ),
        ),
        _buildEditableCell(context, topic.thisMonthExecution, isEditable,
            () => _showEditDialog(context, topic, userProfile)),
        _buildEditableCell(context, topic.nextMonthPlan, isEditable,
            () => _showEditDialog(context, topic, userProfile)),
      ],
    );
  }

  TableRow _buildAccountingRow(BuildContext context, ForumTopic topic,
      UserProfile userProfile, bool isEditable) {
    final f = NumberFormat('#,###');
    Widget monetaryCell = _buildEditableAccountingCell(
        isEditable: isEditable,
        onTap: () => _showEditDialog(context, topic, userProfile),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildAccountingItem('이월', f.format(topic.broughtForward)),
          _buildAccountingItem('수입', f.format(topic.income)),
          _buildAccountingItem('지출', f.format(topic.expenditure)),
          const Divider(color: Colors.white54, height: 16),
          _buildAccountingItem('잔액', f.format(topic.balance), isBold: true)
        ]));
    Widget incomeDetailsCell = _buildEditableAccountingCell(
        isEditable: isEditable,
        onTap: () => _showEditDialog(context, topic, userProfile),
        child: Text(topic.incomeDetails.isEmpty ? '내역 없음' : topic.incomeDetails,
            style: TextStyle(color: Colors.grey.shade300)));
    Widget expenditureDetailsCell = _buildEditableAccountingCell(
        isEditable: isEditable,
        onTap: () => _showEditDialog(context, topic, userProfile),
        child: Text(
            topic.expenditureDetails.isEmpty
                ? '내역 없음'
                : topic.expenditureDetails,
            style: TextStyle(color: Colors.grey.shade300)));
    return TableRow(children: [
      _buildTitleCell(topic.title),
      monetaryCell,
      incomeDetailsCell,
      expenditureDetailsCell
    ]);
  }

  Widget _buildAccountingItem(String label, String value,
      {bool isBold = false}) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(color: Colors.grey.shade400)),
          Text(value,
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal))
        ]));
  }

  Widget _buildEditableAccountingCell(
      {required Widget child,
      required bool isEditable,
      required VoidCallback onTap}) {
    return TableCell(
        verticalAlignment: TableCellVerticalAlignment.middle,
        child: InkWell(
            onTap: isEditable ? onTap : null,
            child: Container(
                color: isEditable ? Colors.blueGrey[800] : Colors.transparent,
                padding: const EdgeInsets.all(12.0),
                child: child)));
  }

  Widget _buildHeaderCell(String title) {
    return TableCell(
        verticalAlignment: TableCellVerticalAlignment.middle,
        child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
            child: Center(
                child: Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 15)))));
  }

  Widget _buildTitleCell(String title) {
    return TableCell(
        verticalAlignment: TableCellVerticalAlignment.middle,
        child: Container(
            color: Colors.grey[850],
            padding: const EdgeInsets.all(12.0),
            child: Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center)));
  }

  Widget _buildContentCell(String content) {
    return TableCell(
        verticalAlignment: TableCellVerticalAlignment.middle,
        child: Padding(
            padding: const EdgeInsets.all(12.0),
            child:
                Text(content, style: TextStyle(color: Colors.grey.shade300))));
  }

  Widget _buildEditableCell(BuildContext context, String content,
      bool isEditable, VoidCallback onTap) {
    return TableCell(
        verticalAlignment: TableCellVerticalAlignment.middle,
        child: InkWell(
            onTap: isEditable ? onTap : null,
            child: Container(
                color: isEditable ? Colors.blueGrey[800] : Colors.transparent,
                padding: const EdgeInsets.all(12.0),
                child: Row(children: [
                  Expanded(
                      child: Text(content,
                          style: TextStyle(
                              color: isEditable
                                  ? Colors.white
                                  : Colors.grey.shade400))),
                  if (isEditable)
                    const Icon(Icons.edit, size: 16, color: Colors.white70)
                ]))));
  }

  void _showEditDialog(
      BuildContext context, ForumTopic topic, UserProfile userProfile) {
    showDialog(
      context: context,
      builder: (_) => Theme(
        data: ThemeData.dark(),
        child: EditForumDialog(
          topic: topic,
          onSave: (Map<String, dynamic> updateData) {
            final topicKey = topic.id.split('_').last;

            if (topicKey == '회계' || topicKey == '기금') {
              _forumService.updateAccountingTopic(
                churchName: userProfile.church,
                yearMonth: DateFormat('yyyy-MM').format(_selectedDate),
                topicId: topic.id,
                broughtForward: updateData['broughtForward'],
                income: updateData['income'],
                expenditure: updateData['expenditure'],
                incomeDetails: updateData['incomeDetails'],
                expenditureDetails: updateData['expenditureDetails'],
                editorName: userProfile.name,
              );
            } else if (topicKey == '안건토의') {
              _forumService.updateAgendaTopic(
                churchName: userProfile.church,
                yearMonth: DateFormat('yyyy-MM').format(_selectedDate),
                topicId: topic.id,
                agendaContent: updateData['agendaContent'],
                discussionResult: updateData['discussionResult'],
                actionLog: updateData['actionLog'],
                editorName: userProfile.name,
              );
            } else {
              _forumService.updateForumTopic(
                churchName: userProfile.church,
                yearMonth: DateFormat('yyyy-MM').format(_selectedDate),
                topicId: topic.id,
                thisMonthExecution: updateData['thisMonthExecution'],
                nextMonthPlan: updateData['nextMonthPlan'],
                editorName: userProfile.name,
              );
            }

            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) setState(() {});
            });
          },
        ),
      ),
    );
  }
}
