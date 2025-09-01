// lib/home/models/user_profile.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  final String uid;
  final String name;
  final String email;
  final String? photoURL;
  final String church;
  final String phoneNumber;
  final String birthdate;
  final String houseHoldHead;
  final int heavenlyScore;
  final Timestamp? lastLogin;
  // --- ▼ [추가] 사용자가 작성한 문구를 담을 리스트 ▼ ---
  final List<String> phrases;
  // --- ▲ [추가] 사용자가 작성한 문구를 담을 리스트 ▲ ---

  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.houseHoldHead,
    this.photoURL,
    required this.church,
    required this.phoneNumber,
    required this.birthdate,
    this.heavenlyScore = 0,
    this.lastLogin,
    // --- ▼ [추가] 생성자에 phrases 추가, 기본값은 빈 리스트 ▼ ---
    this.phrases = const [],
    // --- ▲ [추가] 생성자에 phrases 추가, 기본값은 빈 리스트 ▲ ---
  });

  factory UserProfile.fromFirestore(Map<String, dynamic> data, String id, {int? score, Timestamp? loginTime, String? houseHoldHead}) {
    return UserProfile(
      uid: id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      photoURL: data['photoURL'],
      church: data['church'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      birthdate: data['birthdate'] ?? '',
      heavenlyScore: score ?? 0,
      houseHoldHead: houseHoldHead ?? '',
      lastLogin: loginTime,
      // --- ▼ [추가] Firestore 데이터에서 phrases 필드를 읽어오도록 수정 ▼ ---
      // data['phrases']가 null일 경우 빈 리스트를 반환하도록 처리
      phrases: List<String>.from(data['phrases'] ?? []),
      // --- ▲ [추가] Firestore 데이터에서 phrases 필드를 읽어오도록 수정 ▲ ---
    );
  }

  // UserProfile 객체의 일부 필드만 변경하여 새로운 객체를 생성하는 copyWith 메서드
  UserProfile copyWith({
    String? uid,
    String? name,
    String? email,
    String? photoURL,
    String? church,
    String? phoneNumber,
    String? birthdate,
    String? houseHoldHead,
    int? heavenlyScore,
    Timestamp? lastLogin,
    // --- ▼ [추가] copyWith에 phrases 필드 추가 ▼ ---
    List<String>? phrases,
    // --- ▲ [추가] copyWith에 phrases 필드 추가 ▲ ---
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      photoURL: photoURL ?? this.photoURL,
      church: church ?? this.church,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      birthdate: birthdate ?? this.birthdate,
      heavenlyScore: heavenlyScore ?? this.heavenlyScore,
      houseHoldHead: houseHoldHead ?? this.houseHoldHead,
      lastLogin: lastLogin ?? this.lastLogin,
      // --- ▼ [추가] copyWith에 phrases 필드 추가 ▼ ---
      phrases: phrases ?? this.phrases,
      // --- ▲ [추가] copyWith에 phrases 필드 추가 ▲ ---
    );
  }

  @override
  // --- ▼ [수정] props 리스트에 phrases 추가 ▼ ---
  List<Object?> get props => [uid, name, email, photoURL, church, phoneNumber, birthdate, heavenlyScore, houseHoldHead, lastLogin, phrases];
  // --- ▲ [수정] props 리스트에 phrases 추가 ▲ ---
}