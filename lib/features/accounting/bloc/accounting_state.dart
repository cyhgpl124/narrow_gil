// lib/features/accounting/bloc/accounting_state.dart

import 'package:equatable/equatable.dart';
import 'package:narrow_gil/features/accounting/models/accounting_log_model.dart';
import 'package:narrow_gil/features/accounting/models/receipt_model.dart';

// 모든 회계 상태의 기반이 되는 추상 클래스
abstract class AccountingState extends Equatable {
  const AccountingState();

  @override
  List<Object> get props => [];
}

// 초기 상태
class AccountingInitial extends AccountingState {}

// 데이터 로딩 중 상태
class AccountingLoading extends AccountingState {}

// 데이터 로딩 성공 상태
class AccountingLoaded extends AccountingState {
  final List<AccountingLogModel> accountingLogs;
  final List<ReceiptModel> pendingReceipts;

  const AccountingLoaded({
    this.accountingLogs = const [],
    this.pendingReceipts = const [],
  });

  @override
  List<Object> get props => [accountingLogs, pendingReceipts];
}

// 데이터 로딩 실패 상태
class AccountingError extends AccountingState {
  final String message;

  const AccountingError(this.message);

  @override
  List<Object> get props => [message];
}