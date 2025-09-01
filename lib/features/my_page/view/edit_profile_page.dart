// lib/features/my_page/view/edit_profile_page.dart

import 'package:flutter/material.dart';
import 'package:narrow_gil/features/user/user_service.dart';
import 'package:narrow_gil/home/models/user_profile.dart';

class EditProfilePage extends StatefulWidget {
  final UserProfile userProfile;
  const EditProfilePage({super.key, required this.userProfile});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final UserService _userService = UserService();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _houseHoldHeadController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userProfile.name);
    _phoneController = TextEditingController(text: widget.userProfile.phoneNumber);
    _houseHoldHeadController = TextEditingController(text: widget.userProfile.houseHoldHead);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _houseHoldHeadController.dispose();
    super.dispose();
  }

  // --- ▼ [수정] 세대주 정보도 함께 업데이트하도록 로직 변경 ---
  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await _userService.updateUserProfile(
          userId: widget.userProfile.uid,
          churchName: widget.userProfile.church,
          newName: _nameController.text.trim(),
          newPhoneNumber: _phoneController.text.trim(),
          newHouseHoldHead: _houseHoldHeadController.text.trim(), // [추가] 세대주 값 전달
        );

        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('프로필이 성공적으로 업데이트되었습니다.')),
            );
            Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('프로필 업데이트 중 오류가 발생했습니다: $e')),
            );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필 수정'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '이름',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '이름을 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: '핸드폰 번호',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '핸드폰 번호를 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // --- ▼ [추가] 세대주 정보 입력을 위한 TextFormField ---
              TextFormField(
                controller: _houseHoldHeadController,
                decoration: const InputDecoration(
                  labelText: '세대주',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '세대주를 입력해주세요.';
                  }
                  return null;
                },
              ),
              // --- ▲ [추가] ---
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _updateProfile,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('수정 완료'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}