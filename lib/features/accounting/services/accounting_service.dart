// lib/features/accounting/services/accounting_service.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:narrow_gil/features/accounting/models/event_model.dart';
import 'package:narrow_gil/features/accounting/models/receipt_model.dart';
import 'package:narrow_gil/features/accounting/models/accounting_log_model.dart';

// [수정] CsvDataType에서 transaction 제거
enum CsvDataType { accountingLog }

class AccountingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

    // ✨ [추가] CSV 업로드 시 동명이인 처리를 위한 배치 생성 및 커밋 함수
  WriteBatch getBatch() => _firestore.batch();
  Future<void> commitBatch(WriteBatch batch) => batch.commit();

   // ✨ [추가] 이름으로 사용자를 검색하고 상세 정보를 반환하는 함수 (동명이인 처리용)
  Future<List<Map<String, dynamic>>> findUsersByName(String name) async {
    final snapshot = await _firestore
        .collection('users')
        .where('name', isEqualTo: name)
        .get();

    if (snapshot.docs.isEmpty) return [];

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'name': data['name'] as String,
        'church': data['church'] as String,
        // birthDate 필드가 String으로 저장되어 있다고 가정합니다. Timestamp일 경우 변환이 필요합니다.
        'birthDate': data['birthDate'] as String? ?? '정보 없음',
      };
    }).toList();
  }

    // ✨ [추가] CSV의 한 행을 처리하여 배치에 추가하는 함수
  Future<void> processCsvRowForBatch({
    required WriteBatch batch,
    required String churchId,
    required String sectionName,
    required AccountingLogModel log,
    String? targetUserChurch, // 헌금 업데이트 시 필요한 대상자의 소속 교회
  }) async {
    final logRef = _firestore
        .collection('churches').doc(churchId)
        .collection('accounting_logs').doc(sectionName)
        .collection('logs').doc();

    // 전달받은 log 모델에 생성된 문서 ID를 부여하여 새 모델 생성
    final logWithId = AccountingLogModel(
        id: logRef.id, fromArea: log.fromArea, toArea: log.toArea,
        householdHead: log.householdHead, userId: log.userId,
        managerId: log.managerId, managerName: log.managerName,
        type: log.type, amount: log.amount, date: log.date,
        hasProof: log.hasProof, proofId: log.proofId, item: log.item);

    batch.set(logRef, logWithId.toMap());

    // '헌금' 항목이고 대상자 ID가 있을 경우, donation 필드 업데이트 로직 추가
    if (log.item.startsWith('헌금') && log.userId != null && targetUserChurch != null) {
      final memberRef = _firestore
          .collection('approved_members').doc(targetUserChurch)
          .collection('members').doc(log.userId!);
      batch.update(memberRef, {'donation': FieldValue.increment(log.amount)});
    }
  }

  // ✨ [수정] users 컬렉션에서 사용자 목록을 가져오도록 변경
  Future<List<Map<String, String>>> getUsers() async {
    final snapshot = await _firestore.collection('users').get();
    if (snapshot.docs.isEmpty) return [];
    return snapshot.docs
        .where((doc) => doc.data().containsKey('name') && doc.data().containsKey('church'))
        .map((doc) => {
              'id': doc.id,
              'name': doc['name'] as String,
              'church': doc['church'] as String,
            })
        .toList();
  }

  // ✨ [추가] 재정 요약 데이터를 계산하는 함수
  Stream<Map<String, double>> getSectionSummary(String churchId, String sectionName) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfPreviousMonth = DateTime(now.year, now.month - 1, 1);

    return _firestore
        .collection('churches').doc(churchId)
        .collection('accounting_logs').doc(sectionName)
        .collection('logs')
        .snapshots()
        .map((snapshot) {
      double currentBalance = 0;
      double thisMonthIncome = 0;
      double thisMonthExpense = 0;
      double previousMonthCarryover = 0;

      for (var doc in snapshot.docs) {
        final log = AccountingLogModel.fromFirestore(doc);
        final logDate = log.date.toDate();

        // 전체 잔액 계산
        if (log.type == LogType.income) {
          currentBalance += log.amount;
        } else {
          currentBalance -= log.amount;
        }

        // 이번 달 수입/지출
        if (logDate.isAfter(startOfMonth) || logDate.isAtSameMomentAs(startOfMonth)) {
          if (log.type == LogType.income) thisMonthIncome += log.amount;
          if (log.type == LogType.expense) thisMonthExpense += log.amount;
        }

        // 지난달까지의 잔액 (전달 이월금)
        if (logDate.isBefore(startOfMonth)) {
           if (log.type == LogType.income) previousMonthCarryover += log.amount;
           if (log.type == LogType.expense) previousMonthCarryover -= log.amount;
        }
      }
      return {
        'currentBalance': currentBalance,
        'thisMonthIncome': thisMonthIncome,
        'thisMonthExpense': thisMonthExpense,
        'previousMonthCarryover': previousMonthCarryover,
      };
    });
  }

  // ✨ [추가] 증빙 처리 로그를 기록하는 함수
  Future<void> _addApprovalLog({
    required String church,
    required ReceiptModel receipt,
    required String managerName,
    required ReceiptStatus status,
    String? reason,
  }) async {
    final logRef = _firestore.collection('churches').doc(church).collection('approval_logs').doc();
    await logRef.set({
      'receiptId': receipt.id,
      'receiptSubmitterName': receipt.userName,
      'receiptAmount': receipt.amount,
      'managerName': managerName,
      'status': status.name,
      'reason': reason,
      'processedAt': FieldValue.serverTimestamp(),
    });
  }

  // ✨ [추가] 페이지네이션이 적용된 처리 로그 목록 함수
  Future<Map<String, dynamic>> getApprovalLogsPaginated({
    required String churchId,
    int limit = 10,
    DocumentSnapshot? startAfter,
  }) async {
    Query query = _firestore
        .collection('churches')
        .doc(churchId)
        .collection('approval_logs')
        .orderBy('processedAt', descending: true);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final querySnapshot = await query.limit(limit).get();
    final logs = querySnapshot.docs.map((doc) => ApprovalLog.fromFirestore(doc)).toList();
    final lastDocument = querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null;
    final hasMore = logs.length == limit;

    return {
      'logs': logs,
      'lastDocument': lastDocument,
      'hasMore': hasMore,
    };
  }

    // --- ▼ [추가] 특정 교회의 행사 목록을 가져오는 함수 ---
  Stream<List<EventModel>> getEvents(String churchId) {
    return _firestore
        .collection('churches')
        .doc(churchId)
        .collection('events')
        .orderBy('date', descending: true) // 최신순으로 정렬
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => EventModel.fromFirestore(doc)).toList());
  }

  Stream<List<ReceiptModel>> getUserReceipts(String userId, String church) {
  return _firestore
      .collection('churches')
      .doc(church)
      .collection('receipt_submissions')
      .where('userId', isEqualTo: userId)
      .orderBy('submittedAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => ReceiptModel.fromFirestore(doc)).toList());
  }

  Future<List<String>> getAccountingAreas(String churchId) async {
    final docSnapshot = await _firestore.collection('churches').doc(churchId).get();
    if (docSnapshot.exists && docSnapshot.data()!.containsKey('구역')) {
      return List<String>.from(docSnapshot.data()!['구역']);
    }
    return [];
  }

   Future<void> addAccountingArea({
    required String churchId,
    required String areaName,
    required String target, // target 파라미터 추가
  }) async {
    // '구역' 필드는 배열이므로 arrayUnion을 사용합니다.
    await _firestore.collection('churches').doc(churchId).update({
      '구역': FieldValue.arrayUnion([areaName]),
      // 필요하다면 target 정보도 저장할 수 있습니다.
      // 예: '회계구역_대상': FieldValue.arrayUnion(['$areaName:$target'])
    });
  }

// receipt_submissions 콜렉션은 이미 churches/{churchId} 하위에 있으므로 구조 변경 없음
  Future<void> submitReceipt({
    required String userId,
    required String userName,
    required String church, // 여기서 church가 churchId 역할을 함
    required List<XFile> files,
    required double amount,
    required String accountingArea,
  }) async {
    List<String> fileUrls = [];
    for (var file in files) {
      final filePath = 'churches/$church/receipts/$userId/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final ref = _storage.ref().child(filePath);
      await ref.putData(await file.readAsBytes());
      final downloadUrl = await ref.getDownloadURL();
      fileUrls.add(downloadUrl);
    }
    // churches/{church} 경로 사용 (올바른 구조)
    await _firestore.collection('churches').doc(church).collection('receipt_submissions').add({
      'userId': userId,
      'userName': userName,
      'fileUrls': fileUrls,
      'amount': amount,
      'accountingArea': accountingArea,
      'status': ReceiptStatus.pending.name,
      'submittedAt': FieldValue.serverTimestamp(),
      'rejectionReason': null,
    });
  }

  // --- ▼ [수정] 날짜(date)와 수입/지출(logType) 파라미터를 받도록 함수 시그니처 변경 ---
  Future<void> createAccountingLog({
    required String churchId,
    required String currentSection, // 작업을 수행하는 현재 구역
    required String target,         // 거래 대상 (다른 구역 또는 외부인)
    required double amount,
    required String item,
    required String managerId,
    required String managerName,
    required bool isInternal,     // 내부 구역 간 거래 여부
    required LogType logType,       // [추가] 사용자가 선택한 수입/지출 타입
    required DateTime date,          // [추가] 사용자가 선택한 날짜
    String? targetUserId, // 외부 거래 대상자 ID
    String? targetUserChurch, // 외부 거래 대상자 소속 교회
  }) async {
    final batch = _firestore.batch();
    final timestamp = Timestamp.fromDate(date);

    // 내부 구역 간 거래일 경우 (지출과 수입을 모두 기록)
    if (isInternal) {
      // 1. 보내는 구역(currentSection)의 지출 내역 생성
      final expenseLogRef = _firestore
          .collection('churches').doc(churchId)
          .collection('accounting_logs').doc(currentSection)
          .collection('logs').doc();

      final expenseLog = AccountingLogModel(
        id: expenseLogRef.id,
        fromArea: currentSection,
        toArea: target,
        householdHead: target,
        type: LogType.expense, // 지출로 고정
        amount: amount,
        item: item,
        date: timestamp,
        managerId: managerId,
        managerName: managerName,
      );
      batch.set(expenseLogRef, expenseLog.toMap());

      // --- ✨ [수정] 2. 받는 구역(target)의 수입 내역 생성 ---
      // 'churchId'와 부서 이름인 'target'을 조합하여 정확한 전체 경로를 만듭니다.
      // 예: '서울교회' + ' ' + '장년부' -> '서울교회 장년부'
      final targetSectionName = '$churchId $target';

      final incomeLogRef = _firestore
          .collection('churches').doc(churchId)
          .collection('accounting_logs').doc(targetSectionName) // 수정된 경로 사용
          .collection('logs').doc();

      final incomeLog = AccountingLogModel(
        id: incomeLogRef.id,
        fromArea: currentSection,
        toArea: targetSectionName, // 받는 구역 이름도 전체 경로로 기록
        householdHead: currentSection, // 수입 입장에서는 보낸 구역이 거래 대상
        type: LogType.income,
        amount: amount,
        item: item,
        date: timestamp,
        managerId: managerId,
        managerName: managerName,
      );
      batch.set(incomeLogRef, incomeLog.toMap());
    }
    else {
      // 외부/개인 거래일 경우 (기존과 동일)
      final logRef = _firestore
          .collection('churches').doc(churchId)
          .collection('accounting_logs').doc(currentSection)
          .collection('logs').doc();

      final log = AccountingLogModel(
        id: logRef.id,
        fromArea: logType == LogType.expense ? currentSection : target,
        toArea: logType == LogType.expense ? target : currentSection,
        householdHead: target,
        type: logType,
        amount: amount,
        item: item,
        date: timestamp,
        managerId: managerId,
        managerName: managerName,
        userId: targetUserId, // ✨ [추가] 대상자 ID 저장

      );
      batch.set(logRef, log.toMap());

      // ✨ [추가] '헌금' 항목일 경우, 대상자의 donation 필드 업데이트
      if (item.startsWith('헌금') && targetUserId != null && targetUserChurch != null) {
        final memberRef = _firestore
            .collection('approved_members').doc(targetUserChurch)
            .collection('members').doc(targetUserId);
        batch.update(memberRef, {'donation': FieldValue.increment(amount)});
      }
    }

    await batch.commit();
  }



  /// 특정 회계 구역의 처리 대기 증빙 목록을 가져옵니다.
  Stream<List<ReceiptModel>> getReceiptsForReview(String churchId, String accountingArea) {
    return _firestore
        .collection('churches')
        .doc(churchId)
        .collection('receipt_submissions')
        .where('accountingArea', isEqualTo: accountingArea)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ReceiptModel.fromFirestore(doc)).toList());
  }

  // ✨ [추가] 페이지네이션이 적용된 상세 입출금 내역 함수
  Future<Map<String, dynamic>> getAccountingLogsPaginated(String churchId, String sectionName, {
     int limit = 10,
     DocumentSnapshot? startAfter,
     int? year, String? name, LogType? type, String? householdHead,
  }) async {
    Query query = _firestore
        .collection('churches').doc(churchId)
        .collection('accounting_logs').doc(sectionName)
        .collection('logs')
        .orderBy('date', descending: true);

    if (year != null) {
       final start = Timestamp.fromDate(DateTime(year));
       final end = Timestamp.fromDate(DateTime(year + 1));
       query = query.where('date', isGreaterThanOrEqualTo: start).where('date', isLessThan: end);
    }
    if (name != null && name.isNotEmpty && name != '전체') {
      query = query.where('managerName', isEqualTo: name);
    }
    if (type != null) {
        query = query.where('type', isEqualTo: type.name);
    }
    if (householdHead != null && householdHead.isNotEmpty && householdHead != '전체') {
        query = query.where('householdHead', isEqualTo: householdHead);
    }

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final querySnapshot = await query.limit(limit).get();
    final logs = querySnapshot.docs.map((doc) => AccountingLogModel.fromFirestore(doc)).toList();
    final lastDocument = querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null;
    final hasMore = logs.length == limit;

    return {
      'logs': logs,
      'lastDocument': lastDocument,
      'hasMore': hasMore,
    };
  }
  /// 증빙을 승인하고 상세 입출금 내역에 자동으로 기록합니다.
  Future<void> approveReceipt(ReceiptModel receipt, {
    required String church,
    required String accountingSection,
    required String managerId,
    required String managerName,
  }) async {
    final receiptRef = _firestore
        .collection('churches').doc(church)
        .collection('receipt_submissions').doc(receipt.id);

    final logRef = _firestore
        .collection('churches').doc(church)
        .collection('accounting_logs').doc(accountingSection)
        .collection('logs').doc();

    await _firestore.runTransaction((transaction) async {
      transaction.update(receiptRef, {'status': ReceiptStatus.approved.name});
      final newLog = AccountingLogModel(
        id: logRef.id,
        householdHead: receipt.userName, // 증빙 제출자를 거래 대상으로
        fromArea: accountingSection,
        toArea: receipt.userName, // 외부인으로 간주
        managerId: managerId,
        managerName: managerName,
        type: LogType.expense,
        amount: receipt.amount,
        date: receipt.submittedAt,
        hasProof: true,
        proofId: receipt.id,
        item: receipt.accountingArea, // 관리항목 형식에 맞춤
      );
      transaction.set(logRef, newLog.toMap());
    });
    await _addApprovalLog(church: church, receipt: receipt, managerName: managerName, status: ReceiptStatus.approved);
  }

 // ✨ [수정] 반려 시 로그가 기록되도록 로직을 완성합니다.
  Future<void> rejectReceipt(ReceiptModel receipt, {
    required String church,
    required String reason,
    required String managerName,
  }) async {
    final docRef = _firestore.collection('churches').doc(church).collection('receipt_submissions').doc(receipt.id);

    // 1. Firestore 문서의 상태와 반려 사유를 업데이트합니다.
    await docRef.update({
      'status': ReceiptStatus.rejected.name,
      'rejectionReason': reason,
    });

    // 2. 처리 로그를 기록합니다.
    await _addApprovalLog(
      church: church,
      receipt: receipt,
      managerName: managerName,
      status: ReceiptStatus.rejected,
      reason: reason
    );
  }

  // ✨ [추가] 증빙 문서를 삭제하는 함수
  Future<void> deleteReceipt(String churchId, String receiptId) async {
    // Firestore 문서 삭제
    await _firestore
        .collection('churches')
        .doc(churchId)
        .collection('receipt_submissions')
        .doc(receiptId)
        .delete();

    // TODO: Storage에 저장된 이미지 파일들도 함께 삭제하는 로직을 추가하면 더 좋습니다.
    // (예: 영수증 모델에 파일 경로를 저장해두고, 그 경로로 Storage 파일 삭제)
  }

  /// 입출금 내역을 추가합니다. (CSV 업로드 등에서 사용)
  Future<void> addAccountingLog(String churchId, String sectionName, AccountingLogModel log) async {
    await _firestore
        .collection('churches').doc(churchId)
        .collection('accounting_logs').doc(sectionName)
        .collection('logs').add(log.toMap());
  }

  /// 입출금 내역의 특정 필드를 수정합니다.
  Future<void> updateAccountingLogField(String churchId, String sectionName, String docId, String field, dynamic value) async {
    await _firestore
        .collection('churches').doc(churchId)
        .collection('accounting_logs').doc(sectionName)
        .collection('logs').doc(docId).update({field: value});
  }

  /// 입출금 내역을 삭제합니다.
  Future<void> deleteAccountingLog(String churchId, String sectionName, String docId) async {
    await _firestore
        .collection('churches').doc(churchId)
        .collection('accounting_logs').doc(sectionName)
        .collection('logs').doc(docId).delete();
  }

