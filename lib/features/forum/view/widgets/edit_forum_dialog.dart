import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:narrow_gil/features/forum/models/forum_model.dart';

class EditForumDialog extends StatefulWidget {
  final ForumTopic topic;
  final Function(Map<String, dynamic> updateData) onSave;

  const EditForumDialog({super.key, required this.topic, required this.onSave});

  @override
  State<EditForumDialog> createState() => _EditForumDialogState();
}

class _EditForumDialogState extends State<EditForumDialog> {
  // 일반 주제용
  late final TextEditingController _thisMonthController;
  late final TextEditingController _nextMonthController;

  // 회계/기금용
  late final TextEditingController _broughtForwardController;
  late final TextEditingController _incomeController;
  late final TextEditingController _expenditureController;
  late final TextEditingController _incomeDetailsController;
  late final TextEditingController _expenditureDetailsController;

  // --- ▼ [추가] 안건토의 컨트롤러 ▼ ---
  late final TextEditingController _agendaContentController;
  late final TextEditingController _discussionResultController;
  late final TextEditingController _actionLogController;
  // --- ▲ [추가] 안건토의 컨트롤러 ▲ ---

  bool isAccountingTopic = false;
  // --- ▼ [추가] 안건토의 토픽 여부 플래그 ▼ ---
  bool isAgendaTopic = false;
  // --- ▲ [추가] 안건토의 토픽 여부 플래그 ▲ ---

  @override
  void initState() {
    super.initState();

    isAccountingTopic = widget.topic.responsiblePosition.contains('회계') || widget.topic.responsiblePosition.contains('기금');
    // --- ▼ [추가] 안건토의 토픽인지 확인하는 로직 추가 ▼ ---
    isAgendaTopic = widget.topic.id.endsWith('_안건토의');
    // --- ▲ [추가] 안건토의 토픽인지 확인하는 로직 추가 ▲ ---

    if(isAccountingTopic) {
      _broughtForwardController = TextEditingController(text: widget.topic.broughtForward.toString());
      _incomeController = TextEditingController(text: widget.topic.income.toString());
      _expenditureController = TextEditingController(text: widget.topic.expenditure.toString());
      _incomeDetailsController = TextEditingController(text: widget.topic.incomeDetails);
      _expenditureDetailsController = TextEditingController(text: widget.topic.expenditureDetails);
    // --- ▼ [추가] 안건토의 컨트롤러 초기화 로직 추가 ▼ ---
    } else if (isAgendaTopic) {
      _agendaContentController = TextEditingController(text: widget.topic.agendaContent);
      _discussionResultController = TextEditingController(text: widget.topic.discussionResult);
      _actionLogController = TextEditingController(text: widget.topic.actionLog);
    // --- ▲ [추가] 안건토의 컨트롤러 초기화 로직 추가 ▲ ---
    } else {
      _thisMonthController = TextEditingController(text: widget.topic.thisMonthExecution);
      _nextMonthController = TextEditingController(text: widget.topic.nextMonthPlan);
    }
  }

  @override
  void dispose() {
    if(isAccountingTopic) {
      _broughtForwardController.dispose();
      _incomeController.dispose();
      _expenditureController.dispose();
      _incomeDetailsController.dispose();
      _expenditureDetailsController.dispose();
    // --- ▼ [추가] 안건토의 컨트롤러 dispose 로직 추가 ▼ ---
    } else if (isAgendaTopic) {
      _agendaContentController.dispose();
      _discussionResultController.dispose();
      _actionLogController.dispose();
    // --- ▲ [추가] 안건토의 컨트롤러 dispose 로직 추가 ▲ ---
    } else {
      _thisMonthController.dispose();
      _nextMonthController.dispose();
    }
    super.dispose();
  }

  void _onSavePressed() {
    if (isAccountingTopic) {
      widget.onSave({
        'broughtForward': num.tryParse(_broughtForwardController.text) ?? 0,
        'income': num.tryParse(_incomeController.text) ?? 0,
        'expenditure': num.tryParse(_expenditureController.text) ?? 0,
        'incomeDetails': _incomeDetailsController.text,
        'expenditureDetails': _expenditureDetailsController.text,
      });
    // --- ▼ [추가] 안건토의 저장 로직 추가 ▼ ---
    } else if (isAgendaTopic) {
      widget.onSave({
        'agendaContent': _agendaContentController.text,
        'discussionResult': _discussionResultController.text,
        'actionLog': _actionLogController.text,
      });
    // --- ▲ [추가] 안건토의 저장 로직 추가 ▲ ---
    } else {
      widget.onSave({
        'thisMonthExecution': _thisMonthController.text,
        'nextMonthPlan': _nextMonthController.text,
      });
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.topic.title} 수정'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.7,
          // --- ▼ [수정] 기존 구조를 유지하면서 안건토의 폼 분기 추가 ▼ ---
          child: isAccountingTopic
              ? _buildAccountingForm()
              : (isAgendaTopic
                  ? _buildAgendaForm()
                  : _buildDefaultForm()),
          // --- ▲ [수정] 기존 구조를 유지하면서 안건토의 폼 분기 추가 ▲ ---
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _onSavePressed,
          child: const Text('저장'),
        ),
      ],
    );
  }

  Widget _buildDefaultForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _thisMonthController,
          decoration: const InputDecoration(
            labelText: '이번달실행',
            border: OutlineInputBorder(),
          ),
          maxLines: 5,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _nextMonthController,
          decoration: const InputDecoration(
            labelText: '다음달계획',
            border: OutlineInputBorder(),
          ),
          maxLines: 5,
        ),
      ],
    );
  }

  Widget _buildAccountingForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildNumberTextField(_broughtForwardController, '이월금액'),
        const SizedBox(height: 16),
        _buildNumberTextField(_incomeController, '수입금액'),
        const SizedBox(height: 16),
        TextField(
          controller: _incomeDetailsController,
          decoration: const InputDecoration(
            labelText: '수입 내역',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: 3,
          textAlignVertical: TextAlignVertical.top,
        ),
        const SizedBox(height: 20),
        _buildNumberTextField(_expenditureController, '지출금액'),
        const SizedBox(height: 16),
        TextField(
          controller: _expenditureDetailsController,
          decoration: const InputDecoration(
            labelText: '지출 내역',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: 3,
          textAlignVertical: TextAlignVertical.top,
        ),
      ],
    );
  }

  // --- ▼ [추가] 안건토의 수정 폼 위젯 ▼ ---
  Widget _buildAgendaForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(controller: _agendaContentController, decoration: const InputDecoration(labelText: '안건내용', border: OutlineInputBorder(), alignLabelWithHint: true), maxLines: 4, textAlignVertical: TextAlignVertical.top),
        const SizedBox(height: 20),
        TextField(controller: _discussionResultController, decoration: const InputDecoration(labelText: '안건토의결과', border: OutlineInputBorder(), alignLabelWithHint: true), maxLines: 4, textAlignVertical: TextAlignVertical.top),
        const SizedBox(height: 20),
        TextField(controller: _actionLogController, decoration: const InputDecoration(labelText: '안건실행내역', border: OutlineInputBorder(), alignLabelWithHint: true), maxLines: 4, textAlignVertical: TextAlignVertical.top),
      ],
    );
  }
  // --- ▲ [추가] 안건토의 수정 폼 위젯 ▲ ---

  Widget _buildNumberTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
      ],
    );
  }
}