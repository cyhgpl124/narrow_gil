// lib/features/accounting/models/accounting_log_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

// 수입/지출 타입을 명확하게 구분하기 위한 Enum
enum LogType { income, expense }

class AccountingLogModel {
  final String id;
  final String? fromArea;      // [추가] 돈을 보낸 구역 또는 개인 (내부 거래 시 사용)
  final String? toArea;        // [추가] 돈을 받은 구역 또는 개인 (내부 거래 시 사용)
  final String householdHead; // 세대주 또는 외부 거래 대상자 이름
  final String? userId; // [✨ 수정] 세대주 또는 외부 거래 대상자 ID
  final String managerId;     // 처리한 담당자 ID
  final String managerName;   // 처리한 담당자 이름
  final LogType type;         // 수입 또는 지출
  final double amount;        // 금액
  final Timestamp date;       // 날짜
  final bool hasProof;        // 증빙 자료 첨부 여부
  final String? proofId;       // 연결된 영수증/증빙 문서의 ID (선택 사항)
  final String item;          // 관리 항목 (3단계 조합 데이터. 예: "운영비:주부식비:주일 점심")

  AccountingLogModel({
    required this.id,
    this.fromArea,
    this.toArea,
    required this.householdHead,
    this.userId,
    required this.managerId,
    required this.managerName,
    required this.type,
    required this.amount,
    required this.date,
    this.hasProof = false,
    this.proofId,
    required this.item,
  });

  // Firestore 문서를 AccountingLogModel 객체로 변환하는 factory 생성자
  factory AccountingLogModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AccountingLogModel(
      id: doc.id,
      fromArea: data['fromArea'], // null일 수 있음
      toArea: data['toArea'],     // null일 수 있음
      householdHead: data['householdHead'] ?? '',
      userId: data['userId'], // [✨ 수정]
      managerId: data['managerId'] ?? '',
      managerName: data['managerName'] ?? '',
      type: (data['type'] == 'income') ? LogType.income : LogType.expense,
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      date: data['date'] ?? Timestamp.now(),
      hasProof: data['hasProof'] ?? false,
      proofId: data['proofId'],
      item: data['item'] ?? '내역 없음',
    );
  }

  // AccountingLogModel 객체를 Firestore에 저장하기 위한 Map으로 변환하는 메서드
  Map<String, dynamic> toMap() {
    return {
      'fromArea': fromArea,
      'toArea': toArea,
      'householdHead': householdHead,
      'userId': userId, // [✨ 수정]
      'managerId': managerId,
      'managerName': managerName,
      'type': type.name, // Enum을 문자열로 저장 ('income' 또는 'expense')
      'amount': amount,
      'date': date,
      'hasProof': hasProof,
      'proofId': proofId,
      'item': item,
    };
  }
}