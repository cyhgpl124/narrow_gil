import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:narrow_gil/features/schedule/view/widgets/add_event_dialog.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:narrow_gil/features/schedule/models/event_model.dart';
import 'package:narrow_gil/features/schedule/services/schedule_service.dart';
import 'package:narrow_gil/features/schedule/view/event_detail_page.dart';
import 'package:narrow_gil/features/schedule/view/widgets/add_event_dialog.dart';
import 'package:narrow_gil/home/bloc/home_bloc.dart';
import 'package:narrow_gil/home/models/user_profile.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final ScheduleService _scheduleService = ScheduleService();
  late UserProfile _userProfile;

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final homeState = context.read<HomeBloc>().state;
    if (homeState is HomeLoadSuccess) {
      _userProfile = homeState.userProfile;
    } else {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사용자 정보를 불러오는 데 실패했습니다.')),
      );
      return; // initState를 더 이상 진행하지 않음
    }
    _selectedDay = _focusedDay;
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
      _showAddEventDialog(selectedDay);
    }
  }

  void _showAddEventDialog(DateTime date) {
    showDialog(
      context: context,
      builder: (context) => AddEventDialog(
        selectedDate: date,
        onSave: (title, description) {
          final newEvent = Event(
            id: '',
            title: title,
            description: description,
            date: date,
            attendees: [],
          );
          _scheduleService.addEvent(_userProfile.church, newEvent);
        },
      ),
    );
  }

  Future<void> _uploadCsv() async {
    final result = await _scheduleService.uploadEventsFromCsv(_userProfile.church);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('교회 일정'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _uploadCsv,
            tooltip: 'CSV 파일로 일정 일괄 등록',
          )
        ],
      ),
      body: StreamBuilder<List<Event>>(
        stream: _scheduleService.getEventsForMonth(_userProfile.church, _focusedDay),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final events = snapshot.data!;
          // ✨✨✨ 여기가 수정된 부분입니다 ✨✨✨
          // 1. 비어있는 맵을 먼저 선언합니다.
          final Map<DateTime, List<Event>> eventsByDay = {};
          // 2. 반복문을 통해 이벤트를 날짜별로 맵에 추가합니다.
          for (final event in events) {
            final day = DateTime.utc(event.date.year, event.date.month, event.date.day);
            final existingEvents = eventsByDay[day] ?? [];
            eventsByDay[day] = existingEvents..add(event);
          }
          // ✨✨✨ 수정 끝 ✨✨✨

          List<Event> getEventsForDay(DateTime day) {
            return eventsByDay[DateTime.utc(day.year, day.month, day.day)] ?? [];
          }

          return Column(
            children: [
              TableCalendar<Event>(
                locale: 'ko_KR',
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: _onDaySelected,
                calendarFormat: _calendarFormat,
                onFormatChanged: (format) {
                  if (_calendarFormat != format) {
                    setState(() => _calendarFormat = format);
                  }
                },
                onPageChanged: (focusedDay) {
                  setState(() {
                     _focusedDay = focusedDay;
                     // 페이지 변경 시 selectedDay도 해당 월의 1일로 초기화
                     _selectedDay = DateTime(focusedDay.year, focusedDay.month, 1);
                  });
                },
                eventLoader: getEventsForDay,
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                    if (events.isNotEmpty) {
                      return Positioned(
                        right: 1,
                        bottom: 1,
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blueAccent,
                          ),
                          width: 16,
                          height: 16,
                          child: Center(
                            child: Text(
                              '${events.length}',
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ),
                        ),
                      );
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 8.0),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  "${DateFormat('MM월').format(_focusedDay)}의 일정 목록",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    events.sort((a, b) => a.date.compareTo(b.date));
                    final event = events[index];
                    return ListTile(
                      leading: Text(DateFormat('dd일').format(event.date)),
                      title: Text(event.title),
                      subtitle: Text('참석 ${event.attendees.length}명'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            // BlocProvider.value를 사용하여 기존 HomeBloc 인스턴스를 전달합니다.
                            builder: (_) => BlocProvider.value(
                              value: BlocProvider.of<HomeBloc>(context),
                              child: EventDetailPage(event: event),
                            ),
                          ),
                        );
                        // ✨✨✨ 수정 끝 ✨✨✨
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}