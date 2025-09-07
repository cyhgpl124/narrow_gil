// lib/features/attendance_check/view/attendance_stats_page.dart

import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:narrow_gil/features/attendance_check/bloc/attendance_stats_bloc.dart';
import 'package:narrow_gil/features/attendance_check/models/attendance_status.dart';
import 'package:narrow_gil/features/attendance_check/models/user_attendance.dart';
import 'package:screenshot/screenshot.dart';

// ✨ Correctly importing the platform-agnostic file saver
import 'package:narrow_gil/features/user/services/file_saver.dart';

class AttendanceStatsPage extends StatelessWidget {
  final String churchName;
  final DateTime selectedDate;
  const AttendanceStatsPage({super.key, required this.churchName, required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AttendanceStatsBloc()..add(AttendanceStatsRequested(churchName, selectedDate)),
      child: AttendanceStatsView(churchName: churchName, selectedDate: selectedDate),
    );
  }
}

class AttendanceStatsView extends StatelessWidget {
  final String churchName;
  final DateTime selectedDate;
  const AttendanceStatsView({super.key, required this.churchName, required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    final monthString = DateFormat('yyyy년 M월').format(selectedDate);

    return Scaffold(
          appBar: AppBar(
            title: Text('$monthString $churchName 출석 통계'),
          ),
          body: BlocBuilder<AttendanceStatsBloc, AttendanceStatsState>(
            builder: (context, state) {
              if (state is AttendanceStatsLoadInProgress) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is AttendanceStatsLoadSuccess) {
                return _AttendanceStatsTable(
                    attendanceList: state.attendanceList,
                    churchName: churchName,
                    selectedDate: selectedDate,
                    screenshotController: ScreenshotController(),
                );
              } else if (state is AttendanceStatsLoadFailure) {
                return Center(child: Text('Error: ${state.error}'));
              } else {
                return const Center(child: Text('통계 데이터가 없습니다.'));
              }
            },
          )
    );
  }
}

class _AttendanceStatsTable extends StatelessWidget {
  final List<UserAttendance> attendanceList;
  final String churchName;
  final DateTime selectedDate;
  final ScreenshotController screenshotController;

  const _AttendanceStatsTable(
      {required this.attendanceList,
        required this.churchName,
        required this.selectedDate,
        required this.screenshotController,
      });

