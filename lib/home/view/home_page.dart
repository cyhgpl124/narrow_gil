import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:narrow_gil/features/accounting/view/accounting_page.dart';
import 'package:narrow_gil/features/attendance_check/view/attendance_check_page.dart';
import 'package:narrow_gil/features/bible/view/bible_book_list_page.dart';
import 'package:narrow_gil/features/events/view/events_list_page.dart';
import 'package:narrow_gil/features/question/view/question_list_page.dart';
import 'package:narrow_gil/features/question/view/question_page.dart';
import 'package:narrow_gil/home/bloc/home_bloc.dart';
import 'package:narrow_gil/home/models/bento_item.dart';
import 'package:narrow_gil/home/models/notice_model.dart';
import 'package:narrow_gil/home/models/user_profile.dart';
import 'package:narrow_gil/home/view/widgets/add_edit_notice_dialog.dart';
import 'package:narrow_gil/home/view/widgets/home_app_bar.dart';
import 'package:narrow_gil/home/view/widgets/home_drawer.dart';
import 'package:narrow_gil/features/my_page/view/my_page.dart';
import 'package:narrow_gil/features/new_life/view/new_life_page.dart';
import 'package:narrow_gil/features/gallery/view/gallery_page.dart';
import 'package:narrow_gil/features/forum/view/forum_page.dart';
import 'package:narrow_gil/features/schedule/view/schedule_page.dart';
import 'package:narrow_gil/features/announcements/view/announcements_page.dart';
import 'package:narrow_gil/features/attendance_check/models/attendance_status.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:narrow_gil/home/view/widgets/notice_details_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui'; // ✨ [추가] TextDirection 오류 해결을 위한 import


// ✨ [추가] 교인 관리 페이지 import
import 'package:narrow_gil/features/member_management/view/member_management_page.dart';

class HomePage extends StatelessWidget {
  // ✨ 이 부분은 기존과 완전히 동일합니다.
  final UserProfile userProfile;
  const HomePage({super.key, required this.userProfile});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          HomeBloc(userProfile: userProfile)..add(HomeDataRequested()),
      child: const HomeView(),
    );
  }
}

class HomeView extends StatefulWidget {
  // ✨ 이 부분은 기존과 완전히 동일합니다.
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  // ✨ 기존 변수들은 그대로 유지됩니다.
  AttendanceStatus _todayAttendanceStatus = AttendanceStatus.none;

  @override
  void initState() {
    super.initState();
    _loadTodaysAttendance();
  }

  Future<void> _loadTodaysAttendance() async {
    if (!mounted) return;
    final homeState = context.read<HomeBloc>().state;
    if (homeState is HomeLoadSuccess) {
      final userProfile = homeState.userProfile;
      final firestore = FirebaseFirestore.instance;
      final docId = DateFormat('yyyy-MM').format(DateTime.now());
      final dayField = 'd${DateTime.now().day}';

      final attendanceDocRef = firestore
          .collection('churches')
          .doc(userProfile.church)
          .collection('attendance')
          .doc(docId);

      try {
        final doc = await attendanceDocRef.get();
        AttendanceStatus status = AttendanceStatus.none;

        if (doc.exists && doc.data() != null) {
          final Map<String, dynamic> monthData = doc.data()!;
          if (monthData.containsKey(userProfile.uid) &&
              monthData[userProfile.uid] is Map) {
            final Map<String, dynamic> userMonthlyData =
                monthData[userProfile.uid];
            if (userMonthlyData.containsKey(dayField)) {
              // BLoC의 데이터 저장 방식에 맞춰 수정
              if (userMonthlyData[dayField] is String) {
                status =
                    (userMonthlyData[dayField] as String).toAttendanceStatus();
              } else if (userMonthlyData[dayField] is Map &&
                  userMonthlyData[dayField]['status'] is String) {
                status = (userMonthlyData[dayField]['status'] as String)
                    .toAttendanceStatus();
              }
            }
          }
        }

        if (mounted) {
          setState(() {
            _todayAttendanceStatus = status;
          });
        }
      } catch (e) {
        debugPrint("❌ 출석 정보 로딩 중 오류 발생: $e");
        if (mounted) {
          setState(() {
            _todayAttendanceStatus = AttendanceStatus.none;
          });
        }
      }
    }
  }

