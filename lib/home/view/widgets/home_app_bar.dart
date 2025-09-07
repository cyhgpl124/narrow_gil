import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:narrow_gil/home/models/user_profile.dart';

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final UserProfile userProfile;
  final bool isEditing;
  final VoidCallback onSignedOut;
  final VoidCallback onExitEditMode;
  final VoidCallback onResetLayout;
  final VoidCallback onSave;
  final VoidCallback onAttendanceCheck;
  final Color attendanceIconColor;
  final VoidCallback? onLaunchURL;
  final VoidCallback? onLaunchDriveURL;

  // ✨ [추가] 모바일 레이아웃 여부를 확인하기 위한 플래그
  final bool isMobileLayout;

  const HomeAppBar({
    super.key,
    required this.userProfile,
    required this.isEditing,
    required this.onSignedOut,
    required this.onExitEditMode,
    required this.onResetLayout,
    required this.onSave,
    required this.onAttendanceCheck,
    required this.attendanceIconColor,
    this.onLaunchURL,
    this.onLaunchDriveURL,
    // ✨ [추가] 생성자에서 isMobileLayout 값을 받도록 설정
    this.isMobileLayout = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // ✨ [수정] !isMobileLayout이 true일 때만 (즉, 웹일 때만) Drawer 아이콘을 자동으로 표시합니다.
      automaticallyImplyLeading: !isMobileLayout,
      title: isEditing
          ? const Text('레이아웃 편집')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(userProfile.church,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Text(userProfile.name,
                        style:
                            const TextStyle(fontSize: 14, color: Colors.white)),
                    const SizedBox(width: 8),
                    const Icon(Icons.favorite, color: Colors.red, size: 16),
                    const SizedBox(width: 4),
                    Text('${userProfile.heavenlyScore}',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.red)),
                  ],
                ),
              ],
            ),
      actions: isEditing
          ? _buildEditingActions(context)
          : _buildDefaultActions(context),
    );
  }

  // ✨ [추가] 기본 액션 버튼들을 위한 헬퍼 메서드
  List<Widget> _buildDefaultActions(BuildContext context) {
    // 모바일 레이아웃에 따라 아이콘 크기와 패딩을 조절합니다.
    final double iconSize = isMobileLayout ? 22.0 : 24.0;
    final EdgeInsets padding = isMobileLayout
        ? const EdgeInsets.symmetric(horizontal: 4.0)
        : const EdgeInsets.all(8.0);
    final EdgeInsets avatarPadding = isMobileLayout
        ? const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0)
        : const EdgeInsets.all(8.0);

    return [
      IconButton(
        icon: Icon(Icons.check_circle, color: attendanceIconColor),
        iconSize: iconSize,
        padding: padding,
        onPressed: onAttendanceCheck,
        tooltip: '오늘 출석체크',
      ),
      if (onLaunchURL != null)
        IconButton(
          icon: const Icon(Icons.movie_filter_outlined),
          iconSize: iconSize,
          padding: padding,
          onPressed: onLaunchURL,
          tooltip: '줌예식',
        ),
      if (onLaunchDriveURL != null)
        IconButton(
          icon: const Icon(BoxIcons.bx_cloud),
          iconSize: iconSize,
          padding: padding,
          tooltip: 'Google Drive',
          onPressed: onLaunchDriveURL,
        ),
      Padding(
        padding: avatarPadding, // 조절된 패딩 적용
        child: CircleAvatar(
          backgroundImage: userProfile.photoURL != null
              ? NetworkImage(userProfile.photoURL!)
              : null,
          child: userProfile.photoURL == null ? const Icon(Icons.person) : null,
        ),
      ),
      IconButton(
        icon: const Icon(Icons.logout),
        iconSize: iconSize,
        padding: padding,
        tooltip: '로그아웃',
        onPressed: onSignedOut,
      ),
    ];
  }

  // ✨ [추가] 편집 모드 액션 버튼들을 위한 헬퍼 메서드
  List<Widget> _buildEditingActions(BuildContext context) {
    // 모바일에서 텍스트 버튼의 폰트 크기를 조절합니다.
    final double textSize = isMobileLayout ? 14.0 : 16.0;

    return [
      TextButton(
        onPressed: onResetLayout,
        child: Text('초기화', style: TextStyle(color: Colors.red, fontSize: textSize)),
      ),
      TextButton(
        onPressed: onExitEditMode,
        child: Text('나가기', style: TextStyle(color: Colors.white, fontSize: textSize)),
      )
    ];
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}