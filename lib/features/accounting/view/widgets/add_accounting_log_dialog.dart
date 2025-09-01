// lib/features/accounting/view/widgets/add_accounting_log_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:narrow_gil/features/accounting/models/accounting_log_model.dart';
import 'package:narrow_gil/features/accounting/services/accounting_service.dart';
import 'package:narrow_gil/home/bloc/home_bloc.dart';

const Map<String, List<String>> managementItems = {
  '헌금': ['주일예물', '감사예물', '십일조', '특별예물', '후원금', '성전기금', '해외헌금', '찬조금', '기타'],
  '운영비': ['선교비', '찬조금', '예전비', '교육비', '행사비', '주부식비', '봉사비', '통신비', '비품', '소모품비', '기타'],
};

// ✨ [수정] showDialog 함수가 Future<bool?>를 반환하도록 변경하고, isChurchLevel 파라미터를 추가합니다.
Future<bool?> showAddAccountingLogDialog(BuildContext pageContext, {
  required String churchId,
  required String currentSection,
  bool isChurchLevel = false,
}) {
  final formKey = GlobalKey<FormState>();
  final amountController = TextEditingController();
  final detailsController = TextEditingController();
  final externalTargetController = TextEditingController();
  final accountingService = AccountingService();

  bool isInternalTrade = true;
  String? selectedToSection;
  String? tier1, tier2;
  DateTime selectedDate = DateTime.now();
  LogType selectedLogType = LogType.expense;

  // ✨ [추가] 자동완성을 위한 상태 변수
  Map<String, String>? selectedUser;


  // ✨ [수정] showDialog의 반환값을 return합니다.
  return showDialog<bool>(
    context: pageContext,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> _selectDate(BuildContext context) async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: selectedDate,
              firstDate: DateTime(2000),
              lastDate: DateTime(2101),
            );
            if (picked != null && picked != selectedDate) {
              setState(() {
                selectedDate = picked;
              });
            }
          }

          void handleSubmit() {
            if (formKey.currentState!.validate()) {
              final user = (pageContext.read<HomeBloc>().state as HomeLoadSuccess).userProfile;
              final amount = double.tryParse(amountController.text) ?? 0;
              // ✨ [수정] 3단계가 없어도 되도록 item 조합 방식 변경
              final item = tier2 != null
                  ? '$tier1:$tier2:${detailsController.text.trim()}'
                  : '$tier1:${detailsController.text.trim()}';

              accountingService.createAccountingLog(
                churchId: churchId,
                currentSection: currentSection,
                // ✨ [수정] 외부 거래 시 선택된 사용자 이름 또는 입력된 텍스트를 target으로 사용
                target: isInternalTrade
                    ? selectedToSection!
                    : selectedUser != null ? selectedUser!['name']! : externalTargetController.text.trim(),
                amount: amount,
                item: item,
                managerId: user.uid,
                managerName: user.name,
                isInternal: isInternalTrade,
                logType: selectedLogType,
                date: selectedDate,
                // ✨ [추가] 외부 거래 시 선택된 사용자 정보 전달
                targetUserId: isInternalTrade ? null : selectedUser?['id'],
                targetUserChurch: isInternalTrade ? null : selectedUser?['church'],
              ).then((_) {
                 // ✨ [수정] 성공 시 true 값을 반환하며 다이얼로그를 닫습니다.
                 Navigator.of(dialogContext).pop(true);
                 ScaffoldMessenger.of(pageContext).showSnackBar(const SnackBar(content: Text('회계 내역이 성공적으로 기록되었습니다.')));
              }).catchError((e) {
                  // ✨ [수정] 실패 시 false 값을 반환하며 다이얼로그를 닫습니다.
                  Navigator.of(dialogContext).pop(false);
                  ScaffoldMessenger.of(pageContext).showSnackBar(SnackBar(content: Text('기록 실패: $e')));
              });
            }
          }

          return AlertDialog(
            title: const Text('상세 입출금 내역 추가'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context),
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: '날짜', border: OutlineInputBorder(), contentPadding: EdgeInsets.all(12)),
                              child: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                            ),
                          ),
                        ),
                        if (!isInternalTrade) ...[
                           const SizedBox(width: 16),
                           Expanded(
                            child: DropdownButtonFormField<LogType>(
                              value: selectedLogType,
                              decoration: const InputDecoration(labelText: '종류', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                              items: const [
                                DropdownMenuItem(value: LogType.expense, child: Text('지출')),
                                DropdownMenuItem(value: LogType.income, child: Text('수입')),
                              ],
                              onChanged: (val) => setState(() => selectedLogType = val!),
                            ),
                          )
                        ]
                      ],
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('내부 거래')),
                        ButtonSegment(value: false, label: Text('외부/개인 거래')),
                      ],
                      selected: {isInternalTrade},
                      onSelectionChanged: (Set<bool> newSelection) {
                        setState(() {
                          isInternalTrade = newSelection.first;
                          selectedUser = null; // 거래 유형 변경 시 선택된 사용자 초기화
                          externalTargetController.clear();
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    if (isInternalTrade)
                      isChurchLevel
                          ? FutureBuilder<List<String>>(
                              future: accountingService.getChurchNames(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) return const CircularProgressIndicator();
                                final otherChurches = snapshot.data!.where((s) => s != currentSection).toList();
                                return DropdownButtonFormField<String>(
                                  value: selectedToSection,
                                  decoration: const InputDecoration(labelText: '받는 교회', border: OutlineInputBorder()),
                                  items: otherChurches.map((area) => DropdownMenuItem(value: area, child: Text(area))).toList(),
                                  onChanged: (val) => setState(() => selectedToSection = val),
                                  validator: (val) => val == null ? '받는 교회를 선택하세요' : null,
                                );
                              },
                            )
                          : FutureBuilder<List<String>>(
                              future: accountingService.getDepartments(churchId).first,
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) return const CircularProgressIndicator();
                                final otherSections = snapshot.data!.where((s) => s != currentSection.split(' ').last).toList();
                                return DropdownButtonFormField<String>(
                                  value: selectedToSection,
                                  decoration: const InputDecoration(labelText: '받는 구역', border: OutlineInputBorder()),
                                  items: otherSections.map((area) => DropdownMenuItem(value: area, child: Text(area))).toList(),
                                  onChanged: (val) => setState(() => selectedToSection = val),
                                  validator: (val) => val == null ? '받는 구역을 선택하세요' : null,
                                );
                              },
                            )
                    else
                      // ✨ [수정] 외부 거래 시 자동완성 필드로 변경
                      FutureBuilder<List<Map<String, String>>>(
                        future: accountingService.getUsers(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const CircularProgressIndicator();
                          final users = snapshot.data!;
                          return Autocomplete<Map<String, String>>(
                            displayStringForOption: (option) => '${option['church']} ${option['name']}',
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              if (textEditingValue.text == '') {
                                return const Iterable<Map<String, String>>.empty();
                              }
                              return users.where((Map<String, String> option) {
                                final displayName = '${option['church']} ${option['name']}';
                                return displayName.toLowerCase().contains(textEditingValue.text.toLowerCase());
                              });
                            },
                            onSelected: (Map<String, String> selection) {
                              setState(() {
                                selectedUser = selection;
                                externalTargetController.text = '${selection['church']} ${selection['name']}';
                              });
                            },
                            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                              // 이전에 선택된 사용자가 있으면 컨트롤러 텍스트를 설정
                              if (selectedUser != null && controller.text.isEmpty) {
                                controller.text = '${selectedUser!['church']} ${selectedUser!['name']}';
                              }
                              return TextFormField(
                                controller: controller,
                                focusNode: focusNode,
                                decoration: InputDecoration(
                                  labelText: '대상 (개인/기관명)',
                                  border: const OutlineInputBorder(),
                                  suffixIcon: controller.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            controller.clear();
                                            setState(() => selectedUser = null);
                                          },
                                        )
                                      : null,
                                ),
                                validator: (val) => val!.trim().isEmpty ? '대상을 입력하세요' : null,
                              );
                            },
                          );
                        },
                      ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: amountController,
                      decoration: const InputDecoration(labelText: '거래 금액/헌금', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      validator: (val) => val!.isEmpty ? '금액을 입력하세요' : null,
                    ),
                    const SizedBox(height: 20),
                    const Text('관리 항목', style: TextStyle(fontWeight: FontWeight.bold)),
                    const Divider(),
                    DropdownButtonFormField<String>(
                      value: tier1,
                      decoration: const InputDecoration(labelText: '1단계 분류', border: OutlineInputBorder()),
                      items: managementItems.keys.map((key) => DropdownMenuItem(value: key, child: Text(key))).toList(),
                      onChanged: (val) => setState(() {
                        tier1 = val;
                        tier2 = null;
                      }),
                      validator: (val) => val == null ? '1단계 분류를 선택하세요' : null,
                    ),
                    const SizedBox(height: 16),
                    if (tier1 != null)
                      DropdownButtonFormField<String>(
                        value: tier2,
                        decoration: const InputDecoration(labelText: '2단계 분류', border: OutlineInputBorder()),
                        items: managementItems[tier1]!.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                        onChanged: (val) => setState(() => tier2 = val),
                        validator: (val) => val == null ? '2단계 분류를 선택하세요' : null,
                      ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: detailsController,
                      decoration: const InputDecoration(labelText: '3단계 (세부사항)', border: OutlineInputBorder()),
                       // ✨ [수정] validator 제거하여 선택사항으로 변경
                       // validator: (val) => val!.trim().isEmpty ? '세부사항을 입력하세요' : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('취소')),
              ElevatedButton(onPressed: handleSubmit, child: const Text('기록 추가')),
            ],
          );
        },
      );
    },
  );
}