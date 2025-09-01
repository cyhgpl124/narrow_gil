import 'package:cloud_firestore/cloud_firestore.dart';

class Member {
  final String id;
  final String name;
  final String phoneNumber;
  final String? baptismDate;
  final String district;
  final String role;
  final String gender;
  final Timestamp? lastLogin;
  final int heavenlyScore;
  final String houseHoldHead;
  final int donation;

  Member({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.district,
    this.baptismDate,
    required this.role,
    required this.gender,
    this.lastLogin,
    required this.heavenlyScore,
    required this.houseHoldHead,
    required this.donation,
  });

  factory Member.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Member(
      id: doc.id,
      name: data['name'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      district: data['district'] ?? '', // 'district' 필드 읽기
      baptismDate: data['baptismDate'],
      role: data['role'] ?? '',
      gender: data['gender'] ?? '미정',
      lastLogin: data['lastLogin'],
      heavenlyScore: data['skyScore'] ?? 0,
      houseHoldHead: data['houseHoldHead'] ?? '',
      donation: data['donation'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'baptismDate': baptismDate,
      'district': district, // ✨ 'district'를 'district'으로 수정하여 통일
      'role': role,
      'gender': gender,
      'lastLogin': lastLogin,
      'skyScore': heavenlyScore,
      'houseHoldHead': houseHoldHead,
      'donation': donation,
    };
  }
}
