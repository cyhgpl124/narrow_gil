// lib/features/accounting/bloc/accounting_event.dart

import 'package:equatable/equatable.dart';
import 'package:narrow_gil/features/accounting/models/receipt_model.dart';
import 'package:narrow_gil/features/accounting/models/accounting_log_model.dart';

// 모든 회계 이벤트의 기반이 되는 추상 클래스
abstract class AccountingEvent extends Equatable {
  const AccountingEvent();

  @override
  List<Object?> get props => [];
}

// 특정 회계 구역의 데이터를 불러오기 위한 이벤트
class LoadAccountingSectionData extends AccountingEvent {
  final String sectionName;
  // 필터링을 위한 파라미터들
  final int? year;
  final String? name;
  final String? accountingArea;
  final LogType? type;
  final String? householdHead;

  const LoadAccountingSectionData({
    required this.sectionName,
    this.year,
    this.name,
    this.accountingArea,
    this.type,
    this.householdHead,
  });

  @override
  List<Object?> get props =>
      [sectionName, year, name, accountingArea, type, householdHead];
}

// 사용자가 제출한 증빙 내역 목록을 불러오기 위한 이벤트
class LoadUserReceipts extends AccountingEvent {
  final String userId;

  const LoadUserReceipts(this.userId);

  @override
  List<Object> get props => [userId];
}

// 증빙을 승인 처리하는 이벤트
class ApproveReceipt extends AccountingEvent {
  final ReceiptModel receipt;
  final String accountingSection;
  final String managerId;
  final String managerName;
  final String church;

  const ApproveReceipt({
    required this.receipt,
    required this.accountingSection,
    required this.managerId,
    required this.managerName,
    required this.church,
  });

  @override
  List<Object> get props =>
      [receipt, accountingSection, managerId, managerName, church];
}

// ✨ [수정] RejectReceipt 이벤트가 ReceiptModel 객체와 managerName을 직접 받도록 변경합니다.
class RejectReceipt extends AccountingEvent {
  final ReceiptModel receipt;
  final String reason;
  final String managerName;
  final String church;

  const RejectReceipt({
    required this.receipt,
    required this.reason,
    required this.managerName,
    required this.church,
  });

  @override
  List<Object> get props => [receipt, reason, managerName, church];
}