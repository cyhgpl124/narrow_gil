import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:narrow_gil/features/attendance_check/models/attendance_status.dart';
import 'package:narrow_gil/home/bloc/home_bloc.dart';
import 'package:narrow_gil/home/models/user_profile.dart';
import 'package:narrow_gil/features/user/user_service.dart'; // ✨ [추가] UserService import


part 'attendance_check_event.dart';
part 'attendance_check_state.dart';

class AttendanceCheckBloc extends Bloc<AttendanceCheckEvent, AttendanceCheckState> {
  final HomeBloc _homeBloc;
  final FirebaseFirestore _firestore;
  final UserService _userService; // ✨ [추가] UserService 인스턴스

  AttendanceCheckBloc({
    FirebaseFirestore? firestore,
    UserService? userService, // ✨ [추가] 생성자에서 UserService를 받을 수 있도록 수정
    required HomeBloc homeBloc,
  })  : _homeBloc = homeBloc,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _userService = userService ?? UserService(), // ✨ [추가] UserService 초기화
        // ✨ 상태 초기값에 현재 사용자 이름을 설정합니다.
        super(AttendanceCheckState(
          focusedDay: DateTime.now(),
          selectedMemberName: (homeBloc.state is HomeLoadSuccess)
              ? (homeBloc.state as HomeLoadSuccess).userProfile.name
              : '',
        )) {
    on<AttendanceDataRequested>(_onDataRequested);
    on<AttendanceMonthChanged>(_onMonthChanged);
    on<AttendanceDayTapped>(_onDayTapped);
    on<AttendanceChurchChanged>(_onChurchChanged);
    on<AttendanceMemberChanged>(_onMemberChanged); // ✨ 새 이벤트 핸들러 등록
  }


  // ✨ [수정] 현재 로그인한 사용자의 정보를 안전하게 가져옵니다.
  UserProfile? get _currentUser {
    final homeState = _homeBloc.state;
    if (homeState is HomeLoadSuccess) {
      return homeState.userProfile;
    }
    return null;
  }

  // ✨ 데이터 요청 시, 교회 목록과 현재 선택된 교회의 멤버 및 출석 데이터를 가져옵니다.
  Future<void> _onDataRequested(
    AttendanceDataRequested event,
    Emitter<AttendanceCheckState> emit,
  ) async {
    emit(state.copyWith(status: BlocStatus.loading));
    try {
      if (_currentUser == null) throw Exception('User not found');

      final churchesSnapshot = await _firestore.collection('churches').get();
      final churchList = churchesSnapshot.docs.map((doc) => doc.id).toList()..sort();
      final initialChurch = _currentUser!.church;

      emit(state.copyWith(
        status: BlocStatus.success,
        userProfile: _currentUser,
        churchList: churchList,
        selectedChurch: initialChurch,
      ));

      // ✨ 교회 데이터 로드 로직을 호출합니다.
      await _fetchDataForSelectedChurch(initialChurch, emit);
    } catch (e) {
      emit(state.copyWith(status: BlocStatus.failure, error: e.toString()));
    }
  }

  // ✨ 교회 선택 변경 시, 해당 교회의 멤버 및 출석 데이터를 다시 가져옵니다.
  Future<void> _onChurchChanged(
    AttendanceChurchChanged event,
    Emitter<AttendanceCheckState> emit,
  ) async {
    emit(state.copyWith(status: BlocStatus.loading, selectedChurch: event.church));
    await _fetchDataForSelectedChurch(event.church, emit);
  }

  // ✨ 멤버 선택 변경 시, 해당 멤버의 출석 데이터를 다시 가져옵니다.
  Future<void> _onMemberChanged(
    AttendanceMemberChanged event,
    Emitter<AttendanceCheckState> emit,
  ) async {
    emit(state.copyWith(status: BlocStatus.loading, selectedMemberName: event.selectedName));
    await _fetchAttendanceForSelectedMember(emit);
  }

  // ✨ 월 변경 시, 해당 월의 출석 데이터를 다시 가져옵니다.
  Future<void> _onMonthChanged(
    AttendanceMonthChanged event,
    Emitter<AttendanceCheckState> emit,
  ) async {
    emit(state.copyWith(status: BlocStatus.loading, focusedDay: event.focusedDay));
    await _fetchAttendanceForSelectedMember(emit);
  }

  // ✨ 날짜를 탭하여 출석 상태를 변경하는 로직
  Future<void> _onDayTapped(
    AttendanceDayTapped event,
    Emitter<AttendanceCheckState> emit,
  ) async {
    final selectedName = state.selectedMemberName;
    final selectedUid = state.allMembers[selectedName];

    // ✨ 선택된 멤버의 UID가 없으면 로직을 중단합니다.
    if (selectedUid == null) return;

    final day = event.day;
    final currentStatus = state.attendanceRecords[day] ?? AttendanceStatus.none;

    final nextStatus = switch (currentStatus) {
      AttendanceStatus.none => AttendanceStatus.present,
      AttendanceStatus.present => AttendanceStatus.remote,
      AttendanceStatus.remote => AttendanceStatus.none,
    };

    final docId = DateFormat('yyyy-MM').format(day);
    final dayKey = 'd${day.day}';
    final churchAttendanceRef = _firestore
        .collection('churches')
        .doc(state.selectedChurch)
        .collection('attendance')
        .doc(docId);

    try {
      // ✨ Firestore에 '선택된 멤버'의 출석 상태를 업데이트합니다.
      await churchAttendanceRef.set({
        selectedUid: {dayKey: nextStatus.name}
      }, SetOptions(merge: true));

      await _updateSkyScore(selectedUid, currentStatus, nextStatus, day);

      final updatedRecords = Map<DateTime, AttendanceStatus>.from(state.attendanceRecords);
      if (nextStatus == AttendanceStatus.none) {
        updatedRecords.remove(day);
      } else {
        updatedRecords[day] = nextStatus;
      }
      emit(state.copyWith(attendanceRecords: updatedRecords, status: BlocStatus.success));
    } catch (e) {
      emit(state.copyWith(status: BlocStatus.failure, error: e.toString()));
    }
  }

