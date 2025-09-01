import 'package:equatable/equatable.dart';
import 'package:narrow_gil/features/attendance_check/models/attendance_status.dart';
import 'package:narrow_gil/home/models/user_profile.dart';

class UserAttendance extends Equatable {
  final UserProfile user;
  final AttendanceStatus status;
  final Map<DateTime, AttendanceStatus> attendanceRecords;
  final String? district;
  final String? baptismInfo;
  final int? baptismNumber;

  const UserAttendance({
    required this.user,
    this.status = AttendanceStatus.none,
    this.attendanceRecords = const {},
    this.district,
    this.baptismInfo,
    this.baptismNumber,
  });

  UserAttendance copyWith({
    UserProfile? user,
    AttendanceStatus? status,
    Map<DateTime, AttendanceStatus>? attendanceRecords,
    String? district,
    String? baptismInfo,
    int? baptismNumber,
  }) {
    return UserAttendance(
      user: user ?? this.user,
      status: status ?? this.status,
      attendanceRecords: attendanceRecords ?? this.attendanceRecords,
      district: district ?? this.district,
      baptismInfo: baptismInfo ?? this.baptismInfo,
      baptismNumber: baptismNumber ?? this.baptismNumber,
    );
  }

  @override
  List<Object?> get props =>
      [user, status, attendanceRecords, district, baptismInfo, baptismNumber];
}
