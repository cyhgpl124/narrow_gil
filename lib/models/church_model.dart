// lib/models/church_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class Church extends Equatable {
  final String name;
  final String zoomLink;
  final String driveLink;
  final List<String> districts; // 구역
  final String presbytery; // 노회명
  final String businessNumber; // 사업자번호
  final String address;
  final List<String> positions; // 직책

  const Church({
    required this.name,
    this.driveLink = '',
    this.zoomLink = '',
    this.districts = const [],
    this.presbytery = '',
    this.businessNumber = '',
    this.address = '',
    this.positions = const [],
  });

  factory Church.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Church(
      name: doc.id,
      driveLink: data['drive'] ?? '',
      zoomLink: data['zoom'] ?? '',
      // Firestore의 array를 List<String>으로 변환
      districts: List<String>.from(data['구역'] ?? []),
      presbytery: data['노회명'] ?? '',
      businessNumber: data['사업자번호'] ?? '',
      address: data['주소'] ?? '',
      positions: List<String>.from(data['직책'] ?? []),
    );
  }

  Church copyWith({
    String? name,
    String? driveLink,
    String? zoomLink,
    List<String>? districts,
    String? presbytery,
    String? businessNumber,
    String? address,
    List<String>? positions,
  }) {
    return Church(
      name: name ?? this.name,
      driveLink: driveLink ?? this.driveLink,
      zoomLink: zoomLink ?? this.zoomLink,
      districts: districts ?? this.districts,
      presbytery: presbytery ?? this.presbytery,
      businessNumber: businessNumber ?? this.businessNumber,
      address: address ?? this.address,
      positions: positions ?? this.positions,
    );
  }

  @override
  List<Object?> get props => [
        name,
        driveLink,
        zoomLink,
        districts,
        presbytery,
        businessNumber,
        address,
        positions
      ];
}