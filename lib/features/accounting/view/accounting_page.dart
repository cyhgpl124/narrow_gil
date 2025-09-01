// lib/features/accounting/view/accounting_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:intl/intl.dart';
import 'package:narrow_gil/features/accounting/models/event_model.dart';
import 'package:narrow_gil/features/accounting/models/receipt_model.dart';
import 'package:narrow_gil/features/accounting/services/accounting_service.dart';
import 'package:narrow_gil/features/accounting/view/accounting_section_page.dart';
import 'package:narrow_gil/features/accounting/view/widgets/add_receipt_dialog.dart';
import 'package:narrow_gil/features/accounting/view/widgets/add_department_dialog.dart';
import 'package:narrow_gil/home/bloc/home_bloc.dart';

class AccountingPage extends StatefulWidget {
  const AccountingPage({super.key});

  @override
  State<AccountingPage> createState() => _AccountingPageState();
}

class _AccountingPageState extends State<AccountingPage> {
  String? _selectedChurch;
  String? _defaultUserDepartment;
  String? _selectedDepartment;
  final AccountingService _accountingService = AccountingService();
  final CarouselSliderController _churchCarouselController =
      CarouselSliderController();
  bool _isDepartmentLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final homeState = context.watch<HomeBloc>().state;
    if (homeState is HomeLoadSuccess) {
      _selectedChurch ??= homeState.userProfile.church;
      if (_isDepartmentLoading) {
        _fetchUserDepartment(
            homeState.userProfile.church, homeState.userProfile.uid);
      }
    }
  }

  Future<void> _fetchUserDepartment(String churchId, String userId) async {
    _isDepartmentLoading = false;
    final department =
        await _accountingService.getUserDepartment(churchId, userId);
    if (mounted) {
      setState(() {
        _defaultUserDepartment = department;
        _selectedDepartment = department;
      });
    }
  }

  /// AccountingSectionPage로 이동하는 공통 함수 (BlocProvider.value 사용)
  void _navigateToSectionPage(BuildContext context,
      {required String sectionName, required String churchId}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<HomeBloc>(), // 현재 Context의 HomeBloc을 전달
          child: AccountingSectionPage(
              sectionName: sectionName, churchId: churchId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final homeState = context.watch<HomeBloc>().state;
    if (homeState is! HomeLoadSuccess) {
      return const Scaffold(body: Center(child: Text('사용자 정보를 불러올 수 없습니다.')));
    }
    final user = homeState.userProfile;
    _selectedChurch ??= user.church;

    return Scaffold(
      appBar: AppBar(
        title: const Text('회계 관리'),
        elevation: 1,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSubmitReceiptButton(context, user),
              const SizedBox(height: 24),
              _buildSectionCard(
                context: context,
                icon: Icons.groups,
                title: '총회',
                churchId: '총회',
                onTap: () => _navigateToSectionPage(context,
                    sectionName: '총회', churchId: '총회'),
                child: _buildDepartmentCarousel(
                    context, _accountingService.getDepartments('총회'), '총회'),
              ),
              const SizedBox(height: 16),
              _buildSectionCard(
                context: context,
                icon: Icons.place,
                title: '지교',
                churchId: _selectedChurch!,
                onTap: null,
                headerWidget: _buildChurchCarousel(user.church),
                child: Column(
                  // 부서와 행사를 세로로 나열하기 위해 Column 사용
                  children: [
                    _buildDepartmentCarousel(
                        context,
                        _accountingService.getDepartments(_selectedChurch!),
                        _selectedChurch!),
                    const Divider(height: 16, indent: 16, endIndent: 16),
                    _buildEventCarousel(context, _selectedChurch!), // 행사 캐러셀 추가
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildMyReceiptsSection(context, user.uid, user.church),
            ],
          ),
        ),
      ),
    );
  }

// --- ▼ [수정] 오늘과 가장 가까운 날짜의 행사에 포커스를 맞추는 로직 추가 ---
  Widget _buildEventCarousel(BuildContext context, String churchId) {
    return StreamBuilder<List<EventModel>>(
      stream: _accountingService.getEvents(churchId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SizedBox(
              height: 38, child: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child:
                  Text('등록된 행사가 없습니다.', style: TextStyle(color: Colors.grey)),
            ),
          );
        }
        final events = snapshot.data!;

        // --- ▼ [로직 추가] 오늘과 가장 가까운 행사 인덱스 찾기 ---
        int closestIndex = 0;
        if (events.isNotEmpty) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          int minDifference = -1;

          for (int i = 0; i < events.length; i++) {
            final eventDate = events[i].date.toDate();
            // 날짜 차이의 절대값을 계산
            final difference = today.difference(eventDate).abs().inDays;

            if (minDifference == -1 || difference < minDifference) {
              minDifference = difference;
              closestIndex = i;
            }
          }
        }
        // --- ▲ [로직 추가] ---

        return CarouselSlider.builder(
          itemCount: events.length,
          itemBuilder: (context, index, realIndex) {
            final event = events[index];
            final formattedDate =
                DateFormat('yyMMdd').format(event.date.toDate());
            final displayText = '$formattedDate${event.title}';

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.0),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  _navigateToSectionPage(context,
                      sectionName: event.title, churchId: churchId);
                },
                child: Text(
                  displayText,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            );
          },
          options: CarouselOptions(
            height: 38,
            viewportFraction: 0.35,
            enableInfiniteScroll: false,
            padEnds: false,
            // [수정] initialPage에 계산된 인덱스 값을 적용
            initialPage: closestIndex,
          ),
        );
      },
    );
  }

  Widget _buildSubmitReceiptButton(BuildContext context, dynamic user) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => showAddReceiptDialog(context,
            userId: user.uid,
            userName: user.name,
            church: user.church,
            district: _defaultUserDepartment),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.receipt_long_rounded, color: Colors.blueAccent),
              const SizedBox(width: 12),
              Text(
                '영수증 / 이체증빙 제출',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String churchId,
    VoidCallback? onTap,
    Widget? headerWidget,
    Widget? child,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            leading: Icon(icon, color: Theme.of(context).primaryColor),
            title: Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            trailing: onTap != null
                ? const Icon(Icons.arrow_forward_ios, size: 16)
                : null,
            onTap: onTap,
          ),
          if (headerWidget != null) ...[
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: headerWidget,
            ),
            const SizedBox(height: 8),
          ],
          if (child != null) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              child: child,
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildChurchCarousel(String userChurch) {
    return FutureBuilder<List<String>>(
      future: _accountingService.getChurchNames(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 45);
        final churches = snapshot.data!;
        if (churches.isEmpty) return const SizedBox.shrink();
        final initialIndex = churches.indexOf(userChurch);

        return CarouselSlider.builder(
          carouselController: _churchCarouselController,
          itemCount: churches.length,
          itemBuilder: (context, index, realIndex) {
            final churchName = churches[index];
            final isSelected = churchName == _selectedChurch;
            return Container(
              width: MediaQuery.of(context).size.width,
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              child: GestureDetector(
                onTap: () => _navigateToSectionPage(context,
                    sectionName: churchName, churchId: churchName),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).primaryColor.withOpacity(0.1)
                        : Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.black54,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                      child: Text(churchName,
                          style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal))),
                ),
              ),
            );
          },
          options: CarouselOptions(
            height: 45,
            viewportFraction: 0.45,
            enlargeCenterPage: false,
            enableInfiniteScroll: false,
            initialPage: initialIndex != -1 ? initialIndex : 0,
            onPageChanged: (index, reason) {
              setState(() {
                _selectedChurch = churches[index];
                _selectedDepartment = (_selectedChurch == userChurch)
                    ? _defaultUserDepartment
                    : null;
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildDepartmentCarousel(
      BuildContext context, Stream<List<String>> stream, String churchId) {
    return StreamBuilder<List<String>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SizedBox(height: 38);
        }
        final departments = snapshot.data ?? [];
        if (departments.isEmpty) {
          return TextButton.icon(
            icon: const Icon(Icons.add, size: 20),
            label: const Text('부서 추가'),
            onPressed: () => showAddDepartmentDialog(context, churchId),
          );
        }
        int initialIndex = departments.indexOf(_defaultUserDepartment ?? '');
        final scrollController = ScrollController(
            initialScrollOffset:
                initialIndex != -1 ? (initialIndex * 100.0) : 0.0);

        return SizedBox(
          height: 38,
          child: ListView.builder(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: departments.length + 1,
            itemBuilder: (context, index) {
              if (index == departments.length) {
                return IconButton(
                  icon: Icon(Icons.add_circle_outline,
                      color: Colors.grey.shade600),
                  tooltip: '부서 추가',
                  onPressed: () => showAddDepartmentDialog(context, churchId),
                );
              }
              final department = departments[index];
              final bool isFocused = department == _selectedDepartment;

              VoidCallback onDepartmentPressed = () {
                setState(() {
                  _selectedDepartment = department;
                });
                _navigateToSectionPage(context,
                    sectionName: '$churchId $department', churchId: churchId);
              };

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: isFocused
                    ? ElevatedButton(
                        onPressed: onDepartmentPressed,
                        child: Text(department),
                        style: ElevatedButton.styleFrom(elevation: 1))
                    : OutlinedButton(
                        onPressed: onDepartmentPressed,
                        child: Text(department)),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMyReceiptsSection(
      BuildContext context, String userId, String churchId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
          child: Text(
            '내 증빙 제출 현황',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: StreamBuilder<List<ReceiptModel>>(
            stream: _accountingService.getUserReceipts(userId, churchId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator()));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SizedBox(
                  height: 100,
                  child: Center(
                      child: Text('제출한 내역이 없습니다.',
                          style: TextStyle(color: Colors.grey))),
                );
              }
              final receipts = snapshot.data!;
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: receipts.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (context, index) {
                  final receipt = receipts[index];
                  final formattedDate = DateFormat('yyyy-MM-dd')
                      .format(receipt.submittedAt.toDate());
                  final formattedAmount =
                      NumberFormat('#,###원').format(receipt.amount);
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    title: Text('${receipt.accountingArea}: $formattedAmount', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(formattedDate),
                    // ✨ [수정] 반려된 항목을 탭하면 사유를 보여주는 기능을 추가합니다.
                    onTap: receipt.status == ReceiptStatus.rejected
                        ? () => _showRejectionReasonDialog(context, receipt.rejectionReason)
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildStatusChip(receipt.status),
                        if (receipt.status != ReceiptStatus.pending)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.grey),
                            tooltip: '제출 내역 삭제',
                            onPressed: () => _confirmDeleteReceipt(context, churchId, receipt.id),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
  // ✨ [추가] 반려 사유를 보여주는 다이얼로그
  void _showRejectionReasonDialog(BuildContext context, String? reason) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('반려 사유'),
        content: Text(reason ?? '반려 사유가 기재되지 않았습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
// ✨ [추가] 증빙 삭제 확인 다이얼로그 (section_page의 것과 동일한 로직)
  void _confirmDeleteReceipt(
      BuildContext context, String churchId, String receiptId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('제출 내역 삭제'),
        content: const Text('이 제출 내역을 정말로 삭제하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('취소')),
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
}