  Future<void> _handleAttendanceCheck() async {
    final homeState = context.read<HomeBloc>().state;
    if (homeState is! HomeLoadSuccess) return;

    final userProfile = homeState.userProfile;
    final firestore = FirebaseFirestore.instance;
    final docId = DateFormat('yyyy-MM').format(DateTime.now());
    final dayField = 'd${DateTime.now().day}';

    final attendanceDocRef = firestore
        .collection('churches')
        .doc(userProfile.church)
        .collection('attendance')
        .doc(docId);

    final currentStatus = _todayAttendanceStatus;
    AttendanceStatus nextStatus;
    String message;

    switch (currentStatus) {
      case AttendanceStatus.none:
        nextStatus = AttendanceStatus.present;
        message = '✅ 출석 처리되었습니다.';
        break;
      case AttendanceStatus.present:
        nextStatus = AttendanceStatus.remote;
        message = '💻 비대면 출석으로 변경되었습니다.';
        break;
      case AttendanceStatus.remote:
        nextStatus = AttendanceStatus.none;
        message = '❌ 미출석으로 변경되었습니다.';
        break;
    }

    final bool shouldIncrementScore = currentStatus == AttendanceStatus.none &&
        (nextStatus == AttendanceStatus.present ||
            nextStatus == AttendanceStatus.remote);

    final bool shouldDecrementScore =
        (currentStatus == AttendanceStatus.present ||
                currentStatus == AttendanceStatus.remote) &&
            nextStatus == AttendanceStatus.none;

    try {
      await attendanceDocRef.set({
        userProfile.uid: {dayField: nextStatus.value},
      });

      if (shouldIncrementScore || shouldDecrementScore) {
        final phoneNumber = userProfile.phoneNumber;
        if (phoneNumber != null && phoneNumber.isNotEmpty) {
          final approvedMemberQuery = await firestore
              .collection('approved_members')
              .doc(userProfile.church)
              .collection('members')
              .where('phoneNumber', isEqualTo: phoneNumber)
              .limit(1)
              .get();

          if (approvedMemberQuery.docs.isNotEmpty) {
            final memberDocRef = approvedMemberQuery.docs.first.reference;
            final scoreChange = shouldIncrementScore ? 1 : -1;
            await memberDocRef
                .update({'skyScore': FieldValue.increment(scoreChange)});
            context.read<HomeBloc>().add(HomeProfileRefreshed());
          }
        }
      }

      setState(() {
        _todayAttendanceStatus = nextStatus;
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('출석체크 중 오류: $e')));
      }
    }
  }

  Color _getAttendanceIconColor() {
    switch (_todayAttendanceStatus) {
      case AttendanceStatus.present:
        return Colors.green;
      case AttendanceStatus.remote:
        return Colors.blue;
      case AttendanceStatus.none:
        return Colors.grey;
    }
  }

  // ✨ [수정] _launchURL 함수를 범용적으로 사용할 수 있도록 개선합니다.
  // 어떤 URL이든 처리할 수 있고, 링크가 비어있는 경우도 안전하게 처리합니다.
  Future<void> _launchURL(String? urlString) async {
    if (urlString == null || urlString.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('링크가 제공되지 않았습니다.')),
        );
      }
      return;
    }

    final Uri? url = Uri.tryParse(urlString);
    if (url == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('잘못된 형식의 링크입니다: $urlString')),
        );
      }
      return;
    }

    // 외부 앱(줌, 브라우저 등)에서 링크를 열도록 설정
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('링크를 열 수 없습니다: $urlString')));
      }
    }
  }

  // --- ▼ [수정] 공지사항 관련 위젯 및 함수 ---
  Widget _buildNoticeSection(HomeLoadSuccess state) {
    final bool canEdit = state.userRole != '성민';
    final notices = state.notices;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (notices.isEmpty)
          // 공지가 없을 때도 '+' 버튼을 표시하기 위한 로직
          canEdit
          ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("등록된 공지가 없습니다."),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => showAddEditNoticeDialog(context),
                  tooltip: '새 공지 등록',
                ),
              ],
            ),
          )
          : const Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: Center(child: Text("등록된 공지가 없습니다.")),
          )
        else
          // ✨ [수정] asMap().entries.map을 사용하여 인덱스 접근
          ...notices.asMap().entries.map((entry) {
            int idx = entry.key;
            Notice notice = entry.value;
            return _buildNoticeItem(
              context,
              notice,
              canEdit,
              // ✨ [수G정] 첫 번째 아이템인지 여부와 공지 개수 제한을 전달
              isFirst: idx == 0,
              canAdd: notices.length < 3,
            );
          }),
      ],
    );
  }

  Widget _buildNoticeItem(
    BuildContext context,
    Notice notice,
    bool canEdit, {
    required bool isFirst,
    required bool canAdd,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    notice.content,
                    textAlign: TextAlign.center, // ✨ [수정] 텍스트 가운데 정렬
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (canEdit)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ✨ [수정] 첫 번째 아이템이고, 추가 가능할 때만 '+' 버튼 표시
                      if (isFirst && canAdd)
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          onPressed: () => showAddEditNoticeDialog(context),
                          tooltip: '새 공지 등록',
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () =>
                            showAddEditNoticeDialog(context, notice: notice),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        onPressed: () => _confirmDeleteNotice(context, notice),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _buildDetailsRow(context, notice),
          ],
        ),
      ),
    );
  }


  Widget _buildDetailsRow(BuildContext context, Notice notice) {
    // ✨ [수정] TextPainter를 사용하기 위해 StatefulWidget으로 변경할 필요 없이,
    // LayoutBuilder를 사용하여 context와 제약조건을 가져옵니다.
    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: notice.content, style: Theme.of(context).textTheme.bodyMedium),
          maxLines: 2,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth);

        final bool isOverflowing = textPainter.didExceedMaxLines;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${notice.author} · ${DateFormat('yy.MM.dd').format(notice.createdAt.toDate())}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (isOverflowing)
              TextButton(
                child: const Text('더보기'),
                onPressed: () => showNoticeDetailsDialog(context, notice),
              ),
          ],
        );
      },
    );
  }


  void _confirmDeleteNotice(BuildContext context, Notice notice) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('공지 삭제'),
        content: const Text('이 공지를 정말 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              context.read<HomeBloc>().add(HomeNoticeDeleted(notice.id));
              Navigator.of(dialogContext).pop();
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  // --- ▲ [추가] ---


  @override
  Widget build(BuildContext context) {
    return BlocListener<HomeBloc, HomeState>(
      listener: (context, state) {
        if (state is HomeLoadSuccess) {
          _loadTodaysAttendance();
        }
      },
      child: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          if (state is HomeLoadInProgress || state is HomeInitial) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (state is HomeLoadFailure) {
            return Scaffold(body: Center(child: Text('오류: ${state.error}')));
          }

          // ✨ [추가] '권한 없음' 상태일 때 전용 화면을 표시합니다.
          if (state is HomeLoadNoPermission) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('좁은길 생명의길'),
                actions: [
                  // 로그아웃 버튼은 남겨둡니다.
                  IconButton(
                    icon: const Icon(Icons.logout),
                    tooltip: '로그아웃',
                    onPressed: () =>
                        context.read<HomeBloc>().add(HomeSignedOut()),
                  ),
                ],
              ),
              body: const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    '접근권한이 삭제되었습니다. 관리자에게 연락주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            );
          }

          if (state is HomeLoadSuccess) {
            final user = state.userProfile;

            // --- ▼ [추가] BentoGrid의 높이를 동적으로 계산 ---
            final screenWidth = MediaQuery.of(context).size.width;
            const double horizontalGap = 0.005;
            const double verticalGapRatio = 0.005; // 너비에 대한 비율로 계산
            const int columnCount = 2;
            const double totalHorizontalGap = horizontalGap * (columnCount + 1);

            final itemWidthRelative = (1.0 - totalHorizontalGap) / columnCount;
            final itemWidthPx = itemWidthRelative * screenWidth;
            final itemHeightPx = itemWidthPx *0.12;

            final int rowCount = (state.bentoItems.length / columnCount).ceil();
            final verticalGapPx = verticalGapRatio * screenWidth;
            final gridHeight = (rowCount * itemHeightPx) + ((rowCount + 1) * verticalGapPx);
            // --- ▲ [추가] ---

            return Scaffold(
              appBar: HomeAppBar(
                userProfile: user,
                isEditing: state.isEditing,
                onSignedOut: () =>
                    context.read<HomeBloc>().add(HomeSignedOut()),
                onSave: () {
                  showDialog(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                            title: const Text('레이아웃 저장'),
                            content: const Text('변경하신 레이아웃을 저장하시겠습니까?'),
                            actions: <Widget>[
                              TextButton(
                                  child: const Text('취소'),
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop()),
                              TextButton(
                                  child: const Text('저장'),
                                  onPressed: () {
                                    context
                                        .read<HomeBloc>()
                                        .add(HomeLayoutSaved());
                                    Navigator.of(dialogContext).pop();
                                  }),
                            ],
                          ));
                },
                onExitEditMode: () {
                  showDialog(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                            title: const Text('편집 종료'),
                            content: const Text('변경사항을 저장하시겠습니까?'),
                            actions: <Widget>[
                              TextButton(
                                  child: const Text('저장 안함',
                                      style: TextStyle(color: Colors.red)),
                                  onPressed: () {
                                    context
                                        .read<HomeBloc>()
                                        .add(HomeEditCancelled());
                                    Navigator.of(dialogContext).pop();
                                  }),
                              TextButton(
                                  child: const Text('취소'),
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop()),
                              TextButton(
                                  child: const Text('저장'),
                                  onPressed: () {
                                    context
                                        .read<HomeBloc>()
                                        .add(HomeLayoutSaved());
                                    Navigator.of(dialogContext).pop();
                                  }),
                            ],
                          ));
                },
                onResetLayout: () =>
                    context.read<HomeBloc>().add(HomeLayoutResetRequested()),
                onAttendanceCheck: _handleAttendanceCheck,
                attendanceIconColor: _getAttendanceIconColor(),
                // ✨ [수정] zoomLink를 열도록 하고, 안전하게 nullable(?) 처리합니다.
                onLaunchURL: () => _launchURL(state.churchInfo?.zoomLink),
                // ✨ [추가] Google Drive 아이콘 클릭 시 driveLink를 열도록 콜백을 추가합니다.
                onLaunchDriveURL: () => _launchURL(state.churchInfo?.driveLink),
              ),
              // ✨ role이 있는 사용자에게만 Drawer를 표시합니다.
              drawer: HomeDrawer(userProfile: user),

             body: SingleChildScrollView(
                child: Column(
                  children: [
                    if (user.phrases.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Text(
                          '“${user.phrases.last}”',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontStyle: FontStyle.normal,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),

                    _buildNoticeSection(state),

                    // --- ▼ [수정] Expanded를 SizedBox로 변경하고 계산된 높이 적용 ---
                    SizedBox(
                      height: gridHeight,
                      child: BentoGrid(
                          items: state.bentoItems, isEditing: state.isEditing),
                    ),
                    // --- ▲ [수정] ---
                  ],
                ),
              ),
              // --- ▲ [수정] ---
            );
          }
          return const Scaffold(body: Center(child: Text('알 수 없는 상태')));
        },
      ),
    );
  }
}

