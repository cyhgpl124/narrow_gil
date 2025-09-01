part of 'attendance_check_bloc.dart';

enum BlocStatus { initial, loading, success, failure }

class AttendanceCheckState extends Equatable {
  final BlocStatus status;
  final UserProfile? userProfile;
  final String selectedChurch;
  final List<String> churchList;
  final DateTime focusedDay;
  final Map<DateTime, AttendanceStatus> attendanceRecords;
  final String? error;

  // 대리 출석 체크 관련 상태
  final bool canCheckForOthers;
  final List<String> memberList;
  final String selectedMemberName;
  final Map<String, String> allMembers; // key: 이름, value: UID

  const AttendanceCheckState({
    this.status = BlocStatus.initial,
    this.userProfile,
    this.selectedChurch = '',
    this.churchList = const [],
    required this.focusedDay,
    this.attendanceRecords = const {},
    this.error,
    this.canCheckForOthers = false,
    this.memberList = const [],
    this.selectedMemberName = '',
    this.allMembers = const {},
  });

  // 현재 월의 출석일수 계산
  int get presentCount =>
      attendanceRecords.values.where((s) => s == AttendanceStatus.present).length;
  // 현재 월의 비대면 출석일수 계산
  int get remoteCount =>
      attendanceRecords.values.where((s) => s == AttendanceStatus.remote).length;
  // 현재 월의 미출석일수 계산
  int get absentCount {
    final daysInMonth = DateUtils.getDaysInMonth(focusedDay.year, focusedDay.month);
    // 오늘 이후의 날짜는 미출석일수에서 제외
    final today = DateTime.now();
    int futureDays = 0;
    if (focusedDay.year == today.year && focusedDay.month == today.month) {
        futureDays = daysInMonth - today.day;
    }
    final totalDays = daysInMonth - futureDays;
    return totalDays - presentCount - remoteCount;
  }


  AttendanceCheckState copyWith({
    BlocStatus? status,
    UserProfile? userProfile,
    String? selectedChurch,
    List<String>? churchList,
    DateTime? focusedDay,
    Map<DateTime, AttendanceStatus>? attendanceRecords,
    String? error,
    bool? canCheckForOthers,
    List<String>? memberList,
    String? selectedMemberName,
    Map<String, String>? allMembers,
  }) {
    return AttendanceCheckState(
      status: status ?? this.status,
      userProfile: userProfile ?? this.userProfile,
      selectedChurch: selectedChurch ?? this.selectedChurch,
      churchList: churchList ?? this.churchList,
      focusedDay: focusedDay ?? this.focusedDay,
      attendanceRecords: attendanceRecords ?? this.attendanceRecords,
      error: error ?? this.error,
      canCheckForOthers: canCheckForOthers ?? this.canCheckForOthers,
      memberList: memberList ?? this.memberList,
      selectedMemberName: selectedMemberName ?? this.selectedMemberName,
      allMembers: allMembers ?? this.allMembers,
    );
  }

  @override
  List<Object?> get props => [
        status,
        userProfile,
        selectedChurch,
        churchList,
        focusedDay,
        attendanceRecords,
        error,
        canCheckForOthers,
        memberList,
        selectedMemberName,
        allMembers,
      ];
}