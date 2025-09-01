// lib/features/events/view/events_list_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:narrow_gil/features/events/models/event_model.dart';
import 'package:narrow_gil/features/events/services/event_service.dart';
import 'package:narrow_gil/features/events/view/event_detail_page.dart';
import 'package:narrow_gil/home/bloc/home_bloc.dart';
import 'package:flutter/foundation.dart';

class EventsListPage extends StatefulWidget {
  const EventsListPage({super.key});

  @override
  State<EventsListPage> createState() => _EventsListPageState();
}

class _EventsListPageState extends State<EventsListPage> {
  final EventService _eventService = EventService();
  // ✨ [추가] 필터 관련 상태 변수
  List<String> _churchList = [];
  String? _selectedChurchFilter;
  String? _selectedFilter;
  int _selectedYearFilter = DateTime.now().year; // ✨ [추가] 연도 필터, 기본값은 올해
  final List<int> _yearList = List.generate(20, (index) => DateTime.now().year - index); // ✨ [추가] 최근 20년간의 연도 목록
  // ✨ [추가] Stream을 상태 변수로 관리하여 필터 변경 시 명확하게 교체하도록 합니다.
  late Stream<List<EventModel>> _eventsStream;

  @override
  void initState() {
    super.initState();
    // ✨ [수정] 위젯이 처음 생성될 때, 초기 필터값으로 스트림을 설정합니다.
    // 아직 필터 값이 없으므로, 초기는 비어있는 스트림으로 시작합니다.
    _eventsStream = Stream.value([]);

    // 교회 목록을 가져온 후, 사용자의 교회로 기본 필터를 설정하고 스트림을 업데이트합니다.
    _fetchChurchList().then((_) {
      final homeState = context.read<HomeBloc>().state;
      if (mounted && homeState is HomeLoadSuccess) {
        setState(() {
          _selectedChurchFilter = homeState.userProfile.church;
          _selectedYearFilter = DateTime.now().year;

        });
        // ✨ 필터 값이 설정되었으므로, 실제 데이터를 가져오는 스트림으로 교체합니다.
        _updateStream();
      }
    });
  }

  // ✨ [추가] 현재 필터 값에 따라 새로운 스트림을 생성하고 상태를 업데이트하는 함수
  void _updateStream() {
    setState(() {
      _eventsStream = _eventService.getEvents(
        churchName: _selectedChurchFilter,
        year: _selectedYearFilter,
      );
    });
  }
  // ✨ [추가] Firestore에서 교회 목록을 가져오는 함수
  Future<void> _fetchChurchList() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('churches').get();
      final churches = snapshot.docs.map((doc) => doc.id).toList()..sort();
      if (mounted) {
        setState(() {
          _churchList = ['전체', ...churches];
        });
      }
    } catch (e) {
      // 오류 처리
    }
  }

  void _showAddEventDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final homeState = context.read<HomeBloc>().state;
    if (homeState is! HomeLoadSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사용자 정보를 불러올 수 없어 행사를 생성할 수 없습니다.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        // --- ▼ [수정] BlocProvider.value로 AlertDialog를 감싸 HomeBloc 전달 ▼ ---
        return BlocProvider.value(
          value: BlocProvider.of<HomeBloc>(context),
          child: AlertDialog(
            title: const Text('새 행사 만들기'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: '행사 제목'),
                    validator: (value) => value!.isEmpty ? '제목을 입력하세요.' : null,
                  ),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: '행사 설명'),
                    maxLines: 3,
                    validator: (value) => value!.isEmpty ? '설명을 입력하세요.' : null,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    final user = homeState.userProfile;
                    try {
                      final newEventId = await _eventService.createEvent(
                        title: titleController.text,
                        description: descriptionController.text,
                        authorId: user.uid,
                        church: user.church,
                      );
                      Navigator.of(dialogContext).pop();

                      // BlocProvider.value를 사용하여 HomeBloc을 전달
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                          value: context.read<HomeBloc>(),
                          child: EventDetailPage(eventId: newEventId),
                        ),
                      ));
                    } catch (e) {
                       Navigator.of(dialogContext).pop();
                       ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(content: Text('행사 생성 실패: $e')),
                       );
                    }
                  }
                },
                child: const Text('생성하기'),
              ),
            ],
          ),
        );
        // --- ▲ [수정] BlocProvider.value로 AlertDialog를 감싸 HomeBloc 전달 ▲ ---
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('행사 목록'),
      ),
      body: Column( // ✨ [수정] 드롭다운을 추가하기 위해 Column으로 감싸기
        children: [
          Row(
            children: [
              // ✨ [추가] 교회 필터 드롭다운
              // ✨ [해결] 첫 번째 DropdownButtonFormField를 Expanded로 감싸 너비를 지정합니다.
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int>(
                    value: _selectedYearFilter,
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12.0)),
                    items: _yearList.map((int year) {
                      return DropdownMenuItem<int>(value: year, child: Text('$year년'));
                    }).toList(),
                    onChanged: (int? newValue) {
                      if (newValue != null) {
                        // ✨ [수정] 연도 필터 변경 시 setState로 값을 바꾸고, 스트림을 새로고침합니다.
                        setState(() => _selectedYearFilter = newValue);
                        _updateStream();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // ✨ [해결] 두 번째 DropdownButtonFormField도 Expanded로 감싸 너비를 지정합니다.
                if (_churchList.isNotEmpty)
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _selectedChurchFilter,
                      decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12.0)),
                      items: _churchList.map((String value) {
                        return DropdownMenuItem<String>(value: value, child: Text(value));
                      }).toList(),
                      onChanged: (String? newValue) {
                        // ✨ [수정] 교회 필터 변경 시 setState로 값을 바꾸고, 스트림을 새로고침합니다.
                        setState(() => _selectedChurchFilter = newValue);
                        _updateStream();
                      },
                    ),
                  ),
            ]
          ),
          // ✨ [수정] 기존 StreamBuilder를 Expanded로 감싸기
          Expanded(
            child: StreamBuilder<List<EventModel>>(
              // ✨ [수정] build 함수에서 매번 새로 생성하는 대신, 상태 변수인 _eventsStream을 사용합니다.
              stream: _eventsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  final error = snapshot.error;
                  debugPrint('\nFIRESTORE ERROR: $error\n');
                  return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('오류가 발생했습니다.\n$error', textAlign: TextAlign.center)));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('해당 조건의 행사가 없습니다.'));
                }

                final events = snapshot.data!;
                return ListView.builder(
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(event.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BlocProvider.value(
                                value: context.read<HomeBloc>(),
                                child: EventDetailPage(eventId: event.id),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEventDialog,
        tooltip: '새 행사 만들기',
        child: const Icon(Icons.add),
      ),
    );
  }
}