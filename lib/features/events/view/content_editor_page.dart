// lib/features/events/view/content_editor_page.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:narrow_gil/features/events/models/content_block_model.dart';
import 'package:narrow_gil/features/events/models/form_template_model.dart';
import 'package:narrow_gil/features/events/services/event_service.dart';
import 'package:narrow_gil/home/bloc/home_bloc.dart';
import 'dart:typed_data';

// =========================================================================
// 1. 전체 화면 페이지 위젯 (ContentEditorPage)
// =========================================================================
/// 이 위젯은 시간표 세부사항 편집과 같이 독립적인 전체 화면 편집기가 필요할 때 사용됩니다.
/// UI의 뼈대(Scaffold, AppBar)를 제공하고, 실제 편집 기능은 ContentEditorWidget을 통해 구현됩니다.
class ContentEditorPage extends StatefulWidget {
  final String eventId;
  final int? scheduleIndex;
  final ContentBlockModel initialContent;
  final String pageTitle;
  final bool isReport;

  const ContentEditorPage({
    super.key,
    required this.eventId,
    this.scheduleIndex,
    required this.initialContent,
    required this.pageTitle,
    this.isReport = false,
  });

  @override
  State<ContentEditorPage> createState() => _ContentEditorPageState();
}

class _ContentEditorPageState extends State<ContentEditorPage> {
  /// GlobalKey는 하위 위젯 트리에 있는 특정 위젯의 상태(State)에 접근하기 위해 사용됩니다.
  /// 여기서는 AppBar의 저장 버튼이 ContentEditorWidget의 `saveContent` 함수를 호출하기 위해 필요합니다.
  final GlobalKey<ContentEditorWidgetState> _editorKey = GlobalKey<ContentEditorWidgetState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pageTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: '저장하기',
            onPressed: () async {
              // GlobalKey를 통해 ContentEditorWidget의 State에 접근하여 public 함수인 saveContent를 호출합니다.
              // `currentState`가 null일 수 있으므로 `?` 연산자를 사용합니다.
              await _editorKey.currentState?.saveContent();
              if (mounted) {
                // 저장이 완료되면 현재 페이지를 닫습니다.
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      // 본문에는 재사용 가능한 ContentEditorWidget을 배치합니다.
      // Key를 연결하여 AppBar에서 이 위젯의 상태에 접근할 수 있도록 합니다.
      body: ContentEditorWidget(
        key: _editorKey,
        eventId: widget.eventId,
        scheduleIndex: widget.scheduleIndex,
        initialContent: widget.initialContent,
        isReport: widget.isReport,
      ),
    );
  }
}


// =========================================================================
// 2. 재사용 가능한 편집기 위젯 (ContentEditorWidget)
// =========================================================================
/// 이 위젯은 실제 편집 UI와 모든 관련 로직을 포함합니다.
/// `event_detail_page`와 같은 다른 페이지에 직접 내장될 수 있도록 설계되었습니다.
class ContentEditorWidget extends StatefulWidget {
  final String eventId;
  final int? scheduleIndex;
  final ContentBlockModel initialContent;
  final bool isReport;

  const ContentEditorWidget({
    super.key,
    required this.eventId,
    this.scheduleIndex,
    required this.initialContent,
    this.isReport = false,
  });

  @override
  State<ContentEditorWidget> createState() => ContentEditorWidgetState();
}

