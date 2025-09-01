import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:narrow_gil/features/member_management/models/member_log_model.dart';
import 'package:narrow_gil/features/member_management/models/member_model.dart';
import 'package:uuid/uuid.dart';

class MemberManagementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // --- ▼ [구현] 교인 삭제 및 로그 기록 함수 ---
  Future<void> deleteMember({
    required String churchName,
    required String memberId,
    required String memberName,
    required String editorName,
  }) async {
    // 1. 삭제할 교인 문서의 참조를 가져옵니다.
    final memberRef = _firestore
        .collection('approved_members')
        .doc(churchName)
        .collection('members')
        .doc(memberId);

    // 2. 이 삭제 행위를 기록할 새로운 로그 문서의 참조를 만듭니다.
    final logRef = _firestore
        .collection('churches')
        .doc(churchName)
        .collection('member_logs')
        .doc();

    // 3. Firestore Batch Write를 사용하여 두 작업을 하나의 원자적 단위로 묶습니다.
    //    이렇게 하면 둘 중 하나라도 실패할 경우 아무 작업도 수행되지 않아 데이터 정합성을 보장합니다.
    final batch = _firestore.batch();

    // 3-1. 교인 문서를 삭제하는 작업을 배치에 추가합니다.
    batch.delete(memberRef);

    // 3-2. '삭제' 행위에 대한 로그를 생성하는 작업을 배치에 추가합니다.
    final log = MemberLog(
      id: logRef.id,
      memberName: memberName,
      field: '교인', // 어떤 종류의 데이터인지 명시
      oldValue: memberName, // 삭제된 대상의 이름
      newValue: '삭제됨', // 변경된 상태
      editorName: editorName, // 작업을 수행한 사람
      editedAt: Timestamp.now(), // 작업 시간
      action: '삭제', // 수행된 작업의 종류
    );
    batch.set(logRef, log.toMap());

    // 4. 배치에 추가된 모든 작업을 한 번에 실행합니다.
    await batch.commit();
  }



    // --- ▼ [수정] 교인 목록 불러오기 (정렬 기능 추가) ---
  Stream<List<Member>> getMembers(String churchName) {
    return _firestore
        .collection('approved_members')
        .doc(churchName)
        .collection('members')
        // 1. 'district' 필드를 기준으로 오름차순 정렬합니다.
        .orderBy('district', descending: false)
        // 2. 같은 'district' 내에서는 'position' 필드를 기준으로 오름차순 정렬합니다.
        .orderBy('role', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Member.fromFirestore(doc)).toList());
  }

   // --- ▼ [수정] CSV 파일 업로드 및 데이터베이스 저장 로직 수정 ---
  Future<void> uploadMembersFromCSV(
      Uint8List csvBytes, String churchName) async {
    // 1. Storage에 CSV 파일 저장
    final fileName = 'members_${DateTime.now().toIso8601String()}.csv';
    final storageRef =
        _storage.ref('churches/$churchName/administration/$fileName');
    await storageRef.putData(csvBytes);

    // 2. CSV 내용 파싱
    // UTF-8 with BOM(Byte Order Mark)을 처리하기 위해 디코딩 로직 수정
    final csvString = utf8.decode(csvBytes, allowMalformed: true);
    final List<List<dynamic>> rows =
        const CsvToListConverter(shouldParseNumbers: false).convert(csvString);

    if (rows.length < 2) return;

    final batch = _firestore.batch();
    final membersCollection = _firestore
        .collection('approved_members')
        .doc(churchName)
        .collection('members');

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 8) continue; // CSV 열 개수 확인

      // --- ▼ [수정] CSV 열 순서에 맞게 인덱스 조정 및 필드명 일치 ---
      final memberData = {
        'name': row[0],
        'gender': row[1],
        'phoneNumber': row[2].replaceAll('/', '').replaceAll(' ', ''), // 하이픈, 공백 제거
        'role': row[3], // Firestore 필드명 'role'
        'district': row[4],
        'houseHoldHead': row[5],
        'baptismDate': row[6].replaceAll('/', ''), // 날짜 형식 통일
        'donation': int.tryParse(row[7]) ?? 0,
        'lastLogin': null,
        'skyScore': 100,
      };
      // --- ▲ [수정] ---

      final memberQuery = await membersCollection
          .where('phoneNumber', isEqualTo: memberData['phoneNumber'])
          .limit(1)
          .get();

      if (memberQuery.docs.isNotEmpty) {
        batch.update(memberQuery.docs.first.reference, memberData);
      } else {
        final newDocRef = membersCollection.doc();
        batch.set(newDocRef, memberData);
      }
    }
    await batch.commit();
  }

  // ✨ [추가] 새로운 교인 추가 메서드
  Future<void> addMember({
    required String name,
    required String phoneNumber,
    required String gender,
    required String role,
    String? baptismDate,
    required String district,
    required String houseHoldHead,
    required String churchName, // church가 아닌 churchName으로 명확히 함
  }) async {
    final membersCollection = _firestore
        .collection('approved_members')
        .doc(churchName)
        .collection('members');

    final querySnapshot = await membersCollection
        .where('phoneNumber', isEqualTo: phoneNumber)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      throw Exception('이미 등록된 전화번호입니다.');
    }

    final newMemberData = {
      'name': name,
      'phoneNumber': phoneNumber,
      'gender': gender,
      'role': role,
      'baptismDate': baptismDate?.isNotEmpty == true ? baptismDate : null,
      'district': district,
      'skyScore': 100,
      'lastLogin': null,
      'houseHoldHead': houseHoldHead,
      'donation': 0
    };

    await membersCollection.add(newMemberData);
  }

  // ✨ [수정] 교인 정보 업데이트 및 로그 기록
  Future<void> updateMemberField(String docId, String field, dynamic newValue,
      String churchName, String editorName, Member oldMember) async {
    // approved_members -> {churchName} -> members -> {docId} 경로의 문서를 참조합니다.
    final memberRef = _firestore
        .collection('approved_members')
        .doc(churchName)
        .collection('members')
        .doc(docId);

    // 1. 정보 업데이트
    await memberRef.update({field: newValue});

    // 2. 변경사항 로그 기록 (기존과 동일)
    final logRef = _firestore
        .collection('churches')
        .doc(churchName)
        .collection('member_logs')
        .doc();
    final log = MemberLog(
      id: logRef.id,
      memberName: oldMember.name,
      field: field,
      oldValue: getOldValue(oldMember, field),
      newValue: newValue.toString(),
      editorName: editorName,
      editedAt: Timestamp.now(),
      action: '수정',
    );
    await logRef.set({
      'memberName': log.memberName,
      'field': log.field,
      'oldValue': log.oldValue,
      'newValue': log.newValue,
      'editorName': log.editorName,
      'editedAt': log.editedAt,
      'action': log.action,
    });
  }

  // 변경 전 값을 가져오는 헬퍼 함수 (기존과 동일)
  String getOldValue(Member member, String field) {
    switch (field) {
      case 'name':
        return member.name;
      case 'phoneNumber':
        return member.phoneNumber;
      case 'baptismDate':
        return member.baptismDate ?? '';
      case 'district':
        return member.district;
      case 'role':
        return member.role;
      case 'gender':
        return member.gender;
      case 'skyScore':
        return member.heavenlyScore.toString();
      default:
        return '';
    }
  }

  // 변경사항 로그 불러오기
  Stream<List<MemberLog>> getMemberLogs(String churchName) {
    return _firestore
        .collection('churches')
        .doc(churchName)
        .collection('member_logs')
        .orderBy('editedAt', descending: true)
        .limit(20) // 최근 20개만
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => MemberLog.fromFirestore(doc)).toList());
  }
}
