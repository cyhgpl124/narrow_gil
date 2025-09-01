import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:narrow_gil/home/models/user_profile.dart';
import 'package:narrow_gil/features/user/user_service.dart'; // ✨ [추가] UserService import

part 'new_life_event.dart';
part 'new_life_state.dart';

class NewLifeBloc extends Bloc<NewLifeEvent, NewLifeState> {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final UserService _userService; // ✨ [추가] UserService 인스턴스

  NewLifeBloc({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore, UserService? userService, // ✨ [추가] 생성자에서 UserService를 받을 수 있도록 수정
    }): _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _userService = userService ?? UserService(), // ✨ [추가] UserService 초기화
        super(NewLifeState.initial()) {
    on<NewLifeDataRequested>(_onDataRequested);
    on<NewLifeWeekChanged>(_onWeekChanged);
    on<NewLifeItemToggled>(_onItemToggled);
  }

  String? get _userId => _firebaseAuth.currentUser?.uid;

  Future<void> _onDataRequested(
      NewLifeDataRequested event, Emitter<NewLifeState> emit) async {
    if (_userId == null) {
      emit(state.copyWith(
          status: NewLifeStatus.failure, error: "User not logged in."));
      return;
    }
    emit(state.copyWith(status: NewLifeStatus.loading));
    try {
      final userDoc = await _firestore.collection('users').doc(_userId).get();
      if (!userDoc.exists) throw Exception('User profile not found.');
      final userProfile = UserProfile.fromFirestore(userDoc.data()!, _userId!);

      final results = await Future.wait([
        _fetchDataForWeek(state.focusedWeekStart),
        _fetchYearlyStats(),
      ]);

      final checkedItems = results[0] as Map<DateTime, Map<String, bool>>;
      final yearlyCount = results[1] as int;

      emit(state.copyWith(
        status: NewLifeStatus.success,
        checkedItems: checkedItems,
        userProfile: userProfile,
        yearlyCheckedDaysCount: yearlyCount,
      ));
    } catch (e) {
      emit(state.copyWith(status: NewLifeStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onWeekChanged(
      NewLifeWeekChanged event, Emitter<NewLifeState> emit) async {
    final newWeekStart = event.isNextWeek
        ? state.focusedWeekStart.add(const Duration(days: 7))
        : state.focusedWeekStart.subtract(const Duration(days: 7));

    emit(state.copyWith(
      status: NewLifeStatus.loading,
      focusedWeekStart: newWeekStart,
    ));

    try {
      final checkedItems = await _fetchDataForWeek(newWeekStart);
      emit(state.copyWith(
        status: NewLifeStatus.success,
        checkedItems: checkedItems,
      ));
    } catch (e) {
      emit(state.copyWith(status: NewLifeStatus.failure, error: e.toString()));
    }
  }

  // ✨ [수정] 점수 및 로그 기록 로직을 UserService를 사용하도록 변경
  Future<void> _onItemToggled(
      NewLifeItemToggled event, Emitter<NewLifeState> emit) async {
    // 사용자 ID나 프로필 정보가 없으면 함수를 종료합니다.
    if (_userId == null || state.userProfile == null) return;

    final day = event.day;
    final item = event.item;
    final docId = DateFormat('yyyy-MM').format(day);
    final dayKey = 'd${day.day}';

    final currentCheckedStatus = state.checkedItems[day]?[item] ?? false;
    final newCheckedStatus = !currentCheckedStatus;

    // 점수 변경을 계산하기 위해 토글 전후의 상태를 확인합니다.
    final dayChecksBefore = state.checkedItems[day] ?? {};
    final wasDayUnchecked = dayChecksBefore.values.every((v) => v == false);

    // UI에 즉시 변경사항을 반영(Optimistic Update)합니다.
    final newCheckedItems =
        Map<DateTime, Map<String, bool>>.from(state.checkedItems);
    newCheckedItems[day] = Map<String, bool>.from(newCheckedItems[day] ?? {});
    newCheckedItems[day]![item] = newCheckedStatus;
    emit(state.copyWith(checkedItems: newCheckedItems));

    final dayChecksAfter = newCheckedItems[day] ?? {};
    final isDayNowUnchecked = dayChecksAfter.values.every((v) => v == false);

    int scoreChange = 0;
    // 점수 증가 조건: 해당 날짜에 체크된 항목이 없다가 새로 체크된 경우
    if (wasDayUnchecked && !isDayNowUnchecked) {
      scoreChange = 1;
    // 점수 감소 조건: 해당 날짜의 모든 항목이 체크 해제된 경우
    } else if (!wasDayUnchecked && isDayNowUnchecked) {
      scoreChange = -1;
    }

    // 연간 통계 UI를 즉시 업데이트합니다.
    if (scoreChange != 0) {
      emit(state.copyWith(
          yearlyCheckedDaysCount: state.yearlyCheckedDaysCount + scoreChange));
    }

    try {
      // 1. Firestore에 체크 상태를 먼저 업데이트합니다.
      final docRef = _firestore
          .collection('users')
          .doc(_userId)
          .collection('new_life')
          .doc(docId);

      await docRef.set(
        {
          dayKey: {item: newCheckedStatus}
        },
        SetOptions(merge: true),
      );

      // ✨ [수정] 2. 점수가 변경되었을 경우, UserService를 통해 점수 업데이트와 로그 기록을 동시에 처리합니다.
      if (scoreChange != 0) {
        // reason에 'MM/dd' 형식의 날짜를 포함시킵니다.
        final dateString = DateFormat('MM/dd').format(day);
        final reason = scoreChange > 0 ? "$dateString 신생활 실천" : "$dateString 신생활 실천 취소";

        await _userService.addSkyScore(
          userId: _userId!,
          church: state.userProfile!.church,
          reason: reason,
          score: scoreChange,
        );
      }
    } catch (e) {
      // 오류 발생 시, UI 상태를 원래대로 되돌립니다.
      final revertedCheckedItems =
          Map<DateTime, Map<String, bool>>.from(state.checkedItems);
      revertedCheckedItems[day] =
          Map<String, bool>.from(revertedCheckedItems[day] ?? {});
      revertedCheckedItems[day]![item] = currentCheckedStatus;
      emit(state.copyWith(
        yearlyCheckedDaysCount: scoreChange != 0
            ? state.yearlyCheckedDaysCount - scoreChange
            : state.yearlyCheckedDaysCount,
        checkedItems: revertedCheckedItems,
        status: NewLifeStatus.failure,
        error: "Failed to update: ${e.toString()}",
      ));
      // 데이터 동기화를 위해 전체 데이터를 다시 요청합니다.
      add(NewLifeDataRequested());
    }
  }

  // ✨ [수정] '올해' 실천 일수를 계산하도록 로직 변경
  Future<int> _fetchYearlyStats() async {
    if (_userId == null) return 0;

    final now = DateTime.now();
    final checkedDays = <String>{};

    // ✨ [수정] 지난 12개월이 아닌, 올해 1월부터 현재 월까지 반복합니다.
    for (int month = 1; month <= now.month; month++) {
      final monthToFetch = DateTime.utc(now.year, month, 1);
      final docId = DateFormat('yyyy-MM').format(monthToFetch);

      final docSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('new_life')
          .doc(docId)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        data.forEach((dayKey, items) {
          if (dayKey.startsWith('d') &&
              (items as Map).values.any((checked) => checked == true)) {
            final dayNum = int.tryParse(dayKey.substring(1));
            if (dayNum != null) {
              try {
                final date =
                    DateTime.utc(monthToFetch.year, monthToFetch.month, dayNum);
                checkedDays.add(DateFormat('yyyy-MM-dd').format(date));
              } catch (e) {
                // Ignore invalid dates
              }
            }
          }
        });
      }
    }
    return checkedDays.length;
  }

  Future<Map<DateTime, Map<String, bool>>> _fetchDataForWeek(
      DateTime weekStart) async {
    if (_userId == null) return {};

    final weekEnd = weekStart.add(const Duration(days: 6));
    final checkedItems = <DateTime, Map<String, bool>>{};

    final monthsToFetch = <String>{};
    monthsToFetch.add(DateFormat('yyyy-MM').format(weekStart));
    monthsToFetch.add(DateFormat('yyyy-MM').format(weekEnd));

    for (final monthDocId in monthsToFetch) {
      final docSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('new_life')
          .doc(monthDocId)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        data.forEach((dayKey, items) {
          if (dayKey.startsWith('d')) {
            final dayNum = int.tryParse(dayKey.substring(1));
            final year = int.parse(monthDocId.substring(0, 4));
            final month = int.parse(monthDocId.substring(5, 7));
            if (dayNum != null) {
              final date = DateTime.utc(year, month, dayNum);
              if (!date.isBefore(weekStart) && !date.isAfter(weekEnd)) {
                checkedItems[date] = Map<String, bool>.from(items);
              }
            }
          }
        });
      }
    }
    return checkedItems;
  }
}
