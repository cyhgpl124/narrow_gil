// lib/features/accounting/view/widgets/add_department_dialog.dart
import 'package:flutter/material.dart';
import 'package:narrow_gil/features/accounting/services/accounting_service.dart';

/// 교회 ID(churchId)를 받아 해당 교회의 부서를 추가하는 다이얼로그를 표시합니다.
void showAddDepartmentDialog(BuildContext context, String churchId) {
  final TextEditingController departmentController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final AccountingService accountingService = AccountingService();

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        // churchId에 따라 동적으로 제목을 설정합니다.
        title: Text('${churchId == '총회' ? '총회' : churchId} 부서 추가'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: departmentController,
            decoration: const InputDecoration(
              labelText: '부서 이름',
              hintText: '예: 청년부, 재정부 등',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '부서 이름을 입력하세요.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              // Form의 유효성 검사를 통과하면 부서 추가 로직 실행
              if (formKey.currentState!.validate()) {
                final departmentName = departmentController.text.trim();

                // AccountingService를 호출하여 Firestore에 데이터 추가
                accountingService.addDepartment(churchId, departmentName).then((_) {
                  Navigator.of(context).pop(); // 성공 시 다이얼로그 닫기
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('\'$departmentName\' 부서가 추가되었습니다.')),
                  );
                }).catchError((error) {
                   Navigator.of(context).pop(); // 실패 시에도 다이얼로그 닫기
                   ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('오류 발생: $error')),
                  );
                });
              }
            },
            child: const Text('추가'),
          ),
        ],
      );
    },
  );
}