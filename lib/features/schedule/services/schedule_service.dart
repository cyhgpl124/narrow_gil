// lib/features/schedule/services/schedule_service.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:narrow_gil/features/schedule/models/event_model.dart';

class ScheduleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference _getEventsCollection(String churchName) {
    return _firestore.collection('churches').doc(churchName).collection('events');
  }

  // 특정 월의 일정들을 가져오는 함수
  Stream<List<Event>> getEventsForMonth(String churchName, DateTime month) {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    return _getEventsCollection(churchName)
        .where('date', isGreaterThanOrEqualTo: startOfMonth)
        .where('date', isLessThanOrEqualTo: endOfMonth)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList());
  }

  // 새로운 일정을 추가하는 함수
  Future<void> addEvent(String churchName, Event event) async {
    await _getEventsCollection(churchName).add(event.toFirestore());
  }

  // 일정에 참석자를 추가하는 함수
  Future<void> addAttendee(String churchName, String eventId, String userName) async {
    await _getEventsCollection(churchName).doc(eventId).update({
      'attendees': FieldValue.arrayUnion([userName])
    });
  }

  // CSV 파일을 통해 일정을 일괄 업로드하는 함수
  Future<String> uploadEventsFromCsv(String churchName) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.single.bytes == null) {
        return "파일이 선택되지 않았습니다.";
      }

      Uint8List fileBytes = result.files.single.bytes!;

      // 1. UTF-8 BOM (Byte Order Mark) 확인 및 제거
      // BOM은 0xEF, 0xBB, 0xBF 세 바이트로 구성됩니다.
      if (fileBytes.length >= 3 &&
          fileBytes[0] == 0xEF &&
          fileBytes[1] == 0xBB &&
          fileBytes[2] == 0xBF) {
        // BOM이 있다면, 3바이트 이후의 데이터만 사용합니다.
        fileBytes = fileBytes.sublist(3);
      }

      // 2. BOM이 제거된 데이터를 UTF-8로 디코딩
      final csvString = utf8.decode(fileBytes);
      final List<List<dynamic>> csvTable = const CsvToListConverter().convert(csvString);

      if (csvTable.length < 2) {
        return "CSV 파일에 데이터가 없습니다 (헤더 제외).";
      }

      final batch = _firestore.batch();
      final eventsCollection = _getEventsCollection(churchName);
      int successCount = 0;

      for (int i = 1; i < csvTable.length; i++) {
        final row = csvTable[i];
        if (row.length >= 2) {
          try {
            final date = DateFormat('yyyy-MM-dd').parse(row[0].toString());
            final title = row[1].toString();
            final description = row.length > 2 ? row[2].toString() : null;

            final newEvent = Event(
              id: '',
              title: title,
              date: date,
              description: description,
              attendees: [],
            );

            final docRef = eventsCollection.doc();
            batch.set(docRef, newEvent.toFirestore());
            successCount++;
          } catch (e) {
            print("CSV 행 처리 중 오류 발생 (행 $i): $e");
          }
        }
      }

      await batch.commit();
      return "$successCount개의 일정이 성공적으로 업로드되었습니다.";

    } catch (e) {
      print("CSV 업로드 실패: $e");
      return "CSV 업로드 중 오류가 발생했습니다: $e";
    }
  }
}