  // --- Helper Methods ---

  // ✨ 선택된 교회의 데이터를 가져오는 헬퍼 메서드
  Future<void> _fetchDataForSelectedChurch(String churchId, Emitter<AttendanceCheckState> emit) async {
    if (_currentUser == null) return;

    final memberDoc = await _firestore.collection('approved_members').doc(churchId).collection('members').doc(_currentUser!.uid).get();
    final userRole = memberDoc.data()?['role'] as String? ?? '';
    final canCheckForOthers = ['개발자', '목회자', '회계', '서기'].contains(userRole);

    if (canCheckForOthers) {
      final membersSnapshot = await _firestore.collection('approved_members').doc(churchId).collection('members').get();
      final Map<String, String> allMembers = {};
      for (var doc in membersSnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('name') && data['name'] != null) {
          allMembers[data['name']] = doc.id;
        }
      }
      final memberList = allMembers.keys.toList()..sort();
      emit(state.copyWith(
        canCheckForOthers: true,
        memberList: memberList,
        allMembers: allMembers,
        selectedMemberName: _currentUser!.name, // 기본값은 항상 현재 사용자
      ));
    } else {
      emit(state.copyWith(
        canCheckForOthers: false,
        memberList: [_currentUser!.name],
        allMembers: {_currentUser!.name: _currentUser!.uid},
        selectedMemberName: _currentUser!.name,
      ));
    }

    await _fetchAttendanceForSelectedMember(emit);
  }

  // ✨ 선택된 멤버의 출석 기록을 불러오는 헬퍼 메서드
  Future<void> _fetchAttendanceForSelectedMember(Emitter<AttendanceCheckState> emit) async {
    final selectedName = state.selectedMemberName;
    final selectedUid = state.allMembers[selectedName];

    if (selectedUid == null || state.selectedChurch.isEmpty) {
        emit(state.copyWith(status: BlocStatus.success, attendanceRecords: {}));
        return;
    }

    try {
      final records = await _fetchAttendanceForMonth(state.focusedDay, state.selectedChurch, selectedUid);
      emit(state.copyWith(status: BlocStatus.success, attendanceRecords: records));
    } catch (e) {
      emit(state.copyWith(status: BlocStatus.failure, error: e.toString()));
    }
  }

  // ✨ 특정 멤버/월의 출석 데이터를 Firestore에서 가져오는 메서드
  Future<Map<DateTime, AttendanceStatus>> _fetchAttendanceForMonth(DateTime month, String church, String userId) async {
    final docId = DateFormat('yyyy-MM').format(month);
    final doc = await _firestore.collection('churches').doc(church).collection('attendance').doc(docId).get();

    final records = <DateTime, AttendanceStatus>{};
    if (doc.exists) {
      final data = doc.data();
      if (data != null && data.containsKey(userId)) {
        final userAttendance = data[userId] as Map<String, dynamic>?;
        userAttendance?.forEach((key, value) {
          if (key.startsWith('d')) {
            final day = int.tryParse(key.substring(1));
            final status = AttendanceStatus.values.firstWhere((e) => e.name == value, orElse: () => AttendanceStatus.none);
            if (day != null && status != AttendanceStatus.none) {
              records[DateTime.utc(month.year, month.month, day)] = status;
            }
          }
        });
      }
    }
    return records;
  }

  // ✨ [수정] 점수 업데이트 함수가 날짜(day)를 인자로 받도록 변경
  Future<void> _updateSkyScore(String userId, AttendanceStatus current, AttendanceStatus next, DateTime day) async {
    final bool shouldIncrement = current == AttendanceStatus.none && (next == AttendanceStatus.present || next == AttendanceStatus.remote);
    final bool shouldDecrement = (current == AttendanceStatus.present || current == AttendanceStatus.remote) && next == AttendanceStatus.none;

    if (shouldIncrement || shouldDecrement) {
      final scoreChange = shouldIncrement ? 1 : -1;
      // ✨ [수정] reason 문자열에 날짜를 포함시킵니다.
      final dateString = DateFormat('MM/dd').format(day);
      final reason = shouldIncrement ? "$dateString 출석체크" : "$dateString 출석 취소";

      try {
        await _userService.addSkyScore(
            userId: userId,
            church: state.selectedChurch,
            reason: reason,
            score: scoreChange,
        );

        if (userId == _currentUser?.uid) {
          _homeBloc.add(HomeProfileRefreshed());
        }
      } catch (e) {
        debugPrint("점수 업데이트 및 로그 기록 실패: $e");
      }
    }
  }
}