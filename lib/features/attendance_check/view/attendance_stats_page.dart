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
                return Center(child: Text('오류: ${state.error}'));
              } else {
                return const Center(child: Text('통계 데이터가 없습니다.'));
              }
            },
          )
    );
  }
}

// <<< ✨ [수정] 테이블 위젯 전체를 헤더가 고정되도록 수정 ✨ >>>
class _AttendanceStatsTable extends StatelessWidget {
  final List<UserAttendance> attendanceList;
  final String churchName;
  final DateTime selectedDate;
  final ScreenshotController screenshotController;

  // 테이블 컬럼 너비를 상수로 정의하여 헤더와 데이터의 정렬을 맞춥니다.
  static const double districtColWidth = 70.0;
  static const double baptismColWidth = 50.0;
  static const double nameColWidth = 120.0;
  static const double birthdateColWidth = 90.0;
  static const double ageColWidth = 50.0;
  static const double dateColWidth = 55.0;

  const _AttendanceStatsTable(
      {required this.attendanceList,
        required this.churchName,
        required this.selectedDate,
        required this.screenshotController,
      });

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(selectedDate.year, selectedDate.month + 1, 0).day;
    const weekDays = ['월', '화', '수', '목', '금', '토', '일'];

    return Column(
        children: [
          Expanded(
            child: Screenshot(
              controller: screenshotController,
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    // 전체 테이블의 너비를 계산합니다.
                    width: districtColWidth +
                        baptismColWidth +
                        nameColWidth +
                        birthdateColWidth +
                        ageColWidth +
                        (dateColWidth * daysInMonth),
                    child: Column(
                      children: [
                        // 1. 고정된 헤더 행
                        _buildHeaderRow(daysInMonth, weekDays),
                        // 2. 스크롤 가능한 데이터 행
                        Expanded(
                          child: ListView.builder(
                            itemCount: attendanceList.length,
                            itemBuilder: (context, index) {
                              return _buildDataRow(
                                  attendanceList[index], daysInMonth, context);
                            },
                          ),
                        ),
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

  /// 고정된 헤더 행을 생성하는 위젯
  Widget _buildHeaderRow(int daysInMonth, List<String> weekDays) {
    return Container(
      height: 60, // 헤더 높이 고정
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
      ),
      child: Row(
        children: [
          _buildHeaderCell('구역', districtColWidth),
          _buildHeaderCell('세례', baptismColWidth),
          _buildHeaderCell('이름', nameColWidth),
          _buildHeaderCell('생년월일', birthdateColWidth),
          _buildHeaderCell('만나이', ageColWidth),
          ...List.generate(
            daysInMonth,
            (index) {
              final day = index + 1;
              final date = DateTime(selectedDate.year, selectedDate.month, day);
              final dayOfWeek = weekDays[date.weekday - 1];
              return _buildHeaderCell(
                '$day\n($dayOfWeek)',
                dateColWidth,
                isDate: true,
              );
            },
          ),
        ],
      ),
    );
  }

  /// 데이터 행을 생성하는 위젯
  Widget _buildDataRow(UserAttendance userAttendance, int daysInMonth,
      BuildContext context) {
    final user = userAttendance.user;
    final age = _calculateAge(user.birthdate, selectedDate);
    final isVisitor = user.church != churchName;

    return Container(
      height: 48, // 데이터 행 높이 고정
      decoration: BoxDecoration(
        color: isVisitor ? Colors.grey.withOpacity(0.2) : null,
      ),
      child: Row(
        children: [
          _buildDataCell(userAttendance.district ?? '-', districtColWidth),
          _buildDataCell(userAttendance.baptismNumber?.toString() ?? '-', baptismColWidth),
          _buildNameCell(user.name, isVisitor, user.church ?? '', nameColWidth),
          _buildDataCell(user.birthdate, birthdateColWidth),
          _buildDataCell(age > 0 ? age.toString() : '-', ageColWidth),
          ...List.generate(
            daysInMonth,
            (dayIndex) {
              final currentDate =
                  DateTime.utc(selectedDate.year, selectedDate.month, dayIndex + 1);
              final attendanceStatus =
                  userAttendance.attendanceRecords[currentDate] ??
                      AttendanceStatus.none;
              return SizedBox(
                width: dateColWidth,
                child: _buildAttendanceIndicator(attendanceStatus),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets for Table Cells ---

  Widget _buildHeaderCell(String text, double width, {bool isDate = false}) {
    return SizedBox(
      width: width,
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isDate ? 12 : null,
          ),
        ),
      ),
    );
  }

  Widget _buildDataCell(String text, double width) {
    return SizedBox(
      width: width,
      child: Center(
        child: Text(text, style: const TextStyle(fontSize: 13)),
      ),
    );
  }

  Widget _buildNameCell(String name, bool isVisitor, String originalChurch, double width) {
    return SizedBox(
      width: width,
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(name, style: const TextStyle(fontSize: 13)),
            if (isVisitor) ...[
              const SizedBox(width: 4),
              Tooltip(
                message: '$originalChurch 소속',
                child: Icon(Icons.star, color: Colors.amber.shade700, size: 14),
              ),
            ]
          ],
        ),
      ),
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

  int _calculateAge(String birthdate, DateTime baseDate) {
    if (birthdate.length != 6) return 0;
    try {
      int year = int.parse(birthdate.substring(0, 2));
      final int month = int.parse(birthdate.substring(2, 4));
      final int day = int.parse(birthdate.substring(4, 6));

      int currentYearLastTwoDigits = baseDate.year % 100;
      year += (year > currentYearLastTwoDigits) ? 1900 : 2000;

      final birthDate = DateTime(year, month, day);
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
        TextCellValue('구역'), TextCellValue('세례'), TextCellValue('이름'),
        TextCellValue('생년월일'), TextCellValue('만나이'),
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
          TextCellValue(user.name), TextCellValue(user.birthdate),
          TextCellValue(age > 0 ? age.toString() : '-'),
          ...attendanceData.map((e) => TextCellValue(e))
        ]);
      }

      var bytes = excel.save();
      if (bytes == null) throw Exception("Failed to save Excel file.");

      await saveFile(
        context, Uint8List.fromList(bytes), fileName,
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
      if (imageBytes == null) throw Exception("Failed to capture image.");

      final monthString = DateFormat('yyyy-MM').format(selectedDate);
      final fileName = '${churchName}_${monthString}_attendance.png';

      await saveFile(
        context, imageBytes, fileName, mimeType: 'image/png',
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 다운로드 중 오류 발생: $e')),
      );
    }
  }
}