  @override
  Widget build(BuildContext context) {
    // <<< ✨ [수정] DateTime.now() 대신 전달받은 selectedDate 사용
    final daysInMonth = DateTime(selectedDate.year, selectedDate.month + 1, 0).day;
    const weekDays = ['월', '화', '수', '목', '금', '토', '일'];

    return Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: Screenshot(
                  controller: screenshotController,
                  // <<< ✨ [완료] 이미지 저장 시 배경색이 포함되도록 Container로 감싸기
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    padding: const EdgeInsets.all(8.0),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.resolveWith<Color?>((states) => Theme.of(context).scaffoldBackgroundColor),
                      columnSpacing: 16.0,
                      horizontalMargin: 16.0,
                      columns: [
                        const DataColumn(label: Text('구역', style: TextStyle(fontWeight: FontWeight.bold))),
                        const DataColumn(label: Text('세례', style: TextStyle(fontWeight: FontWeight.bold))),
                        const DataColumn(label: Text('이름', style: TextStyle(fontWeight: FontWeight.bold))),
                        const DataColumn(label: Text('생년월일', style: TextStyle(fontWeight: FontWeight.bold))),
                        const DataColumn(label: Text('만나이', style: TextStyle(fontWeight: FontWeight.bold))),
                        ...List.generate(
                          daysInMonth,
                              (index) {
                                final day = index + 1;
                                final date = DateTime(selectedDate.year, selectedDate.month, day);
                                final dayOfWeek = weekDays[date.weekday - 1];
                                return DataColumn(
                                  label: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(day.toString(), style: const TextStyle(fontSize: 12)),
                                      Text('($dayOfWeek)', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                                    ],
                                  ),
                                );
                              }
                        ),
                      ],
                      rows: [
                        ...attendanceList.map((userAttendance) =>
                            _buildDataRow(userAttendance, daysInMonth, context)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(onPressed: () => _exportToExcel(context), child: const Text("엑셀 다운로드")),
                ElevatedButton(onPressed: () => _exportToImage(context), child: const Text("이미지 다운로드")),
              ],
            ),
          ),
        ]
    );
  }

  DataRow _buildDataRow(UserAttendance userAttendance, int daysInMonth,
      BuildContext context) {
    final user = userAttendance.user;
    final age = _calculateAge(user.birthdate, selectedDate);
    final isMember = user.church == churchName;

    return DataRow(
      cells: [
        DataCell(Text(userAttendance.district ?? '-')),
        DataCell(Text(userAttendance.baptismNumber?.toString() ?? '-')),
        DataCell(
          Row(
            children: [
              Text(user.name),
              const SizedBox(width: 8),
              if (!isMember)
                const Icon(Icons.star, color: Colors.amber, size: 16),
            ],
          ),
        ),
        DataCell(Text(user.birthdate)),
        DataCell(Text(age > 0 ? age.toString() : '-')),
        ...List.generate(
          daysInMonth,
          (dayIndex) {
            // <<< ✨ [수정] DateTime.now() 대신 전달받은 selectedDate 사용
            final currentDate =
                DateTime.utc(selectedDate.year, selectedDate.month, dayIndex + 1);
            final attendanceStatus =
                userAttendance.attendanceRecords[currentDate] ??
                    AttendanceStatus.none;
            return DataCell(_buildAttendanceIndicator(attendanceStatus));
          },
        ),
      ],
    );
  }

  Widget _buildAttendanceIndicator(AttendanceStatus status) {
    return Center(
      child: switch (status) {
        AttendanceStatus.present => const Icon(
            Icons.circle,
            color: Colors.green,
            size: 16,
          ),
        AttendanceStatus.remote => const Icon(
            Icons.change_history,
            color: Colors.orange,
            size: 16,
          ),
        _ => const Text('-'),
      },
    );
  }

  // <<< ✨ [수정] 나이 계산 함수에 기준 날짜(baseDate)를 받도록 변경
  int _calculateAge(String birthdate, DateTime baseDate) {
    if (birthdate.length != 6) return 0;
    try {
      int year = int.parse(birthdate.substring(0, 2));
      final int month = int.parse(birthdate.substring(2, 4));
      final int day = int.parse(birthdate.substring(4, 6));

      // 2000년대생과 1900년대생 구분
      int currentYearLastTwoDigits = baseDate.year % 100;
      year += (year > currentYearLastTwoDigits) ? 1900 : 2000;

      final birthDate = DateTime(year, month, day);
      // 기준 날짜(baseDate)로 나이 계산
      int age = baseDate.year - birthDate.year;
      if (baseDate.month < birthDate.month ||
          (baseDate.month == birthDate.month && baseDate.day < birthDate.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _exportToExcel(BuildContext context) async {
    try {
      final daysInMonth = DateTime(selectedDate.year, selectedDate.month + 1, 0).day;
      final monthString = DateFormat('yyyy-MM').format(selectedDate);
      final fileName = '${churchName}_${monthString}_attendance.xlsx';

      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sheet1'];

      sheetObject.appendRow([
        TextCellValue('구역'),
        TextCellValue('세례'),
        TextCellValue('이름'),
        TextCellValue('생년월일'),
        TextCellValue('만나이'),
        ...List.generate(daysInMonth, (i) => TextCellValue((i + 1).toString()))
      ]);

      for (var userAttendance in attendanceList) {
        final user = userAttendance.user;
        final age = _calculateAge(user.birthdate, selectedDate);
        final attendanceData = List.generate(daysInMonth, (dayIndex) {
          final currentDate = DateTime.utc(selectedDate.year, selectedDate.month, dayIndex + 1);
          final status = userAttendance.attendanceRecords[currentDate] ?? AttendanceStatus.none;
          return _getAttendanceIndicatorText(status);
        });

        sheetObject.appendRow([
          TextCellValue(userAttendance.district ?? '-'),
          TextCellValue(userAttendance.baptismNumber?.toString() ?? '-'),
          TextCellValue(user.name),
          TextCellValue(user.birthdate),
          TextCellValue(age > 0 ? age.toString() : '-'),
          ...attendanceData.map((e) => TextCellValue(e))
        ]);
      }

      var bytes = excel.save();
      if (bytes == null) {
        throw Exception("Failed to save Excel file.");
      }

      // ✨ [수정] 플랫폼 분기 로직을 삭제하고 saveFile 함수만 호출합니다.
      await saveFile(
        context,
        Uint8List.fromList(bytes),
        fileName,
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('엑셀 다운로드 중 오류 발생: $e')),
      );
    }
  }

  String _getAttendanceIndicatorText(AttendanceStatus status) {
    return switch (status) {
      AttendanceStatus.present => '출석',
      AttendanceStatus.remote => '비대면',
      _ => '-',
    };
  }

  Future<void> _exportToImage(BuildContext context) async {
    try {
      final Uint8List? imageBytes = await screenshotController.capture();
      if (imageBytes == null) {
        throw Exception("Failed to capture image.");
      }

      final monthString = DateFormat('yyyy-MM').format(selectedDate);
      final fileName = '${churchName}_${monthString}_attendance.png';

      // ✨ [수정] 플랫폼 분기 로직을 삭제하고 saveFile 함수만 호출합니다.
      await saveFile(
        context,
        imageBytes,
        fileName,
        mimeType: 'image/png',
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 다운로드 중 오류 발생: $e')),
      );
    }
  }
}