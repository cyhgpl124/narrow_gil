import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:narrow_gil/features/attendance_check/bloc/attendance_check_bloc.dart';
import 'package:narrow_gil/features/attendance_check/models/attendance_status.dart';
import 'package:narrow_gil/features/attendance_check/view/attendance_stats_page.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:narrow_gil/home/bloc/home_bloc.dart'; // HomeBloc import 추가


class AttendanceCheckPage extends StatelessWidget {
  const AttendanceCheckPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AttendanceCheckBloc(
        // ✨ BlocProvider.of를 사용하여 현재 위젯 트리에서 HomeBloc을 찾아 전달합니다.
        homeBloc: BlocProvider.of<HomeBloc>(context),
      )..add(AttendanceDataRequested()),
      child: const AttendanceCheckView(),
    );
  }
}

class AttendanceCheckView extends StatelessWidget {
  const AttendanceCheckView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('출석 체크'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: '출석 통계',
            onPressed: () {
              // <<< ✨ [수정] 현재 상태에서 교회 이름과 선택된 월(focusedDay)을 가져옵니다.
              final state = context.read<AttendanceCheckBloc>().state;
              final selectedChurch = state.selectedChurch;
              final selectedDate = state.focusedDay; // <-- 활성화된 월
              if (selectedChurch.isNotEmpty) {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => AttendanceStatsPage(churchName: selectedChurch, selectedDate: selectedDate),
                ));
              }
            },
          ),
        ],
      ),
      body: BlocBuilder<AttendanceCheckBloc, AttendanceCheckState>(
        builder: (context, state) {
          if (state.status == BlocStatus.loading && state.attendanceRecords.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == BlocStatus.failure) {
            return Center(child: Text('오류 발생: ${state.error}'));
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                _ChurchSelector(),
                _MemberSelector(), // ✨ 멤버 선택 드롭다운 추가
                _AttendanceCalendar(),
                const SizedBox(height: 16),
                _AttendanceSummary(),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ChurchSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AttendanceCheckBloc, AttendanceCheckState>(
      // 상태(status) 변경에도 위젯이 재빌드되도록 buildWhen 조건 추가
      buildWhen: (p, c) =>
          p.selectedChurch != c.selectedChurch ||
          p.churchList != c.churchList ||
          p.status != c.status,
      builder: (context, state) {
        final bool isLoading = state.status == BlocStatus.loading;
        final bool isListEmpty = state.churchList.isEmpty;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: DropdownButtonFormField<String>(
            // 선택된 교회가 목록에 없을 경우 에러가 발생하므로, 목록에 있을 때만 value를 설정합니다.
            value: state.churchList.contains(state.selectedChurch)
                ? state.selectedChurch
                : null,
            decoration: InputDecoration(
              labelText: '출석 교회',
              border: const OutlineInputBorder(),
              // 로딩 중일 때 작은 인디케이터를 표시합니다.
              suffixIcon: isLoading && isListEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : null,
            ),
            hint: Text(isLoading
                ? '교회 목록 로딩 중...'
                : isListEmpty
                    ? '등록된 교회가 없습니다.'
                    : '교회를 선택해주세요'),
            // 로딩 중이거나 목록이 비어있으면 드롭다운을 비활성화합니다.
            items: state.churchList.map((church) {
              return DropdownMenuItem(value: church, child: Text(church));
            }).toList(),
            onChanged: isLoading || isListEmpty
                ? null
                : (value) {
                    if (value != null) {
                      context.read<AttendanceCheckBloc>().add(AttendanceChurchChanged(value));
                    }
                  },
          ),
        );
      },
    );
  }
}

// ✨======= [추가] 멤버 선택 드롭다운 위젯 =======✨
class _MemberSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AttendanceCheckBloc, AttendanceCheckState>(
      // ✨ 권한, 멤버 목록, 선택된 멤버가 변경될 때만 위젯을 다시 빌드합니다.
      buildWhen: (p, c) =>
          p.canCheckForOthers != c.canCheckForOthers ||
          p.memberList != c.memberList ||
          p.selectedMemberName != c.selectedMemberName,
      builder: (context, state) {
        // ✨ 대리 출석 체크 권한이 없으면 위젯을 숨깁니다.
        if (!state.canCheckForOthers) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 8.0),
          child: DropdownButtonFormField<String>(
            value: state.selectedMemberName,
            decoration: const InputDecoration(
              labelText: '출석 대상',
              border: OutlineInputBorder(),
            ),
            // ✨ 멤버 목록으로 드롭다운 아이템을 만듭니다.
            items: state.memberList.map((name) {
              return DropdownMenuItem(value: name, child: Text(name));
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                // ✨ 멤버가 변경되면 BLoC에 이벤트를 전달합니다.
                context.read<AttendanceCheckBloc>().add(AttendanceMemberChanged(value));
              }
            },
          ),
        );
      },
    );
  }
}
// ✨============================================✨

class _AttendanceCalendar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AttendanceCheckBloc>();
    return BlocBuilder<AttendanceCheckBloc, AttendanceCheckState>(
      buildWhen: (p, c) => p.focusedDay != c.focusedDay || p.attendanceRecords != c.attendanceRecords,
      builder: (context, state) {
        return TableCalendar(
          locale: 'ko_KR',
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: state.focusedDay,
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),
          onDaySelected: (selectedDay, focusedDay) {
            bloc.add(AttendanceDayTapped(DateTime.utc(selectedDay.year, selectedDay.month, selectedDay.day)));
          },
          selectedDayPredicate: (day) => isSameDay(state.focusedDay, day),
          onPageChanged: (focusedDay) {
            bloc.add(AttendanceMonthChanged(focusedDay));
          },
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, day, events) {
              final status = state.attendanceRecords[day];
              if (status == null || status == AttendanceStatus.none) return null;

              return Positioned(
                right: 1,
                bottom: 1,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _getColorForStatus(status),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _getMarkerTextForStatus(status),
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Color _getColorForStatus(AttendanceStatus status) => switch (status) {
      AttendanceStatus.present => Colors.green,
      AttendanceStatus.remote => Colors.orange,
      _ => Colors.transparent,
    };

  String _getMarkerTextForStatus(AttendanceStatus status) => switch (status) {
      AttendanceStatus.present => '출',
      AttendanceStatus.remote => '비',
      _ => '',
    };
}

class _AttendanceSummary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AttendanceCheckBloc, AttendanceCheckState>(
      buildWhen: (p, c) => p.attendanceRecords != c.attendanceRecords || p.focusedDay != c.focusedDay,
      builder: (context, state) {
        final monthName = DateFormat.MMMM('ko_KR').format(state.focusedDay);
        // ✨ 선택된 멤버의 이름을 표시하도록 수정
        final title = state.canCheckForOthers ? '${state.selectedMemberName} 님의 $monthName 출석 현황' : '$monthName 출석 현황';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$monthName 출석 현황', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _SummaryItem(color: Colors.green, label: '출석', count: state.presentCount),
                    _SummaryItem(color: Colors.orange, label: '비대면', count: state.remoteCount),
                    _SummaryItem(color: Colors.grey, label: '미출석', count: state.absentCount),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final Color color;
  final String label;
  final int count;

  const _SummaryItem({required this.color, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}