import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:narrow_gil/features/attendance_check/models/attendance_status.dart';
import 'package:narrow_gil/features/attendance_check/models/user_attendance.dart';
// Member 모델과 UserProfile 모델을 모두 사용합니다.
import 'package:narrow_gil/features/member_management/models/member_model.dart';
import 'package:narrow_gil/home/models/user_profile.dart';

part 'attendance_stats_event.dart';
part 'attendance_stats_state.dart';

class AttendanceStatsBloc
    extends Bloc<AttendanceStatsEvent, AttendanceStatsState> {
  final FirebaseFirestore _firestore;

  AttendanceStatsBloc({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        super(AttendanceStatsInitial()) {
    on<AttendanceStatsRequested>(_onStatsRequested);
  }

  /// 출석 통계 요청을 처리하는 메인 로직
  Future<void> _onStatsRequested(AttendanceStatsRequested event,
      Emitter<AttendanceStatsState> emit) async {
    emit(AttendanceStatsLoadInProgress());
    try {
      // 1. 현재 교회의 모든 교인 정보를 `approved_members`에서 가져옵니다.
      // 이것이 출석 통계의 기준이 되는 목록입니다.
      final membersSnapshot = await _firestore
          .collection('approved_members')
          .doc(event.churchName)
          .collection('members')
          .get();

      // 빠른 조회를 위해 교인 정보를 Map 형태로 변환합니다. (Key: 문서 ID, Value: Member 객체)
      final Map<String, Member> membersMap = {
        for (var doc in membersSnapshot.docs) doc.id: Member.fromFirestore(doc)
      };

      // 2. 현재 교회의 모든 출석 기록을 `churches` 컬렉션에서 가져옵니다.
      final attendanceCollection = await _firestore
          .collection('churches')
          .doc(event.churchName)
          .collection('attendance')
          .get();

      // 3. 출석 데이터를 가공하여 멤버별로 정리합니다.
      // (Key: 멤버 ID, Value: Map<날짜, 출석상태>)
      final Map<String, Map<DateTime, AttendanceStatus>> allAttendanceRecords =
          {};

      // 월별 출석 문서(예: '2025-07')를 순회합니다.
      for (var monthDoc in attendanceCollection.docs) {
        // 문서 ID(예: '2025-07')에서 연도와 월을 파싱합니다.
        final yearMonthParts = monthDoc.id.split('-');
        if (yearMonthParts.length != 2) continue; // 'yyyy-MM' 형식이 아니면 건너뜁니다.

        final year = int.tryParse(yearMonthParts[0]);
        final month = int.tryParse(yearMonthParts[1]);
        if (year == null || month == null) continue;

        final monthData = monthDoc.data();

        // 각 사용자(memberId)의 월간 출석 기록을 순회합니다.
        monthData.forEach((memberId, monthlyUserAttendance) {
          if (monthlyUserAttendance is Map) {
            // 한 사용자의 월간 출석 맵 (예: {'d1': 'present', 'd15': 'remote'})
            monthlyUserAttendance.forEach((dayKey, statusString) {
              if (dayKey is String && dayKey.startsWith('d')) {
                final day = int.tryParse(dayKey.substring(1));
                if (day != null) {
                  final date = DateTime.utc(year, month, day);

                  final status = AttendanceStatus.values.firstWhere(
                    (e) => e.name == statusString,
                    orElse: () => AttendanceStatus.none,
                  );

                  // 최종 맵에 기록 저장
                  (allAttendanceRecords[memberId] ??= {})[date] = status;
                }
              }
            });
          }
        });
      }

      // 4. 교인 목록에는 없지만 출석 기록에만 있는 사람들을 처리합니다.
      final Set<String> attendeeIds = allAttendanceRecords.keys.toSet();
      final Set<String> memberIds = membersMap.keys.toSet();
      final Set<String> nonMemberAttendeeIds =
          attendeeIds.difference(memberIds);

      if (nonMemberAttendeeIds.isNotEmpty) {
        // 비회원 출석자들의 정보를 'users' 컬렉션에서 가져옵니다.
        // Firestore 'in' 쿼리는 30개로 제한되므로 데이터를 나눠서(chunk) 처리합니다.
        for (var i = 0; i < nonMemberAttendeeIds.length; i += 30) {
          final chunk = nonMemberAttendeeIds.toList().sublist(
              i,
              i + 30 > nonMemberAttendeeIds.length
                  ? nonMemberAttendeeIds.length
                  : i + 30);

          if (chunk.isNotEmpty) {
            // <<< 🚀 [수정] 쿼리 조건을 추가하여 현재 교회 소속 교인은 제외합니다. 🚀 >>>
            // users 컬렉션에서 문서를 가져올 때,
            // 1. 출석은 했지만 교인 명단에는 없는 사람(chunk) 중에서
            // 2. 소속교회(church 필드)가 현재 통계를 보고 있는 교회(event.churchName)가 아닌 사람만 조회
            final nonMembersSnapshot = await _firestore
                .collection('users')
                .where(FieldPath.documentId, whereIn: chunk)
                .where('church', isNotEqualTo: event.churchName) // <-- 이 조건 추가
                .get();
            // <<< 🚀 [수정] 여기까지 🚀 >>>

            // 가져온 비회원 정보를 임시 Member 객체로 만들어 기존 교인 맵에 추가합니다.
            for (var doc in nonMembersSnapshot.docs) {
              final userData = doc.data();
              membersMap[doc.id] = Member(
                id: doc.id,
                name: userData['name'] ?? '방문자',
                phoneNumber: userData['phoneNumber'] ?? '',
                district: userData['church'] ?? '', // district은 임시로 교회 이름 사용
                role: '방문자',
                gender: '', // 성별 정보가 없으므로 빈 값 처리
                heavenlyScore: 0,
                baptismDate: '010101',
                houseHoldHead: '',
                donation: 0,
              );
            }
          }
        }
      }

      // 5. users 컬렉션에서 추가 정보(생년월일, 이메일)를 가져옵니다.
      final Map<String, Map<String, dynamic>> usersDataMap = {};
      final allMemberIds = membersMap.keys.toList();

      // Firestore 'in' 쿼리 제한(30개)에 맞춰 데이터를 나눠서 가져옵니다.
      for (var i = 0; i < allMemberIds.length; i += 30) {
        final chunk = allMemberIds.sublist(
            i, i + 30 > allMemberIds.length ? allMemberIds.length : i + 30);

        if (chunk.isNotEmpty) {
          final usersSnapshot = await _firestore
              .collection('users')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();

          // 가져온 데이터를 memberId(uid)를 키로 하는 맵에 저장합니다.
          for (var doc in usersSnapshot.docs) {
            usersDataMap[doc.id] = doc.data();
          }
        }
      }

      // 5. 최종적으로 표시할 UserAttendance 목록을 생성합니다.
      List<UserAttendance> userAttendances = membersMap.entries.map((entry) {
        final memberId = entry.key;
        final member = entry.value;
        // 미리 가져온 users 컬렉션의 데이터를 조회합니다.
        final userData = usersDataMap[memberId];

        // UI 표시에 필요한 UserProfile 객체를 Member 데이터 기반으로 생성합니다.
        final userProfile = UserProfile(
          birthdate: userData?['birthdate'] as String? ?? '',
          uid: memberId,
          name: member.name,
          phoneNumber: member.phoneNumber,
          church: event.churchName,
          houseHoldHead: member.houseHoldHead,
          email:
              userData?['email'] as String? ?? '', // Member 모델에 없는 정보는 빈 값으로 처리
        );

        // 최종 UserAttendance 객체를 생성합니다.
        return UserAttendance(
          user: userProfile,
          district: member.district,
          baptismInfo: member.baptismDate, // 세례 정보
          attendanceRecords:
              allAttendanceRecords[memberId] ?? {}, // 해당 멤버의 출석 기록
        );
      }).toList();

      // 6. 구역 순서에 따라 정렬합니다.
      final churchDoc =
          await _firestore.collection('churches').doc(event.churchName).get();
      final districtOrder = (churchDoc.data()?['구역'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      userAttendances.sort((a, b) {
        int districtIndexA =
            a.district != null ? districtOrder.indexOf(a.district!) : -1;
        int districtIndexB =
            b.district != null ? districtOrder.indexOf(b.district!) : -1;

        // 구역 순서가 다르면 구역 순서로 정렬
        if (districtIndexA != districtIndexB)
          return districtIndexA.compareTo(districtIndexB);
        // 구역이 같으면 이름 순으로 정렬
        return a.user.name.compareTo(b.user.name);
      });

      // 7. 세례 번호를 부여합니다.
      int baptismCounter = 1;
      final finalUserAttendances = userAttendances.map((ua) {
        if (ua.baptismInfo != null && ua.baptismInfo!.isNotEmpty) {
          return ua.copyWith(baptismNumber: baptismCounter++);
        }
        return ua;
      }).toList();

      // 8. 성공 상태와 함께 최종 데이터를 UI로 전달합니다.
      emit(AttendanceStatsLoadSuccess(finalUserAttendances));
    } catch (e) {
      // 오류 발생 시 실패 상태를 전달합니다.
      emit(AttendanceStatsLoadFailure(e.toString()));
    }
  }

  // 참고: 기존의 _fetchAllAttendance, _fetchAttendanceRecordsForUser 메서드는
  // 위의 _onStatsRequested 로직에 모두 통합되었으므로 더 이상 필요하지 않습니다.
}
