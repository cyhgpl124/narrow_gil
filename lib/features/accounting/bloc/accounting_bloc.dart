// lib/features/accounting/bloc/accounting_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:narrow_gil/features/accounting/bloc/accounting_event.dart';
import 'package:narrow_gil/features/accounting/bloc/accounting_state.dart';
import 'package:narrow_gil/features/accounting/services/accounting_service.dart';

class AccountingBloc extends Bloc<AccountingEvent, AccountingState> {
  final AccountingService _accountingService;

  AccountingBloc(this._accountingService) : super(AccountingInitial()) {
    // 각 이벤트가 발생했을 때 어떤 동작을 할지 정의합니다.
    on<LoadAccountingSectionData>(_onLoadAccountingSectionData);
    on<ApproveReceipt>(_onApproveReceipt);
    on<RejectReceipt>(_onRejectReceipt);
  }

  // 'LoadAccountingSectionData' 이벤트 처리 핸들러
  Future<void> _onLoadAccountingSectionData(
    LoadAccountingSectionData event,
    Emitter<AccountingState> emit,
  ) async {
    emit(AccountingLoading()); // 데이터 로딩 시작 상태로 변경
    try {
      // 서비스의 함수들을 호출하여 데이터를 스트림 형태로 받아옵니다.
      // 실제 UI에서는 StreamBuilder를 사용하여 이 데이터들을 구독하게 됩니다.
      // 여기서는 BLoC이 직접 데이터를 가지고 있기보다는,
      // 로딩/성공/실패 상태를 UI에 알려주는 역할에 집중합니다.
      // (만약 데이터를 BLoC 상태에 직접 담으려면 .listen()을 사용해야 합니다)

      // 지금은 간단히 로딩이 성공했다는 상태만 전달합니다.
      // UI(AccountingSectionPage)에서 StreamBuilder를 통해 서비스 함수를 직접 호출하여
      // 실시간 데이터를 표시하는 것이 더 효율적입니다.
      emit(const AccountingLoaded());

    } catch (e) {
      emit(AccountingError(e.toString())); // 오류 발생 시 에러 상태로 변경
    }
  }

  // 'ApproveReceipt' 이벤트 처리 핸들러
  Future<void> _onApproveReceipt(
    ApproveReceipt event,
    Emitter<AccountingState> emit,
  ) async {
    try {
      await _accountingService.approveReceipt(
        event.receipt,
        accountingSection: event.accountingSection,
        managerId: event.managerId,
        managerName: event.managerName,
        church: event.church,
      );
      // 성공적으로 처리되었음을 알리기 위해 이벤트를 다시 발생시켜 데이터를 새로고침 할 수 있습니다.
      add(LoadAccountingSectionData(sectionName: event.accountingSection));
    } catch (e) {
      emit(AccountingError("증빙 승인 중 오류가 발생했습니다: ${e.toString()}"));
    }
  }

  // ✨ [수정] 'RejectReceipt' 이벤트 핸들러
  Future<void> _onRejectReceipt(
    RejectReceipt event,
    Emitter<AccountingState> emit,
  ) async {
    try {
      // 수정된 서비스 함수 시그니처에 맞게 호출합니다.
      await _accountingService.rejectReceipt(
        event.receipt, // receiptId 대신 receipt 객체 전체를 전달
        church: event.church,
        reason: event.reason,
        managerName: event.managerName,
      );
    } catch (e) {
      emit(AccountingError("증빙 반려 중 오류가 발생했습니다: ${e.toString()}"));
    }
  }
}