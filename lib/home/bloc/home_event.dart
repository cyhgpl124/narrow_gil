part of 'home_bloc.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object> get props => [];
}

class HomeDataRequested extends HomeEvent {}

// 프로필 정보(점수 포함)만 새로고침하기 위한 이벤트
class HomeProfileRefreshed extends HomeEvent {}

// --- ▼ [추가] 새로운 문구 제출 이벤트 ---
class HomePhraseSubmitted extends HomeEvent {
  final String newPhrase;

  const HomePhraseSubmitted(this.newPhrase);

  @override
  List<Object> get props => [newPhrase];
}
// --- ▲ [추가] ---
// ✨ [수정] 공지 저장 이벤트에 dueDate 필드를 추가합니다.
class HomeNoticeSaved extends HomeEvent {
  final String? id;
  final String content;
  final DateTime dueDate; // D-Day 날짜

  const HomeNoticeSaved({this.id, required this.content, required this.dueDate});

  @override
  List<Object> get props => [id ?? '', content, dueDate ?? ''];
}


/// 관리자가 교회 정보를 수정하고 제출했을 때 발생하는 이벤트
class HomeChurchInfoSubmitted extends HomeEvent {
  final Map<String, dynamic> updatedData;

  const HomeChurchInfoSubmitted(this.updatedData);

  @override
  List<Object> get props => [updatedData];
}

class HomeSignedOut extends HomeEvent {}

/// 편집 모드를 토글(활성화/비활성화)하는 이벤트
class HomeEditModeToggled extends HomeEvent {}

/// 드래그 또는 크기 조절 중인 벤토 아이템의 정보를 업데이트하는 이벤트
class HomeBentoItemUpdated extends HomeEvent {
  final BentoItem updatedItem;
  const HomeBentoItemUpdated(this.updatedItem);
  @override
  List<Object> get props => [updatedItem];
}

/// 변경된 레이아웃을 Firestore에 저장하는 이벤트
class HomeLayoutSaved extends HomeEvent {}

class HomeEditCancelled extends HomeEvent {}

/// 레이아웃을 기본값으로 초기화하는 이벤트
class HomeLayoutResetRequested extends HomeEvent {}
