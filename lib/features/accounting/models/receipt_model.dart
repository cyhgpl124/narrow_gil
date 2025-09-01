// lib/features/accounting/models/receipt_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum ReceiptStatus { pending, approved, rejected }

class ReceiptModel {
  final String id;
  final String userId;
  final String userName;
  // --- ▼ [수정] 단일 URL(String)을 URL 리스트(List<String>)로 변경 ▼ ---
  final List<String> fileUrls;
  // --- ▲ [수정] 단일 URL(String)을 URL 리스트(List<String>)로 변경 ▲ ---
  final double amount;
  final String accountingArea;
  final ReceiptStatus status;
  final Timestamp submittedAt;
  final String? rejectionReason;

  ReceiptModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.fileUrls, // fileUrl -> fileUrls
    required this.amount,
    required this.accountingArea,
    required this.status,
    required this.submittedAt,
    this.rejectionReason,
  });

  factory ReceiptModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ReceiptModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      // --- ▼ [수정] 'fileUrls' 필드를 List<String>으로 안전하게 변환 ▼ ---
      fileUrls: List<String>.from(data['fileUrls'] ?? []),
      // --- ▲ [수정] 'fileUrls' 필드를 List<String>으로 안전하게 변환 ▲ ---
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      accountingArea: data['accountingArea'] ?? '',
      status: ReceiptStatus.values.firstWhere(
        (e) => e.toString() == 'ReceiptStatus.${data['status']}',
        orElse: () => ReceiptStatus.pending, // 기본값 설정
      ),
      submittedAt: data['submittedAt'] ?? Timestamp.now(),
      rejectionReason: data['rejectionReason'],
    );
  }
}

// ✨ [추가] 증빙 처리 로그를 위한 데이터 모델
class ApprovalLog {
  final String id;
  final String receiptId;
  final String receiptSubmitterName; // 증빙 제출자 이름
  final double receiptAmount;        // 증빙 금액
  final String managerName;          // 처리 담당자 이름
  final ReceiptStatus status;        // 처리 결과 (approved/rejected)
  final String? reason;              // 반려 사유 (선택)
  final Timestamp processedAt;       // 처리 일시

  ApprovalLog({
    required this.id,
    required this.receiptId,
    required this.receiptSubmitterName,
    required this.receiptAmount,
    required this.managerName,
    required this.status,
    this.reason,
    required this.processedAt,
  });

  factory ApprovalLog.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ApprovalLog(
      id: doc.id,
      receiptId: data['receiptId'] ?? '',
      receiptSubmitterName: data['receiptSubmitterName'] ?? '',
      receiptAmount: (data['receiptAmount'] as num?)?.toDouble() ?? 0.0,
      managerName: data['managerName'] ?? '',
      status: ReceiptStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => ReceiptStatus.pending,
      ),
      reason: data['reason'],
      processedAt: data['processedAt'] ?? Timestamp.now(),
    );
  }
}