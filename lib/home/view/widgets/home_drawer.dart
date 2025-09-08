import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:narrow_gil/features/accounting/view/accounting_page.dart';
import 'package:narrow_gil/features/announcements/view/announcements_page.dart';
import 'package:narrow_gil/features/attendance_check/view/attendance_check_page.dart';
import 'package:narrow_gil/features/bible/view/bible_book_list_page.dart';
import 'package:narrow_gil/features/events/view/events_list_page.dart';
import 'package:narrow_gil/features/forum/view/forum_page.dart';
import 'package:narrow_gil/features/gallery/view/gallery_page.dart';
import 'package:narrow_gil/features/member_management/view/member_management_page.dart';
import 'package:narrow_gil/features/my_page/view/my_page.dart';
import 'package:narrow_gil/features/new_life/view/new_life_page.dart';
import 'package:narrow_gil/features/question/view/question_list_page.dart';
import 'package:narrow_gil/features/schedule/view/schedule_page.dart';
import 'package:narrow_gil/home/bloc/home_bloc.dart';
import 'package:narrow_gil/home/models/user_profile.dart';

class HomeDrawer extends StatelessWidget {
  final UserProfile userProfile;

  const HomeDrawer({super.key, required this.userProfile});

  // ✨ [추가] 페이지 이동 로직을 처리하는 헬퍼 함수
  // 이 함수는 BlocProvider.value를 사용하여 HomeBloc을 자식 위젯에 안전하게 전달합니다.
  void _navigateToPage(BuildContext context, Widget page) {
    Navigator.pop(context); // Drawer를 먼저 닫습니다.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: BlocProvider.of<HomeBloc>(context),
          child: page,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✨ [추가] 관리자 권한 확인
    final homeState = context.watch<HomeBloc>().state;
    bool isAdmin = false;
    if (homeState is HomeLoadSuccess) {
      const adminRoles = ['목회자', '서기', '개발자'];
      isAdmin = adminRoles.contains(homeState.userRole);
    }

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(
              userProfile.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(userProfile.email),
            currentAccountPicture: CircleAvatar(
              backgroundImage: userProfile.photoURL != null
                  ? NetworkImage(userProfile.photoURL!)
                  : null,
              child: userProfile.photoURL == null
                  ? const Icon(Icons.person, size: 40)
                  : null,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('홈'),
            onTap: () => Navigator.pop(context),
          ),
          const Divider(),
          // --- ▼ [수정] 모든 메뉴 항목이 _navigateToPage 함수를 사용하도록 변경 ---
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('마이페이지'),
            onTap: () => _navigateToPage(context, const MyPage()),
          ),
          ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: const Text('출석체크'),
            onTap: () => _navigateToPage(context, const AttendanceCheckPage()),
          ),
          ListTile(
            leading: const Icon(Icons.lightbulb_outline),
            title: const Text('신생활'),
            onTap: () => _navigateToPage(context, const NewLifePage()),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('밀알스타그램'),
            onTap: () => _navigateToPage(context, const GalleryPage()),
          ),
          ListTile(
            leading: const Icon(Icons.forum_outlined),
            title: const Text('제직회의'),
            onTap: () => _navigateToPage(context, const ForumPage()),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today_outlined),
            title: const Text('일정'),
            onTap: () => _navigateToPage(context, const SchedulePage()),
          ),
          ListTile(
            leading: const Icon(Icons.campaign_outlined),
            title: const Text('공지'),
            onTap: () => _navigateToPage(context, const AnnouncementsPage()),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('말씀필사'),
            onTap: () => _navigateToPage(context, const BibleBookListPage()),
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('회계'),
            onTap: () => _navigateToPage(context, const AccountingPage()),
          ),
          ListTile(
            leading: const Icon(Icons.celebration_outlined),
            title: const Text('행사'),
            onTap: () => _navigateToPage(context, const EventsListPage()),
          ),
          // --- ▼ [추가] '글' 메뉴 항목 ---
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('자유게시판'),
            onTap: () => _navigateToPage(context, const QuestionListPage()),
          ),
          // --- ▲ [추가] ---
          // --- ▼ [수정] 관리자일 경우 '교인 관리' 메뉴를 일관된 방식으로 표시 ---
          if (isAdmin)
            ListTile(
              leading: const Icon(Icons.manage_accounts_outlined),
              title: const Text('교인 관리'),
              onTap: () =>
                  _navigateToPage(context, const MemberManagementPage()),
            ),
          // --- ▲ [수정] ---
        ],
      ),
    );
  }
}
