enum AttendanceStatus {
  none, // 미출석
  present, // 출석
  remote, // 비대면
}

// Firestore에 저장된 문자열을 enum으로, enum을 문자열로 변환하기 위한 확장 기능
extension AttendanceStatusExtension on String {
  AttendanceStatus toAttendanceStatus() {
    switch (this) {
      case 'present':
        return AttendanceStatus.present;
      case 'remote':
        return AttendanceStatus.remote;
      case 'absent': // BLoC와의 호환성을 위해 'absent'도 'none'으로 처리
        return AttendanceStatus.none;
      default:
        return AttendanceStatus.none;
    }
  }
}

extension AttendanceStatusValueExtension on AttendanceStatus {
  String get value {
    switch (this) {
      case AttendanceStatus.present:
        return 'present';
      case AttendanceStatus.remote:
        return 'remote';
      case AttendanceStatus.none:
        // BLoC와의 일관성을 위해 Firestore에는 'absent'로 저장합니다.
        return 'absent';
    }
  }
}
