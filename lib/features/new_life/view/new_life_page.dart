import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:narrow_gil/features/new_life/bloc/new_life_bloc.dart';

class NewLifePage extends StatelessWidget {
  const NewLifePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => NewLifeBloc()..add(NewLifeDataRequested()),
      child: const NewLifeView(),
    );
  }
}

class NewLifeView extends StatelessWidget {
  const NewLifeView({super.key});

  // 체크리스트 항목을 NewLifeView의 상수로 이동
  static const List<String> _checklistItems = [
    "5시기도", "8시기도", "12시기도", "21시기도", "가정예배", "성경읽기",
    "청소", "체조운동", "폐품활용", "신발정돈", "소금물양치", "손씻기",
    "문단속", "불단속", "머리맡준비"
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('신생활'),
      ),
      body: BlocBuilder<NewLifeBloc, NewLifeState>(
        builder: (context, state) {
          if (state.status == NewLifeStatus.initial || (state.status == NewLifeStatus.loading && state.checkedItems.isEmpty)) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == NewLifeStatus.failure) {
            return Center(child: Text('오류: ${state.error}'));
          }

          return Column(
            children: [
              _WeekNavigator(
                focusedWeekStart: state.focusedWeekStart,
                onPreviousWeek: () => context.read<NewLifeBloc>().add(const NewLifeWeekChanged(isNextWeek: false)),
                onNextWeek: () => context.read<NewLifeBloc>().add(const NewLifeWeekChanged(isNextWeek: true)),
              ),
              _YearlyStatsCard(
                year: DateTime.now().year,
                count: state.yearlyCheckedDaysCount
              ),
              if (state.status == NewLifeStatus.loading)
                const LinearProgressIndicator(),
              Expanded(
                // SingleChildScrollView를 제거하고, _NewLifeTable이 자체적으로 스크롤을 처리하도록 변경
                child: _NewLifeTable(
                  weekStart: state.focusedWeekStart,
                  checklistItems: _checklistItems,
                  checkedItems: state.checkedItems,
                  onItemToggled: (day, item) => context.read<NewLifeBloc>().add(NewLifeItemToggled(day, item)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _YearlyStatsCard extends StatelessWidget {
  final int year;
  final int count;

  const _YearlyStatsCard({required this.year, required this.count});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today, color: Colors.blueAccent),
            const SizedBox(width: 16),
            Text(
              '$year년 실천한 날:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            Text(
              '$count일',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekNavigator extends StatelessWidget {
  final DateTime focusedWeekStart;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;

  const _WeekNavigator({
    required this.focusedWeekStart,
    required this.onPreviousWeek,
    required this.onNextWeek,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: onPreviousWeek,
          ),
          Text(
            '${DateFormat('MMMM dd', 'ko_KR').format(focusedWeekStart)} - ${DateFormat('MMMM dd', 'ko_KR').format(focusedWeekStart.add(const Duration(days: 6)))}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios),
            onPressed: onNextWeek,
          ),
        ],
      ),
    );
  }
}

class _NewLifeTable extends StatelessWidget {
  final DateTime weekStart;
  final List<String> checklistItems;
  final Map<DateTime, Map<String, bool>> checkedItems;
  final Function(DateTime, String) onItemToggled;

  // UI 상수를 정의하여 일관성 유지
  final double firstColumnWidth = 100.0;
  final double dataColumnWidth = 60.0;
  final double rowHeight = 48.0;
  final double headerHeight = 56.0;

  const _NewLifeTable({
    required this.weekStart,
    required this.checklistItems,
    required this.checkedItems,
    required this.onItemToggled,
  });

  @override
  Widget build(BuildContext context) {
    // 전체 테이블을 담는 컨테이너
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // 1. 고정된 첫 번째 열 (체크리스트 항목)
          SizedBox(
            width: firstColumnWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 날짜 헤더와 높이를 맞추기 위한 빈 공간
                SizedBox(height: headerHeight),
                // 체크리스트 항목 목록
                ...checklistItems.map((item) {
                  return Container(
                    height: rowHeight,
                    alignment: Alignment.centerLeft,
                    child: Text(item, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
              ],
            ),
          ),
          // 2. 가로로 스크롤되는 나머지 열 (날짜 및 체크 버튼)
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                // 전체 너비를 날짜 열의 개수에 맞게 설정
                width: dataColumnWidth * 7,
                child: Column(
                  children: [
                    // 날짜 헤더 행
                    SizedBox(
                      height: headerHeight,
                      child: Row(
                        children: List.generate(7, (index) {
                          return SizedBox(
                            width: dataColumnWidth,
                            child: Center(
                              child: Text(
                                DateFormat('E\ndd', 'ko_KR').format(weekStart.add(Duration(days: index))),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    // 체크 버튼 행들
                    ...checklistItems.map((item) {
                      return SizedBox(
                        height: rowHeight,
                        child: Row(
                          children: List.generate(7, (dayIndex) {
                            final day = weekStart.add(Duration(days: dayIndex));
                            final isChecked = checkedItems[day]?[item] ?? false;
                            return SizedBox(
                              width: dataColumnWidth,
                              child: Center(
                                child: _CheckButton(
                                  isChecked: isChecked,
                                  onTap: () => onItemToggled(day, item),
                                ),
                              ),
                            );
                          }),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckButton extends StatelessWidget {
  final bool isChecked;
  final VoidCallback onTap;

  const _CheckButton({
    required this.isChecked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15), // InkWell 효과가 원형으로 보이도록
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isChecked ? Colors.blue : Colors.grey.shade300,
        ),
        child: Center(
          child: isChecked
              ? const Icon(
                  Icons.check,
                  size: 20,
                  color: Colors.white,
                )
              : null,
        ),
      ),
    );
  }
}