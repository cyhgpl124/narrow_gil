// lib/features/accounting/view/accounting_section_page.dart
import 'dart:typed_data'; // CSV 업로드를 위해 추가
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart'; // CSV 업로드를 위해 추가
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:narrow_gil/features/accounting/models/accounting_log_model.dart';
import 'package:narrow_gil/features/accounting/models/receipt_model.dart';
import 'package:narrow_gil/features/accounting/services/accounting_service.dart';
import 'package:narrow_gil/features/accounting/view/widgets/add_accounting_log_dialog.dart'; // 신규 다이얼로그 import
import 'package:narrow_gil/home/bloc/home_bloc.dart';
import 'dart:convert'; // ✨ [추가] UTF-8 인코딩을 위해 필요
import 'package:flutter/foundation.dart' show kIsWeb; // ✨ [추가] 웹 환경 감지를 위해 필요
import 'package:universal_html/html.dart' as html; // ✨ [추가] 웹 파일 다운로드를 위해 필요
import 'dart:typed_data'; // ✨ [추가] Uint8List를 사용하기 위해 필요
import 'dart:io'; // ✨ [추가] 모바일 파일 시스템 접근을 위해 필요
import 'package:path_provider/path_provider.dart'; // ✨ [추가]
import 'package:share_plus/share_plus.dart'; // ✨ [추가]
import 'dart:convert'; // ✨ [추가] UTF-8 인코딩을 위해 필요



class AccountingSectionPage extends StatefulWidget {
  final String sectionName; // 예: "총회 선교부", "서울교회 청년부"
  final String churchId;    // 예: "총회", "서울교회"

  const AccountingSectionPage({super.key, required this.sectionName, required this.churchId});

  @override
  State<AccountingSectionPage> createState() => _AccountingSectionPageState();
}

class _AccountingSectionPageState extends State<AccountingSectionPage> {
  final AccountingService _accountingService = AccountingService();
  late String _actualDistrict; // 실제 구역 이름 (예: "선교부", "청년부")

  // 필터 상태 변수
  int? _selectedYear = DateTime.now().year;
  String? _selectedManagerName = '전체';
  LogType? _selectedLogType;
  String? _selectedHouseholdHead = '전체';

  // ✨ [추가] 상세 내역 페이지네이션 상태
  bool _isLogLoading = true;
  List<AccountingLogModel> _accountingLogs = [];
  DocumentSnapshot? _lastLogDocument;
  bool _hasMoreLogs = true;

  // ✨ [추가] 처리 로그 페이지네이션 상태
  bool _isApprovalLogLoading = true;
  List<ApprovalLog> _approvalLogs = [];
  DocumentSnapshot? _lastApprovalLogDocument;
  bool _hasMoreApprovalLogs = true;

   @override
  void initState() {
    super.initState();
    var parts = widget.sectionName.split(' ');
    _actualDistrict = parts.length > 1 ? parts.last : widget.sectionName;
    // 첫 페이지 데이터 로드
    _loadInitialData();
  }

   void _loadInitialData() {
    _loadAccountingLogs(isInitial: true);
    _loadApprovalLogs(isInitial: true);
  }

  //    // ✨ [수정] CSV 다운로드 기능 함수
  // Future<void> _downloadCsv() async {
  //   try {
  //     final csvData = await _accountingService.exportAccountingLogsToCsv(
  //       widget.churchId,
  //       widget.sectionName,
  //     );

  //     if (kIsWeb) {
  //       // 1. UTF-8 BOM(Byte Order Mark) 리스트를 생성합니다.
  //       final bom = [0xEF, 0xBB, 0xBF];
  //       // 2. CSV 데이터를 UTF-8 바이트 리스트로 변환합니다.
  //       final csvBytes = utf8.encode(csvData);
  //       // 3. BOM과 데이터 바이트를 합쳐 최종 바이트 리스트를 만듭니다.
  //       final bytesWithBom = bom + csvBytes;

