import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:narrow_gil/features/attendance_check/bloc/attendance_stats_bloc.dart';
import 'package:narrow_gil/features/attendance_check/models/attendance_status.dart';
import 'package:narrow_gil/features/attendance_check/models/user_attendance.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart'; // For mobile
import 'package:screenshot/screenshot.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html; // For web


class AttendanceStatsPage extends StatelessWidget {
  final String churchName;
  AttendanceStatsPage({super.key, required this.churchName});

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
  AttendanceStatsView({super.key, required this.churchName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
          appBar: AppBar(
            title: Text('$churchName 출석 통계'),
          ),
          body: BlocBuilder<AttendanceStatsBloc, AttendanceStatsState>(
            builder: (context, state) {
              if (state is AttendanceStatsLoadInProgress) {
                return Center(child: CircularProgressIndicator());
              } else if (state is AttendanceStatsLoadSuccess) {
                return _AttendanceStatsTable(
                    attendanceList: state.attendanceList,
                    churchName: churchName,
                    screenshotController: ScreenshotController(),
                );

              } else if (state is AttendanceStatsLoadFailure) {
                return Center(child: Text('Error: ${state.error}'));
              } else {
                return Center(child: Text('Unknown state'));
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

  _AttendanceStatsTable(
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
                    columnSpacing: 16.0, // 컬럼 간 간격 조절
                    horizontalMargin: 16.0, // 좌우 여백 조절
                    columns: [
                      DataColumn(label: Text('구역', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('세례', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('이름', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('생년월일', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('만나이', style: TextStyle(fontWeight: FontWeight.bold))),
                      ...List.generate(
                        daysInMonth,
                            (index) => DataColumn(
                          label: Text(
                            (index + 1).toString(),
                            style: TextStyle(fontSize: 12),
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
            padding: EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(onPressed: () => _exportToExcel(context), child: Text("엑셀 다운로드")),
                ElevatedButton(onPressed: () => _exportToImage(context), child: Text("이미지 다운로드")),
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
              SizedBox(width: 8),
              if (!isMember)
                Icon(Icons.star, color: Colors.amber, size: 16),
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
        AttendanceStatus.present => Icon(
            Icons.circle,
            color: Colors.green,
            size: 16,
          ),
        AttendanceStatus.remote => Icon(
            Icons.change_history,
            color: Colors.orange,
            size: 16,
          ),
        _ => Text('-'),
      },
    );
  }

  int _calculateAge(String birthdate) {
    if (birthdate.length != 6) return 0;
    try {
      int year = int.parse(birthdate.substring(0, 2));
      final int month = int.parse(birthdate.substring(2, 4));
      final int day = int.parse(birthdate.substring(4, 6));

      // 2000년생 이후와 1900년생을 구분
      // 현재 연도의 마지막 두 자리를 기준으로 판단
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
      return 0; // parsing error
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

      // Add headers
      sheetObject.appendRow([
        TextCellValue('구역'),
        TextCellValue('세례'),
        TextCellValue('이름'),
        TextCellValue('생년월일'),
        TextCellValue('만나이'),
        ...List.generate(daysInMonth, (i) => TextCellValue((i + 1).toString()))
      ]);

      // Add data rows
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

      // Save the Excel file
      var bytes = excel.save();
      if (bytes == null) {
        throw Exception("Failed to save Excel file.");
      }

      if (kIsWeb) {
        // Web implementation
        final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('엑셀 파일 다운로드가 시작되었습니다.')),
        );
      } else {
        // Mobile/Desktop implementation
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/$fileName';
        final file = File(path);
        await file.writeAsBytes(bytes, flush: true);

        // Open the file
        OpenFile.open(path);
      }
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

      if (kIsWeb) {
        // Web implementation
        final blob = html.Blob([imageBytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 다운로드가 시작되었습니다.')),
        );
      } else {
        // Mobile/Desktop implementation
        final directory = await getApplicationDocumentsDirectory();
        final imagePath = '${directory.path}/$fileName';
        final file = File(imagePath);
        await file.writeAsBytes(imageBytes);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이미지가 $imagePath 에 저장되었습니다.'),
            action: SnackBarAction(
              label: '열기',
              onPressed: () => OpenFile.open(imagePath),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 다운로드 중 오류 발생: $e')),
      );
    }
  }
}