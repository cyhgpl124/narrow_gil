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
              // ✨ YearlyStatsCard에 현재 연도를 전달합니다.
              _YearlyStatsCard(
                year: DateTime.now().year,
                count: state.yearlyCheckedDaysCount
              ),
              if (state.status == NewLifeStatus.loading)
                const LinearProgressIndicator(),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _NewLifeTable(
                      weekStart: state.focusedWeekStart,
                      checklistItems: _checklistItems,
                      checkedItems: state.checkedItems,
                      onItemToggled: (day, item) => context.read<NewLifeBloc>().add(NewLifeItemToggled(day, item)),
                    ),
                  ),
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
            // ✨ [수정] 텍스트를 '올해' 기준으로 변경하고, 연도를 표시합니다.
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

  const _NewLifeTable({
    required this.weekStart,
    required this.checklistItems,
    required this.checkedItems,
    required this.onItemToggled,
  });

  @override
  Widget build(BuildContext context) {
    return DataTable(
      columns: [
        const DataColumn(label: Text('')), // Empty column for checklist items
        ...List.generate(
          7,
          (index) => DataColumn(
            label: Text(
              DateFormat('E\ndd', 'ko_KR').format(weekStart.add(Duration(days: index))),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
      rows: checklistItems.map((item) {
        return DataRow(
          cells: [
            DataCell(Text(item)),
            ...List.generate(7, (dayIndex) {
              final day = weekStart.add(Duration(days: dayIndex));
              final isChecked = checkedItems[day]?[item] ?? false;
              return DataCell(
                _CheckButton(
                  isChecked: isChecked,
                  onTap: () => onItemToggled(day, item),
                ),
              );
            }),
          ],
        );
      }).toList(),
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
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isChecked ? Colors.blue : Colors.grey.shade200,
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