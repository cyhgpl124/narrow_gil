part of 'new_life_bloc.dart';


enum NewLifeStatus { initial, loading, success, failure }

class NewLifeState extends Equatable {
  final NewLifeStatus status;
  final DateTime focusedWeekStart;
  final Map<DateTime, Map<String, bool>> checkedItems;
  final String? error;
  final UserProfile? userProfile;
  final int yearlyCheckedDaysCount;

  const NewLifeState({
    this.status = NewLifeStatus.initial,
    required this.focusedWeekStart,
    this.checkedItems = const {},
    this.error,
    this.userProfile,
    this.yearlyCheckedDaysCount = 0,
  });

  factory NewLifeState.initial() {
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    // Monday is 1, Sunday is 7. We want to find the Monday of the week.
    return NewLifeState(
      focusedWeekStart: today.subtract(Duration(days: today.weekday - 1)),
    );
  }

  NewLifeState copyWith({
    NewLifeStatus? status,
    DateTime? focusedWeekStart,
    Map<DateTime, Map<String, bool>>? checkedItems,
    String? error,
    UserProfile? userProfile,
    int? yearlyCheckedDaysCount,
  }) {
    return NewLifeState(
      status: status ?? this.status,
      focusedWeekStart: focusedWeekStart ?? this.focusedWeekStart,
      checkedItems: checkedItems ?? this.checkedItems,
      error: error ?? this.error,
      userProfile: userProfile ?? this.userProfile,
      yearlyCheckedDaysCount: yearlyCheckedDaysCount ?? this.yearlyCheckedDaysCount,
    );
  }

  @override
  List<Object?> get props => [
        status, focusedWeekStart, checkedItems, error, userProfile, yearlyCheckedDaysCount
      ];
}