/// 상세 입출금 내역 전체를 CSV 문자열로 변환하는 함수
  Future<String> exportAccountingLogsToCsv(String churchId, String sectionName) async {
    final querySnapshot = await _firestore
        .collection('churches').doc(churchId)
        .collection('accounting_logs').doc(sectionName)
        .collection('logs')
        .orderBy('date', descending: true)
        .get();

    final logs = querySnapshot.docs.map((doc) => AccountingLogModel.fromFirestore(doc)).toList();

    // CSV 데이터를 만들기 위해 StringBuffer를 사용합니다.
    final buffer = StringBuffer();

    // 1. 헤더(첫 번째 줄)를 작성하고, Windows 호환성을 위해 CRLF(\r\n)로 줄바꿈합니다.
    buffer.write('fromArea,toArea,householdHead,type,amount,tier1,tier2,details,managerName');
    buffer.write('\r\n');

    // 2. 각 로그 데이터를 한 줄씩 추가합니다.
    for (final log in logs) {
      // item 필드를 다시 3단계로 분리합니다.
      final itemParts = log.item.split(':');
      String tier1 = '', tier2 = '', details = '';
      if (itemParts.length == 3) {
        tier1 = itemParts[0];
        tier2 = itemParts[1];
        details = itemParts[2];
      } else {
        details = log.item;
      }

      // CSV의 각 셀에 쉼표(,), 큰따옴표("), 줄바꿈(\n)이 포함된 경우를 처리하기 위한 함수입니다.
      String escapeCsvField(String? field) {
        if (field == null) return '';
        // 필드에 쉼표, 큰따옴표, 줄바꿈 문자가 포함되어 있으면, 전체를 큰따옴표로 감싸고 내부의 큰따옴표는 두 개로 만듭니다. (CSV 표준 RFC 4180)
        if (field.contains(',') || field.contains('"') || field.contains('\n')) {
          return '"${field.replaceAll('"', '""')}"';
        }
        return field;
      }

      final row = [
        escapeCsvField(log.fromArea),
        escapeCsvField(log.toArea),
        escapeCsvField(log.householdHead),
        log.type.name,
        log.amount.toString(),
        escapeCsvField(tier1),
        escapeCsvField(tier2),
        escapeCsvField(details),
        escapeCsvField(log.managerName),
      ].join(',');

      // 3. 각 데이터 행을 추가한 후, CRLF(\r\n)로 줄바꿈합니다.
      buffer.write(row);
      buffer.write('\r\n');
    }

    return buffer.toString();
  }


  /// 사용자의 소속 부서를 가져옵니다.
  Future<String?> getUserDepartment(String churchId, String userId) async {
    try {
      final docSnapshot = await _firestore
          .collection('approved_members')
          .doc(churchId)
          .collection('members')
          .doc(userId)
          .get();

      if (docSnapshot.exists && docSnapshot.data()!.containsKey('district')) {
        return docSnapshot.data()!['district'] as String?;
      }
      return null;
    } catch (e) {
      print('Error fetching user department: $e');
      return null;
    }
  }

  /// 특정 구역에 소속된 회원 목록을 가져옵니다.
  Future<List<String>> getMemberNamesByDistrict(String churchId, String district) async {
    final snapshot = await _firestore
        .collection('approved_members')
        .doc(churchId)
        .collection('members')
        .where('district', isEqualTo: district)
        .get();

    if (snapshot.docs.isEmpty) return [];
    return snapshot.docs
        .where((doc) => doc.data().containsKey('name'))
        .map((doc) => doc['name'] as String)
        .toSet()
        .toList();
  }

  /// 특정 교회에 소속된 세대주 목록을 가져옵니다.
  Future<List<String>> getHouseholdHeads(String churchId) async {
    final snapshot = await _firestore
        .collection('approved_members')
        .doc(churchId)
        .collection('members')
        .get();

    if (snapshot.docs.isEmpty) return [];
    return snapshot.docs
        .where((doc) => doc.data().containsKey('houseHoldHead'))
        .map((doc) => doc['houseHoldHead'] as String)
        .toSet()
        .toList();
  }

  /// 모든 교회 이름 목록을 가져옵니다.
  Future<List<String>> getChurchNames() async {
    final snapshot = await _firestore.collection('churches').get();
    return snapshot.docs
        .map((doc) => doc.id)
        .toList();
  }

  /// 특정 교회의 모든 부서(구역) 목록을 실시간으로 가져옵니다.
  Stream<List<String>> getDepartments(String churchId) {
    return _firestore.collection('churches').doc(churchId).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data()!.containsKey('구역')) {
        return List<String>.from(snapshot.data()!['구역']);
      }
      return [];
    });
  }

  /// 특정 교회에 새로운 부서를 추가합니다.
  Future<void> addDepartment(String churchId, String departmentName) async {
    final docRef = _firestore.collection('churches').doc(churchId);
    return docRef.update({
      '구역': FieldValue.arrayUnion([departmentName])
    });
  }
}