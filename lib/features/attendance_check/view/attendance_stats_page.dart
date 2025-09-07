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
  const AttendanceStatsPage({super.key, required this.churchName});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AttendanceStatsBloc()..add(AttendanceStatsRequested(churchName)),
      child: AttendanceStatsView(churchName: churchName),
    );
  }
}

class AttendanceStatsView extends StatelessWidget {
  final String churchName;
  const AttendanceStatsView({super.key, required this.churchName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
          appBar: AppBar(
            title: Text('$churchName 출석 통계'),
          ),
          body: BlocBuilder<AttendanceStatsBloc, AttendanceStatsState>(
            builder: (context, state) {
              if (state is AttendanceStatsLoadInProgress) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is AttendanceStatsLoadSuccess) {
                return _AttendanceStatsTable(
                    attendanceList: state.attendanceList,
                    churchName: churchName,
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
  final ScreenshotController screenshotController;

  const _AttendanceStatsTable(
      {required this.attendanceList,
        required this.churchName,
        required this.screenshotController,
      });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    return Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: Screenshot(
                  controller: screenshotController,
                  child: DataTable(
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
                            (index) => DataColumn(
                          label: Text(
                            (index + 1).toString(),
                            style: const TextStyle(fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),
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
    final age = _calculateAge(user.birthdate);
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
            final currentDate =
                DateTime.utc(DateTime.now().year, DateTime.now().month, dayIndex + 1);
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

  int _calculateAge(String birthdate) {
    if (birthdate.length != 6) return 0;
    try {
      int year = int.parse(birthdate.substring(0, 2));
      final int month = int.parse(birthdate.substring(2, 4));
      final int day = int.parse(birthdate.substring(4, 6));

      int currentYearLastTwoDigits = DateTime.now().year % 100;
      year += (year > currentYearLastTwoDigits) ? 1900 : 2000;

      final birthDate = DateTime(year, month, day);
      final today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _exportToExcel(BuildContext context) async {
    try {
      final now = DateTime.now();
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final monthString = DateFormat('yyyy-MM').format(now);
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
        final age = _calculateAge(user.birthdate);
        final attendanceData = List.generate(daysInMonth, (dayIndex) {
          final currentDate = DateTime.utc(now.year, now.month, dayIndex + 1);
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

      final monthString = DateFormat('yyyy-MM').format(DateTime.now());
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