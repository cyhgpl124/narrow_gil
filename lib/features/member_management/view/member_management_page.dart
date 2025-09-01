import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:narrow_gil/features/member_management/models/member_log_model.dart';
import 'package:narrow_gil/features/member_management/models/member_model.dart';
import 'package:narrow_gil/features/member_management/services/member_management_service.dart';
import 'package:narrow_gil/home/bloc/home_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

import 'package:narrow_gil/home/models/user_profile.dart';

class MemberManagementPage extends StatefulWidget {
  const MemberManagementPage({super.key});

  @override
  State<MemberManagementPage> createState() => _MemberManagementPageState();
}

class _MemberManagementPageState extends State<MemberManagementPage> {
  final MemberManagementService _service = MemberManagementService();
  bool _isLoading = false;

  // CSV 업로드 로직 (기존과 동일)
  Future<void> _uploadCSV() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() => _isLoading = true);
      try {
        final churchName = (context.read<HomeBloc>().state as HomeLoadSuccess)
            .userProfile
            .church;
        await _service.uploadMembersFromCSV(
            result.files.single.bytes!, churchName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CSV 파일이 성공적으로 업로드 및 처리되었습니다.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('CSV 처리 중 오류 발생: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfile =
        (context.read<HomeBloc>().state as HomeLoadSuccess).userProfile;


    return Scaffold(
      appBar: AppBar(
        title: const Text('교인 관리'),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white))
                : const Icon(Icons.upload_file),
            onPressed: _isLoading ? null : _uploadCSV,
            tooltip: 'CSV 업로드',
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 교인 목록 테이블
          Expanded(
            flex: 3,
            // --- ▼ [수정] StreamBuilder 진단 기능 강화 ---
            child: StreamBuilder<List<Member>>(
              stream: _service.getMembers(userProfile.church),
              builder: (context, snapshot) {
                // 1. 에러 상태 확인
                if (snapshot.hasError) {
                  print("getMembers 스트림 에러: ${snapshot.error}");
                  return Center(
                    child: Text(
                      '데이터를 불러오는 중 오류가 발생했습니다.\n오류: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                // 2. 연결 상태에 따른 UI 표시
                switch (snapshot.connectionState) {
                  case ConnectionState.waiting:
                    print("getMembers: 데이터를 기다리는 중... (waiting)");
                    return const Center(child: CircularProgressIndicator());

                  case ConnectionState.none:
                    print("getMembers: 스트림이 연결되지 않음 (none)");
                    return const Center(child: Text('데이터 연결이 없습니다.'));

                  case ConnectionState.done:
                    print("getMembers: 스트림이 종료됨 (done)");
                    return const Center(child: Text('데이터 스트림이 종료되었습니다.'));

                  case ConnectionState.active:
                    print("getMembers: 데이터 스트림 활성화 (active)");
                    // 3. 데이터 유무 확인
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      print("getMembers: 데이터는 받았으나 비어있습니다.");
                      return const Center(child: Text('등록된 교인이 없습니다.'));
                    }

                    // 4. 데이터 성공적으로 받아온 경우
                    final members = snapshot.data!;
                    print("getMembers: ${members.length}명의 교인 데이터를 성공적으로 받았습니다.");

                    return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('이름')),
                            DataColumn(label: Text('번호')),
                            DataColumn(label: Text('세례날짜')),
                            DataColumn(label: Text('구역')),
                            DataColumn(label: Text('직책')),
                            DataColumn(label: Text('성별')),
                            DataColumn(label: Text('세대주')),
                            DataColumn(label: Text('삭제')),
                          ],
                          rows: members
                              .map((member) => DataRow(
                                    cells: [
                                      DataCell(Text(member.name),
                                          onTap: () => _showEditDialog(
                                              context, member, 'name', userProfile)),
                                      DataCell(Text(member.phoneNumber),
                                          onTap: () => _showEditDialog(context,
                                              member, 'phoneNumber', userProfile)),
                                      DataCell(Text(member.baptismDate ?? ''),
                                          onTap: () => _showEditDialog(context,
                                              member, 'baptismDate', userProfile)),
                                      DataCell(Text(member.district),
                                          onTap: () => _showEditDialog(context,
                                              member, 'district', userProfile)),
                                      DataCell(Text(member.role),
                                          onTap: () => _showEditDialog(
                                              context, member, 'position', userProfile)),
                                      DataCell(Text(member.gender),
                                          onTap: () => _showEditDialog(
                                              context,
                                              member,
                                              'gender',
                                              userProfile)),
                                      DataCell(Text(member.houseHoldHead),
                                          onTap: () => _showEditDialog(context,
                                              member, 'houseHoldHead', userProfile)),
                                      DataCell(
                                        IconButton(
                                          icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                                          onPressed: () => _showDeleteConfirmDialog(context, member, userProfile),
                                        )
                                      ),
                                    ],
                                  ))
                              .toList(),
                        ),
                      ),
                    );
                }
              },
            ),
            // --- ▲ [수정] ---
          ),
          // 변경사항 로그
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey.shade800,
              child: StreamBuilder<List<MemberLog>>(
                stream: _service.getMemberLogs(userProfile.church),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  final logs = snapshot.data!;
                  return ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return ListTile(
                              // [수정] 글자 크기 축소
                              title: Text(
                                  '${log.memberName}: ${log.field} 변경',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                  '${log.oldValue} -> ${log.newValue}\n(수정: ${log.editorName}, ${DateFormat('yy.MM.dd HH:mm').format(log.editedAt.toDate())})',
                                  style: const TextStyle(fontSize: 12),
                              ),
                            );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      // ✨ 새로운 행(교인) 추가 버튼
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            _showAddMemberDialog(context, userProfile.church, userProfile.name),
        tooltip: '교인 추가',
        child: const Icon(Icons.add),
      ),
    );
  }

  // --- ▼ [구현] 교인 삭제 확인 다이얼로그 ---
  void _showDeleteConfirmDialog(BuildContext context, Member member, UserProfile userProfile) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("교인 삭제 확인"),
        content: Text("'${member.name}' 님의 모든 정보를 정말로 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("취소"),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              // 서비스의 deleteMember 함수 호출
              _service.deleteMember(
                churchName: userProfile.church,
                memberId: member.id,
                memberName: member.name,
                editorName: userProfile.name,
              );
              Navigator.pop(dialogContext); // 다이얼로그 닫기
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("'${member.name}' 님의 정보가 삭제되었습니다.")),
              );
            },
            child: const Text("삭제"),
          ),
        ],
      ),
    );
  }

  // 기존 정보 수정 다이얼로그
  void _showEditDialog(BuildContext context, Member member, String field,
      UserProfile userprofile) {
    final controller =
        TextEditingController(text: _service.getOldValue(member, field));
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${member.name} - $field 수정'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소')),
          TextButton(
            onPressed: () {
              // ✨ MemberManagementService에 있는 updateMemberField 호출
              _service.updateMemberField(member.id, field, controller.text,
                  userprofile.church, userprofile.name, member);
              Navigator.pop(dialogContext);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  // ✨ 새로운 교인 추가 다이얼로그
  void _showAddMemberDialog(
      BuildContext context, String churchName, String editorName) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final baptismDateController = TextEditingController();
    final roleController = TextEditingController();
    final genderController = TextEditingController();
    final districtController = TextEditingController();
    final houseHoldHeadController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('새 교인 추가'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: '이름')),
                TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: '전화번호')),
                TextField(
                    controller: genderController,
                    decoration: const InputDecoration(labelText: '성별')),
                TextField(
                    controller: roleController,
                    decoration: const InputDecoration(labelText: '직책')),
                TextField(
                    controller: baptismDateController,
                    decoration: const InputDecoration(labelText: '세례날짜(선택)')),
                TextField(
                    controller: districtController,
                    decoration:
                        const InputDecoration(labelText: '구역(선택)')),
                TextField(
                    controller: houseHoldHeadController,
                    decoration:
                        const InputDecoration(labelText: '세대주')),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('취소')),
            TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty &&
                    phoneController.text.isNotEmpty) {
                  // ✨ MemberManagementService에 새로운 멤버를 추가하는 메서드를 호출 (이 메서드는 서비스에 구현해야 함)
                  _service.addMember(
                      name: nameController.text,
                      phoneNumber: phoneController.text,
                      gender: genderController.text,
                      role: roleController.text,
                      baptismDate: baptismDateController.text,
                      district: districtController.text,
                      houseHoldHead: houseHoldHeadController.text,
                      churchName: churchName);
                  print('새 멤버 추가 로직 호출 필요'); // TODO: 서비스에 실제 추가 로직 구현
                  Navigator.pop(dialogContext);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('이름과 전화번호는 필수 항목입니다.')),
                  );
                }
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }
}
