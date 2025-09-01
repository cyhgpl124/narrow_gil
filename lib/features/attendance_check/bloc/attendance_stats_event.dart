part of 'attendance_stats_bloc.dart';

abstract class AttendanceStatsEvent extends Equatable {
  const AttendanceStatsEvent();
  @override
  List<Object> get props => [];
}

class AttendanceStatsRequested extends AttendanceStatsEvent {
  final String churchName;
  const AttendanceStatsRequested(this.churchName);

  @override
  List<Object> get props => [churchName];
}
