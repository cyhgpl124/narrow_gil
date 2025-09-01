part of 'attendance_stats_bloc.dart';

abstract class AttendanceStatsState extends Equatable {
  const AttendanceStatsState();

  @override
  List<Object> get props => [];
}

class AttendanceStatsInitial extends AttendanceStatsState {}

class AttendanceStatsLoadInProgress extends AttendanceStatsState {}

class AttendanceStatsLoadSuccess extends AttendanceStatsState {
  final List<UserAttendance> attendanceList;
  const AttendanceStatsLoadSuccess(this.attendanceList);

  @override
  List<Object> get props => [attendanceList];
}

class AttendanceStatsLoadFailure extends AttendanceStatsState {
  final String error;
  const AttendanceStatsLoadFailure(this.error);
  @override
  List<Object> get props => [error];
}
