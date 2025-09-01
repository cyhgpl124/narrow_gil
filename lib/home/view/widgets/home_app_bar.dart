import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:narrow_gil/home/models/user_profile.dart';

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  // ✨ 기존 변수들은 그대로 유지됩니다.
  final UserProfile userProfile;
  final bool isEditing;
  final VoidCallback onSignedOut;
  final VoidCallback onExitEditMode;
  final VoidCallback onResetLayout;
  final VoidCallback onSave;

  // ✨ [1/2 추가] HomePage에서 전달받을 새로운 변수들을 선언합니다.
  final VoidCallback onAttendanceCheck;
  final Color attendanceIconColor;
  final VoidCallback? onLaunchURL;
  final VoidCallback? onLaunchDriveURL; // ✨ [추가] Drive 링크를 위한 콜백


  const HomeAppBar({
    super.key,
    required this.userProfile,
    required this.isEditing,
    required this.onSignedOut,
    required this.onExitEditMode,
    required this.onResetLayout,
    required this.onSave,

    // ✨ [2/2 추가] 생성자에 새로운 변수들을 추가합니다.
    required this.onAttendanceCheck,
    required this.attendanceIconColor,
    this.onLaunchURL,
    this.onLaunchDriveURL, // ✨ [추가] 생성자에 추가

  });

  @override
  Widget build(BuildContext context) {
    // ✨ AppBar의 기본 구조와 title 부분은 기존과 완전히 동일합니다.
    return AppBar(
      title: isEditing
          ? const Text('레이아웃 편집')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(userProfile.church, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Text(userProfile.name, style: const TextStyle(fontSize: 14, color: Colors.white)),
                    const SizedBox(width: 8),
                    const Icon(Icons.favorite, color: Colors.red, size: 16),
                    const SizedBox(width: 4),
                    Text('${userProfile.heavenlyScore}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red)),
                  ],
                ),
              ],
            ),
      // ✨ actions 부분만 수정됩니다.
      actions: isEditing
          ? [ // 편집 모드일 때는 기존과 동일
              TextButton(
                onPressed: onResetLayout,
                child: const Text('초기화', style: TextStyle(color: Colors.red, fontSize: 16)),
              ),
              TextButton(
                onPressed: onExitEditMode,
                child: const Text('나가기', style: TextStyle(color: Colors.black54, fontSize: 16)),
              )
            ]
          : [ // 기본 모드일 때 새로운 아이콘들을 추가합니다.
              // 1. 출석체크 버튼
              IconButton(
                icon: Icon(Icons.check_circle, color: attendanceIconColor),
                onPressed: onAttendanceCheck,
                tooltip: '오늘 출석체크',
              ),
              // 2. 특정 링크 이동 버튼
              if (onLaunchURL != null)
                IconButton(
                  icon: const Icon(Icons.movie_filter_outlined),
                  onPressed: onLaunchURL,
                  tooltip: '줌예식',
                ),
              // ✨ [추가] Google Drive 아이콘 버튼
              if (onLaunchDriveURL != null)
                IconButton(
                  icon: const Icon(BoxIcons.bx_cloud), // ✨ 수정된 코드
                  tooltip: 'Google Drive',
                  onPressed: onLaunchDriveURL,
                ),
              // 3. 기존 프로필 사진 (그대로 유지)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundImage: userProfile.photoURL != null ? NetworkImage(userProfile.photoURL!) : null,
                  child: userProfile.photoURL == null ? const Icon(Icons.person) : null,
                ),
              ),

              // 4. 기존 로그아웃 버튼 (그대로 유지)
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: '로그아웃',
                onPressed: onSignedOut,
              ),
            ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}