class ContentEditorWidgetState extends State<ContentEditorWidget> {
  final EventService _eventService = EventService();
  late List<ContentBlock> _contentBlocks;
  final Map<int, TextEditingController> _textControllers = {};
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    // 위젯이 처음 생성될 때 전달받은 초기 데이터로 상태를 설정합니다.
    _initializeState(widget.initialContent);
  }

  /// 부모 위젯에서 전달하는 데이터(props)가 변경될 때 호출됩니다.
  /// 예를 들어, `event_detail_page`에서 다른 보고서를 편집하기 시작할 때 이 함수가 호출되어
  /// 편집기 내부의 상태를 새로운 데이터로 갱신합니다.
  @override
  void didUpdateWidget(covariant ContentEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialContent != oldWidget.initialContent) {
      _initializeState(widget.initialContent);
    }
  }

  /// 편집기 상태를 초기화하는 함수입니다.
  /// 새로운 컨텐츠가 로드될 때마다 호출되어 텍스트 컨트롤러 등을 다시 설정합니다.
  void _initializeState(ContentBlockModel content) {
    _contentBlocks = List.from(content.blocks);
    // 기존 컨트롤러들을 모두 폐기하여 메모리 누수를 방지합니다.
    _textControllers.forEach((_, controller) => controller.dispose());
    _textControllers.clear();
    // 컨텐츠 블록을 순회하며 텍스트 블록에 대한 컨트롤러를 새로 생성합니다.
    for (int i = 0; i < _contentBlocks.length; i++) {
      if (_contentBlocks[i].type == ContentBlockType.text) {
        _textControllers[i] = TextEditingController(text: _contentBlocks[i].content as String? ?? '');
      }
    }
  }

  @override
  void dispose() {
    // 위젯이 화면에서 사라질 때 모든 텍스트 컨트롤러를 폐기하여 메모리 누수를 방지합니다.
    _textControllers.forEach((key, controller) {
      controller.dispose();
    });
    super.dispose();
  }

  /// 현재 편집 중인 내용을 Firestore에 저장합니다.
  /// 외부(ContentEditorPage의 AppBar)에서 호출할 수 있도록 public 함수로 선언합니다.
  Future<void> saveContent() async {
    // 각 텍스트 컨트롤러의 최신 텍스트를 _contentBlocks 리스트에 업데이트합니다.
    _textControllers.forEach((index, controller) {
      if (index < _contentBlocks.length && _contentBlocks[index].type == ContentBlockType.text) {
        _contentBlocks[index] = ContentBlock(type: ContentBlockType.text, content: controller.text);
      }
    });

    final contentToSave = ContentBlockModel(blocks: _contentBlocks);
    try {
      if (widget.isReport) {
        // 보고서 저장 로직
        await _eventService.updateReport(widget.eventId, contentToSave.toMap());
      } else if (widget.scheduleIndex != null) {
        // 시간표 세부항목 저장 로직
        await _eventService.updateSingleScheduleItem(
          eventId: widget.eventId,
          scheduleIndex: widget.scheduleIndex!,
          newContent: contentToSave.toMap(),
        );
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장되었습니다.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    }
  }

  // --- 컨텐츠 블록 추가/수정 관련 함수들 ---

  /// 새로운 텍스트 블록을 편집기 하단에 추가합니다.
  void _addTextBlock() {
    setState(() {
      final newIndex = _contentBlocks.length;
      _contentBlocks.add(ContentBlock(type: ContentBlockType.text, content: ''));
      _textControllers[newIndex] = TextEditingController();
    });
  }

  /// 새로운 2x2 테이블 블록을 추가합니다.
  void _addTableBlock() {
    setState(() {
      _contentBlocks.add(ContentBlock(type: ContentBlockType.table, content: [
        ['제목1', '제목2'],
        ['내용1', '내용2']
      ]));
    });
  }

  /// 갤러리에서 여러 이미지를 선택하여 업로드하고, 이미지 블록을 추가/업데이트합니다.
  Future<void> _addImageBlock() async {
    if (_isUploading) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이미지를 업로드하는 중입니다...')));
      return;
    }

    final pickedFiles = await ImagePicker().pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() => _isUploading = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이미지 업로드를 시작합니다...')));

      try {
        List<String> imageUrls = [];
        for (final file in pickedFiles) {
          final imageBytes = await file.readAsBytes();
          final downloadUrl = await _eventService.uploadImage(
            eventId: widget.eventId,
            imageBytes: imageBytes,
          );
          imageUrls.add(downloadUrl);
        }

        setState(() {
          // 이미 이미지 블록이 존재하면 URL을 추가하고, 없으면 새로 생성합니다.
          final imageBlockIndex = _contentBlocks.indexWhere((b) => b.type == ContentBlockType.image);
          if (imageBlockIndex != -1) {
            final existingUrls = List<String>.from(_contentBlocks[imageBlockIndex].content ?? []);
            existingUrls.addAll(imageUrls);
            _contentBlocks[imageBlockIndex] = ContentBlock(type: ContentBlockType.image, content: existingUrls);
          } else {
             _contentBlocks.add(ContentBlock(type: ContentBlockType.image, content: imageUrls));
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이미지 업로드가 완료되었습니다.')));

      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('이미지 업로드 실패: $e')));
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  /// 구분선 블록을 추가합니다.
  void _addDividerBlock() {
    setState(() {
      _contentBlocks.add(ContentBlock(type: ContentBlockType.divider));
    });
  }

  /// 기존에 저장된 양식을 불러와 편집기 내용을 교체합니다.
  Future<void> _selectExistingTemplate() async {
    final selectedContent = await showDialog<ContentBlockModel>(
      context: context,
      builder: (_) => const _ExistingTemplatesDialog(),
    );

    if (selectedContent != null && mounted) {
      setState(() {
        _initializeState(selectedContent); // 불러온 양식으로 편집기 상태를 초기화
      });
    }
  }

  /// 현재 편집 중인 내용을 새로운 양식으로 저장합니다.
  void _saveAsNewTemplate() {
    final homeState = context.read<HomeBloc>().state;
    if (homeState is! HomeLoadSuccess) return;

    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('새 양식으로 등록'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: const InputDecoration(labelText: '양식 이름'),
            validator: (value) => value!.isEmpty ? '이름을 입력하세요.' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final user = homeState.userProfile;
                final contentModel = ContentBlockModel(blocks: _contentBlocks);
                try {
                  await _eventService.saveNewFormTemplate(
                    name: nameController.text,
                    contentModel: contentModel,
                    authorId: user.uid,
                    church: user.church,
                  );
                  if (mounted) {
                     Navigator.of(context).pop();
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('새 양식이 저장되었습니다.')));
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('양식 저장 실패: $e')));
                  }
                }
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold를 제거하고 Column을 사용하여 다른 위젯에 내장될 수 있도록 합니다.
    return Column(
      children: [
        // ✨ [수정] Flexible을 제거하고, ListView.builder에 두 가지 속성을 추가합니다.
        ListView.builder(
          shrinkWrap: true, // 1. 자식들의 크기만큼만 높이를 차지하도록 설정
          physics: const NeverScrollableScrollPhysics(), // 2. 자체 스크롤 기능을 끄고, 부모(SingleChildScrollView)의 스크롤을 따르도록 설정
          padding: const EdgeInsets.all(16),
          itemCount: _contentBlocks.length + 1,
          itemBuilder: (context, index) {
            if (index == _contentBlocks.length) {
              return _buildEmptySpace();
            }
            final block = _contentBlocks[index];
            return _buildContentBlock(block, index);
          },
        ),
        _buildBottomController(),
      ],
    );
  }

  // --- UI를 구성하는 빌더 함수들 ---

  /// 각 컨텐츠 블록의 종류에 맞는 위젯을 반환합니다.
  Widget _buildContentBlock(ContentBlock block, int blockIndex) {
    switch (block.type) {
      case ContentBlockType.text:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: TextFormField(
            controller: _textControllers[blockIndex],
            decoration: const InputDecoration(
              hintText: '내용을 입력하세요...',
              border: InputBorder.none,
            ),
            maxLines: null, // 여러 줄 입력 가능
          ),
        );
      case ContentBlockType.table:
        return _EditableTable(
          key: ValueKey('table_$blockIndex'), // 상태 유지를 위한 Key
          initialData: List<List<String>>.from((block.content as List).map((row) => List<String>.from(row as List))),
          onUpdate: (newData) {
            setState(() {
              _contentBlocks[blockIndex] = ContentBlock(
                type: ContentBlockType.table,
                content: newData,
              );
            });
          },
        );
      case ContentBlockType.image:
        final images = List<String>.from(block.content ?? []);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: CarouselSlider(
            options: CarouselOptions(height: 200, enlargeCenterPage: true, viewportFraction: 0.8),
            items: images.map((url) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 5.0),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(url, fit: BoxFit.cover)),
              );
            }).toList(),
          ),
        );
      case ContentBlockType.divider:
        return const Divider(height: 32, thickness: 1, indent: 20, endIndent: 20);
    }
  }

  /// 텍스트 블록을 쉽게 추가할 수 있도록 리스트 하단에 빈 공간을 제공합니다.
  Widget _buildEmptySpace() {
    return InkWell(
      onTap: _addTextBlock,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        child: Center(
          child: Text(
            '빈 공간을 클릭하여 줄글 추가...',
            style: TextStyle(color: Colors.grey.shade400),
          ),
        ),
      ),
    );
  }

  /// 화면 하단의 컨트롤러 UI (블록 추가, 양식 관리 버튼 등)
  Widget _buildBottomController() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Theme.of(context).canvasColor,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, -2))
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(icon: const Icon(Icons.text_fields_outlined), onPressed: _addTextBlock, tooltip: '텍스트 추가'),
                IconButton(icon: const Icon(Icons.table_chart_outlined), onPressed: _addTableBlock, tooltip: '표 추가'),
                IconButton(icon: const Icon(Icons.image_outlined), onPressed: _addImageBlock, tooltip: '이미지 추가'),
                IconButton(icon: const Icon(Icons.horizontal_rule), onPressed: _addDividerBlock, tooltip: '구분선 추가'),
              ],
            ),
            const Divider(height: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(child: const Text('기존 양식 선택'), onPressed: _selectExistingTemplate),
                TextButton(child: const Text('새 양식으로 등록'), onPressed: _saveAsNewTemplate),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- 테이블 편집을 위한 별도 위젯 ---
class _EditableTable extends StatefulWidget {
  final List<List<String>> initialData;
  final Function(List<List<String>> newData) onUpdate;

  const _EditableTable({super.key, required this.initialData, required this.onUpdate});

  @override
  State<_EditableTable> createState() => __EditableTableState();
}

class __EditableTableState extends State<_EditableTable> {
  late List<List<TextEditingController>> _controllers;
  late List<List<String>> _data;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData.map((row) => List<String>.from(row)).toList();
    _controllers = _data.map((row) {
      return row.map((cell) => TextEditingController(text: cell)).toList();
    }).toList();
  }

  @override
  void dispose() {
    for (var row in _controllers) {
      for (var controller in row) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  void _updateParent() {
    for (int i = 0; i < _controllers.length; i++) {
      for (int j = 0; j < _controllers[i].length; j++) {
        _data[i][j] = _controllers[i][j].text;
      }
    }
    widget.onUpdate(_data);
  }

  void _addRow() {
    if (_controllers.isEmpty) return;
    setState(() {
      final newRow = List.generate(_controllers[0].length, (_) => TextEditingController());
      final newDataRow = List.generate(_controllers[0].length, (_) => '');
      _controllers.add(newRow);
      _data.add(newDataRow);
      _updateParent();
    });
  }

  void _addColumn() {
    if (_controllers.isEmpty) {
      setState(() {
        _controllers.add([TextEditingController()]);
        _data.add(['']);
      });
    } else {
      setState(() {
        for (int i = 0; i < _controllers.length; i++) {
          _controllers[i].add(TextEditingController());
          _data[i].add('');
        }
      });
    }
    _updateParent();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(_controllers.length, (rowIndex) {
                    return Row(
                      children: List.generate(_controllers[rowIndex].length, (colIndex) {
                        return Container(
                          width: 120,
                          padding: const EdgeInsets.all(4.0),
                          child: TextFormField(
                            controller: _controllers[rowIndex][colIndex],
                            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                            onChanged: (_) => _updateParent(),
                          ),
                        );
                      }),
                    );
                  }),
                ),
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_box_outlined, size: 20),
                      onPressed: _addColumn,
                      tooltip: '열 추가',
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                )
              ],
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: _addRow,
                  tooltip: '행 추가',
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- 기존 양식 선택을 위한 별도 다이얼로그 위젯 ---
class _ExistingTemplatesDialog extends StatefulWidget {
  const _ExistingTemplatesDialog();

  @override
  State<_ExistingTemplatesDialog> createState() => _ExistingTemplatesDialogState();
}

class _ExistingTemplatesDialogState extends State<_ExistingTemplatesDialog> {
  final EventService _eventService = EventService();
  late Future<List<FormTemplateModel>> _templatesFuture;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _templatesFuture = _eventService.getFormTemplates();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('기존 양식 선택'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: '양식 검색',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<FormTemplateModel>>(
                future: _templatesFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final filteredList = snapshot.data!.where((template) => template.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final template = filteredList[index];
                      return ListTile(
                        title: Text(template.name),
                        onTap: () {
                          Navigator.of(context).pop(template.content);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('취소')),
      ],
    );
  }
}