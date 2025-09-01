part of 'attendance_check_bloc.dart';

abstract class AttendanceCheckEvent extends Equatable {
  const AttendanceCheckEvent();

  @override
  List<Object> get props => [];
}

// 최초 데이터 요청 이벤트
class AttendanceDataRequested extends AttendanceCheckEvent {}

// 캘린더의 월이 변경되었을 때 발생하는 이벤트
class AttendanceMonthChanged extends AttendanceCheckEvent {
  final DateTime focusedDay;
  const AttendanceMonthChanged(this.focusedDay);

  @override
  List<Object> get props => [focusedDay];
}

// 캘린더의 날짜를 탭했을 때 발생하는 이벤트
class AttendanceDayTapped extends AttendanceCheckEvent {
  final DateTime day;
  const AttendanceDayTapped(this.day);

  @override
  List<Object> get props => [day];
}

// 교회 선택 드롭다운 값이 변경되었을 때 발생하는 이벤트
class AttendanceChurchChanged extends AttendanceCheckEvent {
  final String church;
  const AttendanceChurchChanged(this.church);

  @override
  List<Object> get props => [church];
}

// ✨ [추가] 멤버 선택 드롭다운 값이 변경되었을 때 발생하는 이벤트
class AttendanceMemberChanged extends AttendanceCheckEvent {
  final String selectedName;

  const AttendanceMemberChanged(this.selectedName);

  @override
  List<Object> get props => [selectedName];
}