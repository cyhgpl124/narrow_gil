// lib/features/accounting/view/widgets/add_receipt_dialog.dart

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:narrow_gil/features/accounting/services/accounting_service.dart';

void showAddReceiptDialog(BuildContext context, {
  required String userId,
  required String userName,
  required String church, // 사용자의 기본 소속 교회
  String? district,       // 사용자의 기본 소속 구역
}) {
  final formKey = GlobalKey<FormState>();
  final amountController = TextEditingController();
  final customAreaController = TextEditingController();
  final AccountingService accountingService = AccountingService();

  List<XFile> selectedFiles = [];

  // 상태 변수
  String? selectedChurch = church;
  String? selectedArea = district;
  bool isOtherSelected = false;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> pickImages() async {
            final pickedXFiles = await ImagePicker().pickMultiImage();
            if (pickedXFiles.isNotEmpty) {
              setState(() {
                selectedFiles = pickedXFiles;
              });
            }
          }

          void handleSubmit() {
            if (formKey.currentState!.validate() && selectedFiles.isNotEmpty && selectedArea != null && selectedChurch != null) {
              final area = isOtherSelected ? customAreaController.text.trim() : selectedArea!;
              if (area.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('회계 구역을 입력하거나 선택하세요.')));
                  return;
              }

              accountingService.submitReceipt(
                userId: userId,
                userName: userName,
                church: selectedChurch!,
                files: selectedFiles,
                amount: double.parse(amountController.text),
                accountingArea: area,
              ).then((_) {
                 Navigator.of(context).pop();
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('성공적으로 제출되었습니다.')));
              }).catchError((e) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('제출 실패: $e')));
              });
            } else if (selectedFiles.isEmpty) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('하나 이상의 증빙 파일을 선택해야 합니다.')));
            }
          }

          return AlertDialog(
            title: const Text('영수증/증빙 제출'),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.65,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 이미지 선택 UI
                      InkWell(
                        onTap: pickImages,
                        child: Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: selectedFiles.isNotEmpty
                              ? CarouselSlider(
                                  options: CarouselOptions(height: 200, viewportFraction: 0.8, enlargeCenterPage: true),
                                  items: selectedFiles.map((xfile) {
                                    return Builder(
                                      builder: (BuildContext context) {
                                        return Container(
                                          width: MediaQuery.of(context).size.width,
                                          margin: const EdgeInsets.symmetric(horizontal: 5.0),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: kIsWeb ? Image.network(xfile.path, fit: BoxFit.contain) : Image.file(File(xfile.path), fit: BoxFit.contain),
                                          ),
                                        );
                                      },
                                    );
                                  }).toList(),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.camera_alt_outlined, size: 40, color: Colors.grey.shade600),
                                    const SizedBox(height: 8),
                                    const Text('영수증/이체증빙 업로드'),
                                    const Text('(여러 장 선택 가능)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 금액 입력 필드
                      TextFormField(
                        controller: amountController,
                        decoration: const InputDecoration(labelText: '지출/이체 금액', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        validator: (val) => val == null || val.isEmpty ? '금액을 입력하세요' : null,
                      ),
                      const SizedBox(height: 16),

                      // 교회 선택 드롭다운
                      FutureBuilder<List<String>>(
                        future: accountingService.getChurchNames(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                          final churchList = ['총회', ...snapshot.data!];
                          return DropdownButtonFormField<String>(
                            value: selectedChurch,
                            decoration: const InputDecoration(labelText: '소속 교회', border: OutlineInputBorder()),
                            items: churchList.map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(value: value, child: Text(value));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  selectedChurch = val;
                                  selectedArea = null;
                                  isOtherSelected = false;
                                });
                              }
                            },
                            validator: (val) => val == null ? '소속 교회를 선택하세요' : null,
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // 회계 구역 선택 드롭다운 (선택된 교회에 따라 동적으로 변경)
                      if (selectedChurch != null)
                        FutureBuilder<List<String>>(
                          future: accountingService.getAccountingAreas(selectedChurch!),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            final List<String> areas = ['기타', ...(snapshot.data ?? [])];

                            // --- ▼ [오류 수정] map의 타입을 명시적으로 지정 ▼ ---
                            return DropdownButtonFormField<String>(
                              value: areas.contains(selectedArea) ? selectedArea : null,
                              decoration: const InputDecoration(labelText: '회계 구역', border: OutlineInputBorder()),
                              items: areas.map<DropdownMenuItem<String>>((String area) {
                                return DropdownMenuItem<String>(value: area, child: Text(area));
                              }).toList(),
                              // --- ▲ [오류 수정] map의 타입을 명시적으로 지정 ▲ ---
                              onChanged: (val) {
                                setState(() {
                                  selectedArea = val;
                                  isOtherSelected = (val == '기타');
                                });
                              },
                              validator: (val) => val == null ? '회계 구역을 선택하세요' : null,
                            );
                          },
                        ),

                      if (isOtherSelected) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: customAreaController,
                          decoration: const InputDecoration(labelText: '기타 회계 구역명 입력', border: OutlineInputBorder()),
                           validator: (val) => isOtherSelected && (val == null || val.trim().isEmpty) ? '구역명을 입력하세요' : null,
                        ),
                      ]
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('취소')),
              ElevatedButton(onPressed: handleSubmit, child: const Text('제출')),
            ],
          );
        },
      );
    },
  );
}