class BentoGrid extends StatelessWidget {
  final List<BentoItem> items;
  final bool isEditing;
  const BentoGrid({super.key, required this.items, required this.isEditing});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return DragTarget<BentoItem>(
          onWillAcceptWithDetails: (data) => isEditing,
          onAcceptWithDetails: (details) {
            final item = details.data;
            final newX = details.offset.dx / constraints.maxWidth;
            final newY = details.offset.dy / constraints.maxHeight;
            final clampedX = newX.clamp(0.0, 1.0 - item.width);
            final clampedY = newY.clamp(0.0, 1.0 - item.height);
            final updatedItem = item.copyWith(x: clampedX, y: clampedY);
            context.read<HomeBloc>().add(HomeBentoItemUpdated(updatedItem));
          },
          builder: (context, candidateData, rejectedData) {
            return Stack(
              children: items.map((item) {
                return Positioned(
                  left: item.x * constraints.maxWidth,
                  top: item.y * constraints.maxHeight,
                  width: item.width * constraints.maxWidth,
                  height: item.height * constraints.maxHeight,
                  child: BentoItemCard(item: item, isEditing: isEditing),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}

class BentoItemCard extends StatelessWidget {
  final BentoItem item;
  final bool isEditing;
  const BentoItemCard({super.key, required this.item, required this.isEditing});

  void _navigateToFeature(BuildContext context, String route) {
    Widget page;
    switch (route) {
      case '/attendance_check':
        page = const AttendanceCheckPage();
        break;
      case '/my_page':
        page = const MyPage();
        break;
      case '/new_life':
        page = const NewLifePage();
        break;
      case '/gallery':
        page = const GalleryPage();
        break;
      case '/forum':
        page = const ForumPage();
        break;
      case '/schedule':
        page = const SchedulePage();
        break;
      case '/announcements':
        page = const AnnouncementsPage();
        break;
      case '/bible':
        page = const BibleBookListPage();
        break;
      case '/accounting':
        page = const AccountingPage();
        break;
      case '/events':
        // TODO: 행사 페이지 생성 후 연결
        page = const EventsListPage();
        break;
      case '/questions':
        // TODO: 질문 페이지 생성 후 연결
        page = const QuestionListPage();
        break;
      // ✨ 교인 관리 페이지로 이동하는 case 추가
      case '/member_management':
        page = const MemberManagementPage();
        break;
      default:
        debugPrint("Navigate to an undefined route: $route");
        return;
    }
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: BlocProvider.of<HomeBloc>(context),
          child: page,
        ),
      ),
    )
        .then((_) {
      context.read<HomeBloc>().add(HomeProfileRefreshed());
    });
  }

  @override
  Widget build(BuildContext context) {
    final cardWidget = Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isEditing ? null : () => _navigateToFeature(context, item.route),
        onLongPress: () => context.read<HomeBloc>().add(HomeEditModeToggled()),
        child: Center(
            child: Text(item.title,
                style: Theme.of(context).textTheme.titleMedium)),
      ),
    );

    if (isEditing) {
      return LayoutBuilder(builder: (context, constraints) {
        return Draggable<BentoItem>(
          data: item,
          feedback: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Material(
                  elevation: 4.0,
                  color: Colors.transparent,
                  child: cardWidget)),
          childWhenDragging: Opacity(opacity: 0.4, child: cardWidget),
          child: cardWidget,
        );
      });
    } else {
      return cardWidget;
    }
  }
}
