// lib/features/events/view/event_detail_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:narrow_gil/features/events/models/content_block_model.dart';
import 'package:narrow_gil/features/events/models/event_model.dart';
import 'package:narrow_gil/features/events/models/schedule_item_model.dart';
import 'package:narrow_gil/features/events/services/event_service.dart';
import 'package:narrow_gil/features/events/view/content_editor_page.dart'; // ContentEditorWidget을 위해 import
import 'package:narrow_gil/home/bloc/home_bloc.dart';
import 'package:carousel_slider/carousel_slider.dart';


class EventDetailPage extends StatefulWidget {
  final String eventId;
  const EventDetailPage({super.key, required this.eventId});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  final EventService _eventService = EventService();

  // 보고서 편집 모드를 관리하는 상태 변수
  bool _isEditingReport = false;
  // ✨ [오류 수정] GlobalKey의 타입을 _ContentEditorWidgetState로 정확히 지정합니다.
  final GlobalKey<ContentEditorWidgetState> _editorKey = GlobalKey<ContentEditorWidgetState>();

  // 새로운 시간표 항목을 추가하는 다이얼로그
  void _addScheduleItem(EventModel currentEvent) {
    final dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final timeController = TextEditingController();
    final titleController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('시간표 항목 추가'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: dateController, decoration: const InputDecoration(labelText: '날짜 (YYYY-MM-DD)')),
              TextFormField(controller: timeController, decoration: const InputDecoration(labelText: '시간 (HH:MM - HH:MM)')),
              TextFormField(controller: titleController, decoration: const InputDecoration(labelText: '세부사항 제목')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final newItem = ScheduleItemModel(
                  date: Timestamp.fromDate(DateTime.parse(dateController.text)),
                  time: timeController.text,
                  detailsTitle: titleController.text,
                  detailsContent: ContentBlockModel(blocks: []),
                );
                final updatedSchedule = currentEvent.schedule.map((e) => e.toMap()).toList()..add(newItem.toMap());
                await _eventService.updateSchedule(widget.eventId, updatedSchedule);
                Navigator.of(context).pop();
              }
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final homeState = context.watch<HomeBloc>().state as HomeLoadSuccess;
    final user = homeState.userProfile;

    return StreamBuilder<EventModel>(
      stream: _eventService.getEventStream(widget.eventId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
        }
        final event = snapshot.data!;
        final isAttending = event.attendees.any((attendee) => attendee.uid == user.uid);

        return Scaffold(
          appBar: AppBar(
            title: Text(event.title),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- 1. 행사 정보, 참석 버튼 ---
                Text(event.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(event.description, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: Icon(isAttending ? Icons.check_circle : Icons.check_circle_outline),
                    label: Text(isAttending ? '참석 취소' : '참석하기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAttending ? Colors.grey : Theme.of(context).primaryColor,
                    ),
                    onPressed: () => _eventService.toggleAttendance(event.id, user),
                  ),
                ),
                const SizedBox(height: 16),

                // --- 2. 참석자 명단 ---
                Text('참석자 (${event.attendees.length}명)', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (event.attendees.isEmpty)
                  const Text('아직 참석자가 없습니다.')
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2.5,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: event.attendees.length,
                    itemBuilder: (context, index) {
                      final attendee = event.attendees[index];
                      return Card(
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(attendee.name, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                              Text(attendee.church, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                const Divider(height: 32),

                // --- 3. 시간표 ---
                Text('시간표', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (event.schedule.isEmpty)
                  const Text('등록된 시간표가 없습니다.'),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: event.schedule.length,
                  itemBuilder: (context, index) {
                    final item = event.schedule[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(DateFormat('MM/dd').format(item.date.toDate())),
                            Text(item.time, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        title: Text(item.detailsTitle),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => BlocProvider.value(
                              value: context.read<HomeBloc>(),
                              child: ContentEditorPage(
                                eventId: event.id,
                                scheduleIndex: index,
                                initialContent: item.detailsContent,
                                pageTitle: item.detailsTitle,
                              ),
                            ),
                          ));
                        },
                      ),
                    );
                  },
                ),
                Center(
                  child: IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
                    onPressed: () => _addScheduleItem(event),
                    tooltip: '시간표 항목 추가',
                  ),
                ),
                const Divider(height: 32),

                // --- 4. 보고서 섹션 ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('보고서', style: Theme.of(context).textTheme.titleLarge),
                    if (_isEditingReport)
                      Row(
                        children: [
                          TextButton(
                            child: const Text('취소'),
                            onPressed: () => setState(() => _isEditingReport = false),
                          ),
                          ElevatedButton(
                            child: const Text('저장'),
                            onPressed: () async {
                              await _editorKey.currentState?.saveContent();
                              if (mounted) {
                                setState(() => _isEditingReport = false);
                              }
                            },
                          ),
                        ],
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.edit_note),
                        tooltip: '보고서 수정',
                        onPressed: () => setState(() => _isEditingReport = true),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_isEditingReport)
                  ContentEditorWidget(
                    key: _editorKey,
                    eventId: event.id,
                    initialContent: event.report,
                    isReport: true,
                  )
                else
                  (event.report.blocks.isEmpty)
                      ? const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: Text('작성된 보고서가 없습니다.\n우측 수정 버튼을 눌러 작성해주세요.')),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(12),
                            itemCount: event.report.blocks.length,
                            itemBuilder: (context, index) {
                              final block = event.report.blocks[index];
                              return _buildContentBlockViewer(block);
                            },
                          ),
                        ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 보고서 내용을 화면에 표시하기 위한 뷰어 위젯 빌더
  Widget _buildContentBlockViewer(ContentBlock block) {
    switch (block.type) {
      case ContentBlockType.text:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(block.content as String? ?? ''),
        );
      case ContentBlockType.table:
        final tableData = List<List<String>>.from((block.content as List).map((row) => List<String>.from(row as List)));
        if (tableData.isEmpty || tableData.first.isEmpty) return const SizedBox.shrink();
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade300)),
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: tableData.first.map((header) => DataColumn(label: Text(header, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
              rows: tableData.skip(1).map((row) => DataRow(cells: row.map((cell) => DataCell(Text(cell))).toList())).toList(),
            ),
          ),
        );
      case ContentBlockType.image:
        final images = List<String>.from(block.content ?? []);
        if (images.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: CarouselSlider(
            options: CarouselOptions(height: 200, enlargeCenterPage: true, viewportFraction: 0.8),
            items: images.map((url) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 5.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(url, fit: BoxFit.cover, loadingBuilder: (_, child, progress) =>
                      progress == null ? child : const Center(child: CircularProgressIndicator())),
                ),
              );
            }).toList(),
          ),
        );
      case ContentBlockType.divider:
        return const Divider(height: 32, thickness: 1, indent: 20, endIndent: 20);
    }
  }
}