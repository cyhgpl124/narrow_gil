// lib/features/accounting/view/widgets/add_accounting_area_dialog.dart

import 'package:flutter/material.dart';
import 'package:narrow_gil/features/accounting/services/accounting_service.dart';

// 대상 범위를 나타내는 Enum
enum AreaTarget { allMembers, localChurchMembers }

/// churchId를 인자로 받아 해당 교회에 신규 회계 구역을 추가하는 다이얼로그를 표시합니다.
void showAddAccountingAreaDialog(BuildContext context, String churchId) {
  final formKey = GlobalKey<FormState>();
  final areaNameController = TextEditingController();
  final AccountingService accountingService = AccountingService();

  AreaTarget? selectedTarget = AreaTarget.allMembers; // 기본 선택값

  showDialog(
    context: context,
    barrierDismissible: false, // 다이얼로그 바깥을 눌러도 닫히지 않게 설정
    builder: (BuildContext context) {
      // 다이얼로그 내에서 상태를 관리하기 위해 StatefulBuilder 사용
      return StatefulBuilder(
        builder: (context, setState) {
          // '추가하기' 버튼을 눌렀을 때 실행될 함수
          void handleAddArea() {
            if (formKey.currentState!.validate()) {
              final areaName = areaNameController.text.trim();
              final targetValue = selectedTarget == AreaTarget.allMembers ? 'all' : 'local';

              // --- ▼ [수정] 서비스 함수 호출 시 churchId를 전달하도록 변경 ▼ ---
              accountingService.addAccountingArea(
                churchId: churchId,
                areaName: areaName,
                target: targetValue,
              ).then((_) {
                 Navigator.of(context).pop(); // 성공 시 다이얼로그 닫기
                 ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(content: Text('\'$areaName\' 회계 구역이 추가되었습니다.')),
                 );
              }).catchError((e) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('오류가 발생했습니다: $e')),
                  );
              });
              // --- ▲ [수정] 서비스 함수 호출 시 churchId를 전달하도록 변경 ▲ ---
            }
          }

          return AlertDialog(
            // --- ▼ [수정] 다이얼로그 제목을 동적으로 변경 ▼ ---
            title: Text('[$churchId] 신규 회계 구역 추가'),
            // --- ▲ [수정] 다이얼로그 제목을 동적으로 변경 ▲ ---
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 회계 구역명 입력 필드
                    TextFormField(
                      controller: areaNameController,
                      decoration: const InputDecoration(
                        labelText: '회계 구역명',
                        hintText: '예: 식비, 교통비, 헌금 등',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '회계 구역명을 입력해주세요.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // 대상 선택 라디오 버튼
                    const Text('대상 선택', style: TextStyle(fontWeight: FontWeight.bold)),
                    const Divider(),
                    RadioListTile<AreaTarget>(
                      title: const Text('전체 성민'),
                      subtitle: const Text('모든 교인에게 적용됩니다.'),
                      value: AreaTarget.allMembers,
                      groupValue: selectedTarget,
                      onChanged: (AreaTarget? value) {
                        setState(() {
                          selectedTarget = value;
                        });
                      },
                    ),
                    RadioListTile<AreaTarget>(
                      title: const Text('지교 성민'),
                      subtitle: const Text('각 지교별로 별도로 적용됩니다.'),
                      value: AreaTarget.localChurchMembers,
                      groupValue: selectedTarget,
                      onChanged: (AreaTarget? value) {
                        setState(() {
                          selectedTarget = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: handleAddArea,
                child: const Text('추가하기'),
              ),
            ],
          );
        },
      );
    },
  );
}