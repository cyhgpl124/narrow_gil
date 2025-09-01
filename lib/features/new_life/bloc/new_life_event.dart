part of 'new_life_bloc.dart';

abstract class NewLifeEvent extends Equatable {
  const NewLifeEvent();

  @override
  List<Object> get props => [];
}

class NewLifeDataRequested extends NewLifeEvent {}

class NewLifeWeekChanged extends NewLifeEvent {
  final bool isNextWeek;
  const NewLifeWeekChanged({required this.isNextWeek});

  @override
  List<Object> get props => [isNextWeek];
}

class NewLifeItemToggled extends NewLifeEvent {
  final DateTime day;
  final String item;

  const NewLifeItemToggled(this.day, this.item);

  @override
  List<Object> get props => [day, item];
}