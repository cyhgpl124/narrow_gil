// lib/features/schedule/view/event_detail_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:narrow_gil/features/schedule/models/event_model.dart';
import 'package:narrow_gil/features/schedule/services/schedule_service.dart';
import 'package:narrow_gil/home/bloc/home_bloc.dart';

class EventDetailPage extends StatefulWidget {
  final Event event;

  const EventDetailPage({super.key, required this.event});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  late Event _currentEvent;
  final ScheduleService _scheduleService = ScheduleService();
  bool _isAttending = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentEvent = widget.event;
    final homeState = context.read<HomeBloc>().state;
    if (homeState is HomeLoadSuccess) {
      _isAttending = _currentEvent.attendees.contains(homeState.userProfile.name);
    }
  }

  Future<void> _toggleAttendance() async {
    setState(() => _isLoading = true);
    final homeState = context.read<HomeBloc>().state;
    if (homeState is! HomeLoadSuccess) {
      setState(() => _isLoading = false);
      return;
    }

    final userProfile = homeState.userProfile;

    try {
      if (!_isAttending) {
        await _scheduleService.addAttendee(userProfile.church, _currentEvent.id, userProfile.name);
        setState(() {
          _currentEvent.attendees.add(userProfile.name);
          _isAttending = true;
        });
      }
      // 현재 디자인에서는 참석 취소 기능은 제외합니다.
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류 발생: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentEvent.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(_currentEvent.date),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '세부 내용',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _currentEvent.description ?? '입력된 세부 내용이 없습니다.',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade300),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '참석자 명단',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                 Text('${_currentEvent.attendees.length}명 참석'),
              ],
            ),
            const Divider(height: 20),
            Expanded(
              child: _currentEvent.attendees.isEmpty
                  ? const Center(child: Text('아직 참석자가 없습니다.'))
                  : ListView.builder(
                      itemCount: _currentEvent.attendees.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(_currentEvent.attendees[index]),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            if (!_isAttending)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _toggleAttendance,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: const Text('참석하기'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              )
            else
               const Center(child: Text("참석 완료되었습니다.", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),))
          ],
        ),
      ),
    );
  }
}