  //       // ✨ [수정] Blob을 생성할 때, Uint8List로 명확하게 타입을 지정해줍니다.
  //       // Blob의 MIME 타입을 'application/octet-stream'으로 설정하여
  //       // 브라우저가 파일을 텍스트로 해석하지 않고 원본 그대로 다운로드하도록 강제합니다.
  //       final blob = html.Blob([Uint8List.fromList(bytesWithBom)], 'application/octet-stream');
  //       final url = html.Url.createObjectUrlFromBlob(blob);
  //       final anchor = html.AnchorElement(href: url)
  //         ..setAttribute("download", "${widget.sectionName}_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv")
  //         ..click();
  //       html.Url.revokeObjectUrl(url);

  //     } else {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('CSV 다운로드는 웹 환경에서만 지원됩니다.')),
  //       );
  //     }
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('CSV 다운로드 실패: $e')),
  //     );
  //   }
  // }


// ✨ [수정] CSV 다운로드 기능 함수 (모바일 지원 추가)
  Future<void> _downloadCsv() async {
    try {
      final csvData = await _accountingService.exportAccountingLogsToCsv(
        widget.churchId,
        widget.sectionName,
      );

      final fileName = "${widget.sectionName}_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv";

      // 1. UTF-8 BOM(Byte Order Mark)과 데이터를 바이트로 변환 (한글 깨짐 방지)
      final bom = [0xEF, 0xBB, 0xBF];
      final csvBytes = utf8.encode(csvData);
      final bytesWithBom = bom + csvBytes;

      if (kIsWeb) {
        // --- 웹(Web) 환경 다운로드 로직 ---
        final blob = html.Blob([Uint8List.fromList(bytesWithBom)], 'application/octet-stream');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", fileName)
          ..click();
        html.Url.revokeObjectUrl(url);

      } else {
        // --- 모바일(Mobile) 앱 환경 공유 로직 ---
        // 1. 앱의 임시 저장소 경로를 가져옵니다.
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/$fileName';

        // 2. 임시 경로에 CSV 파일을 생성합니다.
        final file = File(filePath);
        await file.writeAsBytes(bytesWithBom);

        // 3. share_plus 패키지를 사용하여 공유 시트를 띄웁니다.
        // 사용자는 이 시트를 통해 파일을 저장하거나 다른 앱으로 보낼 수 있습니다.
        final xfile = XFile(filePath);
        await Share.shareXFiles([xfile], text: '회계 내역 파일');
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV 다운로드 실패: $e')),
        );
      }
    }
  }

  // ✨ [추가] 아래 함수를 클래스 내부에 붙여넣어 주세요.
  /// 증빙의 상태에 따라 적절한 아이콘과 색상을 가진 칩(Chip) 위젯을 생성합니다.
  Widget _buildStatusChip(ReceiptStatus status) {
    IconData icon;
    Color color;
    String label;

    switch (status) {
      case ReceiptStatus.pending:
        icon = Icons.hourglass_top_rounded;
        color = Colors.orange;
        label = '처리중';
        break;
      case ReceiptStatus.approved:
        icon = Icons.check_circle_rounded;
        color = Colors.green;
        label = '처리완료';
        break;
      case ReceiptStatus.rejected:
        icon = Icons.cancel_rounded;
        color = Colors.red;
        label = '반려';
        break;
    }
    return Chip(
      avatar: Icon(icon, color: Colors.white, size: 16),
      label: Text(label,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold)),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
    );
  }
  // ✨ [추가] 상세 입출금 내역 로드 함수
  Future<void> _loadAccountingLogs({bool isInitial = false}) async {
    if (!isInitial && !_hasMoreLogs) return;
    setState(() => _isLogLoading = true);

    try {
      final result = await _accountingService.getAccountingLogsPaginated(
        widget.churchId,
        widget.sectionName,
        limit: 10,
        startAfter: isInitial ? null : _lastLogDocument,
        year: _selectedYear,
        name: _selectedManagerName,
        type: _selectedLogType,
        householdHead: _selectedHouseholdHead,
      );
      if(mounted) {
        setState(() {
          if (isInitial) {
            _accountingLogs = result['logs'];
          } else {
            _accountingLogs.addAll(result['logs']);
          }
          _lastLogDocument = result['lastDocument'];
          _hasMoreLogs = result['hasMore'];
          _isLogLoading = false;
        });
      }
    } catch (e) {
      // 오류 처리
    }
  }

  // ✨ [추가] 증빙 처리 로그 로드 함수
  Future<void> _loadApprovalLogs({bool isInitial = false}) async {
    if (!isInitial && !_hasMoreApprovalLogs) return;
    setState(() => _isApprovalLogLoading = true);

    try {
      final result = await _accountingService.getApprovalLogsPaginated(
        churchId: widget.churchId,
        limit: 10,
        startAfter: isInitial ? null : _lastApprovalLogDocument,
      );
       if(mounted) {
        setState(() {
          if (isInitial) {
            _approvalLogs = result['logs'];
          } else {
            _approvalLogs.addAll(result['logs']);
          }
          _lastApprovalLogDocument = result['lastDocument'];
          _hasMoreApprovalLogs = result['hasMore'];
          _isApprovalLogLoading = false;
        });
      }
    } catch (e) {
      // 오류 처리
    }
  }

  // ✨ [추가] CSV 업로드 시 동명이인 선택을 위한 다이얼로그
  Future<Map<String, dynamic>?> _showDuplicateUserSelectionDialog(List<Map<String, dynamic>> users) async {
    // '외부인 처리' 선택을 식별하기 위한 특수 객체
    final Map<String, String> treatAsExternalChoice = {'id': '__EXTERNAL__'};

    return showDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: false, // 사용자는 반드시 선택해야 함
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('동명이인 발견'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: users.length,
              itemBuilder: (BuildContext context, int index) {
                final user = users[index];
                return ListTile(
                  title: Text('${user['church']} ${user['name']}'),
                  subtitle: Text('생년월일: ${user['birthDate']}'),
                  onTap: () {
                    Navigator.of(context).pop(user);
                  },
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('선택 안함 (외부인으로 처리)'),
              onPressed: () {
                Navigator.of(context).pop(treatAsExternalChoice);
              },
            ),
            TextButton(
              child: const Text('업로드 중단'),
              onPressed: () {
                Navigator.of(context).pop(null); // null은 업로드 중단을 의미
              },
            ),
          ],
        );
      },
    );
  }


  // ✨ [수정] 대화형 CSV 업로드 기능
  Future<void> _uploadCsv() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.single.bytes == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('파일이 선택되지 않았거나 읽을 수 없습니다.')));
        return;
      }

      final Uint8List fileBytes = result.files.single.bytes!;
      String csvData;
      if (fileBytes.length >= 3 && fileBytes[0] == 0xEF && fileBytes[1] == 0xBB && fileBytes[2] == 0xBF) {
        csvData = utf8.decode(fileBytes.sublist(3));
      } else {
        csvData = utf8.decode(fileBytes);
      }

      final lines = csvData.trim().split('\n').where((line) => line.trim().isNotEmpty).toList();
      if (lines.length < 2) throw Exception("CSV 데이터가 없거나 헤더만 존재합니다.");

      final user = (context.read<HomeBloc>().state as HomeLoadSuccess).userProfile;
      final batch = _accountingService.getBatch();
      bool isCancelled = false;

      // 헤더를 제외한 데이터 라인에 대해 순차적으로 처리
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i];
        final values = line.split(',');
        if (values.length < 9) continue;

        final householdHeadName = values[2].trim();
        String? userId;
        String? userChurch;

        if (householdHeadName.isNotEmpty) {
          final potentialUsers = await _accountingService.findUsersByName(householdHeadName);
          if (potentialUsers.length > 1) {
            // 동명이인 발생 시, 사용자 선택 다이얼로그 표시
            final selectedUserResult = await _showDuplicateUserSelectionDialog(potentialUsers);

            if (selectedUserResult == null) { // 사용자가 '업로드 중단' 선택
              isCancelled = true;
              break;
            } else if (selectedUserResult['id'] == '__EXTERNAL__') {
              // '외부인으로 처리' 선택, userId는 null로 유지
            } else {
              // 특정 사용자 선택
              userId = selectedUserResult['id'];
              userChurch = selectedUserResult['church'];
            }
          } else if (potentialUsers.length == 1) {
            // 유일한 사용자를 찾음
            userId = potentialUsers.first['id'];
            userChurch = potentialUsers.first['church'];
          }
        }

        if (isCancelled) break;

        final tier1 = values[5].trim();
        final tier2 = values[6].trim();
        final details = values[7].trim();
        String item = (tier1.isEmpty && tier2.isEmpty) ? details : '$tier1:$tier2:$details';

        final newLog = AccountingLogModel(
          id: '', // ID는 서비스에서 생성
          date: Timestamp.now(), // 필요 시 CSV에서 날짜 파싱
          fromArea: values[0].trim().isEmpty ? null : values[0].trim(),
          toArea: values[1].trim().isEmpty ? null : values[1].trim(),
          householdHead: householdHeadName,
          userId: userId,
          type: values[3].trim().toLowerCase() == 'income' ? LogType.income : LogType.expense,
          amount: double.tryParse(values[4].trim()) ?? 0.0,
          item: item,
          managerName: values[8].trim().isNotEmpty ? values[8].trim() : user.name,
          managerId: user.uid,
          hasProof: false,
        );

        // 처리된 데이터를 배치에 추가
        await _accountingService.processCsvRowForBatch(
          batch: batch,
          churchId: widget.churchId,
          sectionName: widget.sectionName,
          log: newLog,
          targetUserChurch: userChurch,
        );
      }

      if (isCancelled) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV 업로드가 취소되었습니다.')));
        return;
      }

      // 모든 행 처리가 끝나면 배치 작업을 커밋
      await _accountingService.commitBatch(batch);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV 데이터가 성공적으로 업로드되었습니다.')));
        _loadAccountingLogs(isInitial: true);
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CSV 업로드 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.sectionName} 회계')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✨ [추가] 재정 요약 섹션
            _buildSummarySection(),
            const SizedBox(height: 24),

            // --- ▼ [수정] 필터 제목 추가 ---
            _buildFilterControls(context),
            const SizedBox(height: 24),

            _buildSectionTitle('상세 입출금 내역'),
            _buildAccountingLogTable(),
            const SizedBox(height: 32),

            // --- ▼ [삭제] 구역 간 거래내역 섹션 제거 ---

            _buildSectionTitle('처리 대기 증빙'),
            _buildReceiptsForReview(),

            // ✨ [추가] 증빙 처리 로그 섹션
            _buildSectionTitle('최근 처리 로그'),
            _buildApprovalLogList(),
          ],
        ),
      ),
    );
  }

  // ✨ [추가] 재정 요약 UI 위젯
  Widget _buildSummarySection() {
    return StreamBuilder<Map<String, double>>(
      stream: _accountingService.getSectionSummary(widget.churchId, widget.sectionName),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final summary = snapshot.data!;
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSummaryItem('현재 잔액', summary['currentBalance']!),
                _buildSummaryItem('이번달 수입', summary['thisMonthIncome']!, color: Colors.blue),
                _buildSummaryItem('이번달 지출', summary['thisMonthExpense']!, color: Colors.red),
                _buildSummaryItem('전달 이월', summary['previousMonthCarryover']!),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryItem(String title, double amount, {Color? color}) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          NumberFormat('#,###').format(amount),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      );
  }

  // --- ▼ [수정] 각 필터 위에 설명 텍스트를 추가 ---
  Widget _buildFilterControls(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 24.0, // 필터 간 가로 간격
              runSpacing: 12.0, // 필터 간 세로 간격
              crossAxisAlignment: WrapCrossAlignment.end, // 하단 정렬
              children: [
                // 연도 필터
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('조회 연도', style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    _buildDropdown<int>(
                      hint: '연도 선택',
                      value: _selectedYear,
                      items: List.generate(10, (index) => DateTime.now().year - index),
                      onChanged: (val) => setState(() => _selectedYear = val),
                      itemBuilder: (year) => DropdownMenuItem(value: year, child: Text('$year년')),
                    ),
                  ],
                ),
                // 담당자 필터
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('담당자', style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    _buildFutureDropdown(
                      hint: '담당자 선택',
                      future: _accountingService.getMemberNamesByDistrict(widget.churchId, _actualDistrict),
                      value: _selectedManagerName,
                      onChanged: (val) => setState(() => _selectedManagerName = val),
                    ),
                  ],
                ),
                // 수입/지출 필터
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('수입/지출', style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    _buildDropdown<LogType?>(
                      hint: '전체',
                      value: _selectedLogType,
                      items: [null, LogType.income, LogType.expense],
                      onChanged: (val) => setState(() => _selectedLogType = val),
                      itemBuilder: (type) {
                        String text = '전체';
                        if (type == LogType.income) text = '수입';
                        if (type == LogType.expense) text = '지출';
                        return DropdownMenuItem(value: type, child: Text(text));
                      },
                    ),
                  ],
                ),
                // 거래대상 필터
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('세대주', style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    _buildFutureDropdown(
                      hint: '대상 선택',
                      future: _accountingService.getHouseholdHeads(widget.churchId),
                      value: _selectedHouseholdHead,
                      onChanged: (val) => setState(() => _selectedHouseholdHead = val),
                    ),
                  ],
                ),
                // CSV 업로드 버튼
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     const Text('데이터 관리', style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold)),
                     const SizedBox(height: 4),
                     Row(
                       children: [
                         TextButton.icon(
                          icon: const Icon(Icons.upload_file, size: 20),
                          label: const Text('CSV 업로드'),
                          onPressed: _uploadCsv, // 기존 업로드 함수 연결
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.download_for_offline, size: 20),
                          label: const Text('CSV 다운로드'),
                          onPressed: _downloadCsv, // 새로 만든 다운로드 함수 연결
                        ),
                       ],
                     )
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({ required String hint, T? value, required List<T> items, required void Function(T?) onChanged, required DropdownMenuItem<T> Function(T) itemBuilder }) {
    return DropdownButton<T>(
      hint: Text(hint),
      value: value,
      items: items.map(itemBuilder).toList(),
      onChanged: onChanged,
      underline: Container(),
    );
  }

  Widget _buildFutureDropdown({ required String hint, required Future<List<String>> future, String? value, required void Function(String?) onChanged }) {
    return FutureBuilder<List<String>>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(width: 100, child: Text('로딩...'));
        final items = ['전체', ...snapshot.data!];
        return DropdownButton<String>(
          hint: Text(hint),
          value: items.contains(value) ? value : '전체',
          items: items.map((item) => DropdownMenuItem(value: item, child: Text(item, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: onChanged,
          underline: Container(),
        );
      },
    );
  }

 Widget _buildAccountingLogTable() {
    String formatItem(String item) {
      final parts = item.split(':');
      return parts.length == 3 ? '[${parts[0]}] ${parts[1]} - ${parts[2]}' : item;
    }

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: ['날짜', '종류', '보낸곳', '받는곳', '세대주', '금액', '관리항목', '담당자', '삭제']
                .map((c) => DataColumn(label: Text(c, style: const TextStyle(fontWeight: FontWeight.bold))))
                .toList(),
            rows: _accountingLogs.map((log) {
              final isExpense = log.type == LogType.expense;
              return DataRow(cells: [
                DataCell(Text(DateFormat('yy-MM-dd').format(log.date.toDate()))),
                DataCell(Text(isExpense ? '지출' : '수입', style: TextStyle(color: isExpense ? Colors.red : Colors.blue))),
                DataCell(Text(log.fromArea ?? '-')),
                DataCell(Text(log.toArea ?? '-')),
                DataCell(Text(log.householdHead)),
                DataCell(Text(NumberFormat('#,###').format(log.amount))),
                DataCell(Text(formatItem(log.item))),
                DataCell(Text(log.managerName)),
                // ✨ [추가] 상세 내역 삭제 버튼
                DataCell(IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () => _confirmDeleteLog(context, log.id),
                )),
              ]);
            }).toList(),
          ),
        ),
        if (_isLogLoading) const Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()),
        if (_hasMoreLogs && !_isLogLoading)
          TextButton(onPressed: () => _loadAccountingLogs(), child: const Text('더 보기')),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('내역 추가'),
            // ✨ [수정] onPressed를 async로 바꾸고, 다이얼로그의 결과를 받아 처리합니다.
            onPressed: () async {
              final isChurchLevel = widget.sectionName == widget.churchId;

              final result = await showAddAccountingLogDialog(
                context,
                churchId: widget.churchId,
                currentSection: widget.sectionName,
                isChurchLevel: isChurchLevel,
              );

              // 다이얼로그에서 성공적으로 제출되었을 경우 (result == true) 목록을 새로고침합니다.
              if (result == true && mounted) {
                _loadAccountingLogs(isInitial: true);
              }
            },
          ),
        )
      ],
    );
  }

  Widget _buildReceiptsForReview() {
    final user = (context.read<HomeBloc>().state as HomeLoadSuccess).userProfile;
    return StreamBuilder<List<ReceiptModel>>(
      stream: _accountingService.getReceiptsForReview(widget.churchId, _actualDistrict),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.isEmpty) return Center(child: Text('$_actualDistrict에 제출된 증빙이 없습니다.'));
        final receipts = snapshot.data!;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: receipts.length,
          itemBuilder: (context, index) {
            final receipt = receipts[index];
            return Card(
              child: ListTile(
                onTap: () => _showReceiptImagesDialog(context, receipt),
                leading: CircleAvatar(child: Text(receipt.userName.substring(0, 1))),
                title: Text('${receipt.userName} - ${NumberFormat('#,###').format(receipt.amount)}원'),
                subtitle: Text(DateFormat('yyyy-MM-dd').format(receipt.submittedAt.toDate())),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (receipt.status == ReceiptStatus.pending) ...[
                      TextButton(onPressed: () => _accountingService.approveReceipt(receipt, church: widget.churchId, accountingSection: widget.sectionName, managerId: user.uid, managerName: user.name), child: const Text('승인')),
                      TextButton(onPressed: () => _showRejectionDialog(context, receipt, user.name), child: const Text('반려')),
                    ] else _buildStatusChip(receipt.status),
                    // ✨ [수정] 상태와 관계없이 항상 삭제 버튼 표시
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey),
                      onPressed: () => _confirmDeleteReceipt(context, widget.churchId, receipt.id),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildApprovalLogList() {
    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _approvalLogs.length,
          itemBuilder: (context, index) {
            final log = _approvalLogs[index];
            final isApproved = log.status == ReceiptStatus.approved;
            return Card(
              child: ListTile(
                leading: Icon(isApproved ? Icons.check_circle : Icons.cancel, color: isApproved ? Colors.green : Colors.red),
                title: Text('${log.receiptSubmitterName}님의 증빙 (${NumberFormat('#,###').format(log.receiptAmount)}원)'),
                subtitle: Text('${log.managerName} 님이 ${isApproved ? '승인' : '반려'} 처리'),
                trailing: Text(DateFormat('MM/dd HH:mm').format(log.processedAt.toDate())),
              ),
            );
          },
        ),
        if (_isApprovalLogLoading) const Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()),
        if (_hasMoreApprovalLogs && !_isApprovalLogLoading)
          TextButton(onPressed: () => _loadApprovalLogs(), child: const Text('더 보기')),
      ],
    );
  }

  // ✨ [추가] 제출된 증빙 이미지를 보여주는 다이얼로그
  void _showReceiptImagesDialog(BuildContext context, ReceiptModel receipt) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${receipt.userName}님의 제출 증빙'),
        content: SizedBox(
          width: double.maxFinite,
          child: CarouselSlider.builder(
            itemCount: receipt.fileUrls.length,
            itemBuilder: (context, index, realIndex) {
              return InteractiveViewer(child: Image.network(receipt.fileUrls[index]));
            },
            options: CarouselOptions(
              height: 400,
              enableInfiniteScroll: false,
              viewportFraction: 1.0,
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기'))],
      ),
    );
  }

  // ✨ [수정] 반려 사유를 입력받고, 수정된 서비스 함수를 호출하는 다이얼로그
  void _showRejectionDialog(BuildContext context, ReceiptModel receipt, String managerName) {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
            title: const Text('증빙 반려'),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: '반려 사유를 입력하세요',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.trim().isEmpty ? '반려 사유는 필수입니다.' : null,
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    // 수정된 서비스 함수 호출
                    _accountingService.rejectReceipt(
                      receipt,
                      church: widget.churchId,
                      reason: reasonController.text.trim(),
                      managerName: managerName,
                    );
                    Navigator.pop(context);
                  }
                },
                child: const Text('반려 처리'),
              )
            ],
          ));
  }

