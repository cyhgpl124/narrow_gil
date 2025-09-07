part of 'attendance_stats_bloc.dart';

abstract class AttendanceStatsEvent extends Equatable {
  const AttendanceStatsEvent();
  @override
  List<Object> get props => [];
}

class AttendanceStatsRequested extends AttendanceStatsEvent {
  final String churchName;
  // <<< ✨ [추가] 선택된 월 정보를 담을 필드
  final DateTime selectedDate;

  // <<< ✨ [수정] 생성자에 selectedDate 추가
  const AttendanceStatsRequested(this.churchName, this.selectedDate);

  @override
  // <<< ✨ [수정] props에 selectedDate 추가
  List<Object> get props => [churchName, selectedDate];
}
