part of 'home_bloc.dart';

abstract class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object> get props => [];
}

class HomeInitial extends HomeState {}

class HomeLoadInProgress extends HomeState {}

// ✨ [추가] role이 없어 권한이 없는 경우를 위한 새로운 상태
class HomeLoadNoPermission extends HomeState {
  final UserProfile userProfile;

  const HomeLoadNoPermission({required this.userProfile});

  @override
  List<Object> get props => [userProfile];
}

// --- ▼ [추가] 공지사항 관련 이벤트 ---
class HomeNoticesUpdated extends HomeEvent {
  final List<Notice> notices;
  const HomeNoticesUpdated(this.notices);
  @override
  List<Object> get props => [notices];
}

class HomeNoticeAdded extends HomeEvent {
  final String content;
  const HomeNoticeAdded(this.content);
  @override
  List<Object> get props => [content];
}

class HomeNoticeUpdated extends HomeEvent {
  final String noticeId;
  final String content;
  const HomeNoticeUpdated(this.noticeId, this.content);
  @override
  List<Object> get props => [noticeId, content];
}

class HomeNoticeDeleted extends HomeEvent {
  final String noticeId;
  const HomeNoticeDeleted(this.noticeId);
  @override
  List<Object> get props => [noticeId];
}
// --- ▲ [추가] 공지사항 관련 이벤트 ---

class HomeLoadSuccess extends HomeState {
  final UserProfile userProfile;
  final List<BentoItem> bentoItems;
  final List<BentoItem> originalBentoItems;
  final Church? churchInfo;
  final bool isEditing;
   // --- ▼ [추가] 사용자 직책(role)을 저장할 필드 ▼ ---
  final String userRole;
  // --- ▲ [추가] 사용자 직책(role)을 저장할 필드 ▲ ---
  final List<Notice> notices;

  const HomeLoadSuccess({
    required this.userProfile,
    required this.bentoItems,
    required this.originalBentoItems,
    required this.churchInfo,
    this.isEditing = false,
    // --- ▼ [추가] 생성자에 userRole 추가 ▼ ---
    required this.userRole,
    // --- ▲ [추가] 생성자에 userRole 추가 ▲ ---
    this.notices = const [],
  });

  HomeLoadSuccess copyWith({
    UserProfile? userProfile,
    List<BentoItem>? bentoItems,
    List<BentoItem>? originalBentoItems,
    Church? churchInfo,
    bool? isEditing,
      // --- ▼ [추가] copyWith에 userRole 추가 ▼ ---
    String? userRole,
    // --- ▲ [추가] copyWith에 userRole 추가 ▲ ---
    List<Notice>? notices,

  }) {
    return HomeLoadSuccess(
      userProfile: userProfile ?? this.userProfile,
      bentoItems: bentoItems ?? this.bentoItems,
      originalBentoItems: originalBentoItems ?? this.originalBentoItems,
      churchInfo: churchInfo ?? this.churchInfo,
      isEditing: isEditing ?? this.isEditing,
      // --- ▼ [추가] copyWith에 userRole 추가 ▼ ---
      userRole: userRole ?? this.userRole,
      // --- ▲ [추가] copyWith에 userRole 추가 ▲ ---
      notices: notices ?? this.notices,

    );
  }

  @override
  List<Object> get props =>
      [userProfile, bentoItems, originalBentoItems, if (churchInfo != null) churchInfo!, isEditing, userRole, notices];
}

class HomeLoadFailure extends HomeState {
  final String error;

  const HomeLoadFailure(this.error);

  @override
  List<Object> get props => [error];
}