void _confirmDeleteLog(BuildContext context, String logId) {
     showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('내역 삭제'),
          content: const Text('이 입출금 내역을 정말로 삭제하시겠습니까?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('삭제'),
              onPressed: () {
                _accountingService.deleteAccountingLog(widget.churchId, widget.sectionName, logId)
                  .then((_) => _loadAccountingLogs(isInitial: true));
                Navigator.pop(context);
              },
            ),
          ],
        ),
      );
  }

  // ✨ [추가] 증빙 삭제 전 확인 다이얼로그
  void _confirmDeleteReceipt(BuildContext context, String churchId, String receiptId) {
     showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('증빙 삭제'),
          content: const Text('이 증빙 제출 내역을 정말로 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('삭제'),
              onPressed: () {
                _accountingService.deleteReceipt(churchId, receiptId);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      );
  }


  // --- 셀 편집 관련 위젯 및 함수 ---
  DataCell _buildEditableCell(String docId, String field, String initialValue, Future<void> Function(String) onSave) {
    return DataCell(
      Text(initialValue),
      showEditIcon: true,
      onTap: () => _showEditDialog(field, initialValue, onSave),
    );
  }

  DataCell _buildTypeCell(AccountingLogModel log) {
    return DataCell(
      DropdownButtonHideUnderline(
        child: DropdownButton<LogType>(
          value: log.type,
          items: const [
            DropdownMenuItem(value: LogType.income, child: Text('수입', style: TextStyle(color: Colors.blue))),
            DropdownMenuItem(value: LogType.expense, child: Text('지출', style: TextStyle(color: Colors.red))),
          ],
          onChanged: (val) {
            if (val != null) {
              _accountingService.updateAccountingLogField(widget.churchId, widget.sectionName, log.id, 'type', val.name);
            }
          },
        ),
      ),
    );
  }

  DataCell _buildDateCell(AccountingLogModel log) {
    return DataCell(
      Text(DateFormat('yyyy-MM-dd').format(log.date.toDate())),
      showEditIcon: true,
      onTap: () async {
        DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: log.date.toDate(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2101),
        );
        if (pickedDate != null) {
          _accountingService.updateAccountingLogField(widget.churchId, widget.sectionName, log.id, 'date', Timestamp.fromDate(pickedDate));
        }
      },
    );
  }

  void _showEditDialog(String field, String initialValue, Future<void> Function(String) onSave) {
    final controller = TextEditingController(text: initialValue);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$field 수정'),
        content: TextFormField(controller: controller, autofocus: true, keyboardType: field == 'amount' ? TextInputType.number : TextInputType.text),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              onSave(controller.text);
              Navigator.of(context).pop();
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _addNewAccountingLog() {
    final user = (context.read<HomeBloc>().state as HomeLoadSuccess).userProfile;
    final newLog = AccountingLogModel(
      id: '',
      householdHead: '새 항목',
      managerId: user.uid,
      managerName: user.name,
      type: LogType.expense,
      amount: 0,
      date: Timestamp.now(),
      item: '미분류',
    );
    _accountingService.addAccountingLog(widget.churchId, widget.sectionName, newLog);
  }
}
