import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:narrow_gil/home/models/bento_item.dart';
import 'package:narrow_gil/features/user/user_service.dart';
import 'package:narrow_gil/home/models/notice_model.dart';
import 'package:narrow_gil/home/models/user_profile.dart';
import 'package:narrow_gil/models/church_model.dart'; // [추가]

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;
  final UserService _userService;
  StreamSubscription? _noticesSubscription; // ✨ [추가] 공지 리스너


  HomeBloc({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
    UserProfile? userProfile,
    UserService? userService,
    Church? church,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _userService = userService ?? UserService(),
        _googleSignIn = googleSignIn ?? GoogleSignIn(),
        super(userProfile != null
            ? HomeLoadSuccess(
                userRole: '', // 초기값
                userProfile: userProfile,
                bentoItems: const [],
                originalBentoItems: const [],
                churchInfo: null)
            : HomeInitial()) {
    on<HomeDataRequested>(_onDataRequested);
    // 새로고침 이벤트 핸들러 등록
    on<HomeProfileRefreshed>(_onProfileRefreshed);
    on<HomeSignedOut>(_onSignedOut);
    on<HomeEditModeToggled>(_onEditModeToggled);
    on<HomeBentoItemUpdated>(_onBentoItemUpdated);
    on<HomeLayoutSaved>(_onLayoutSaved);
    on<HomeEditCancelled>(_onEditCancelled);
    on<HomeLayoutResetRequested>(_onLayoutResetRequested);
    on<HomePhraseSubmitted>(_onPhraseSubmitted); // [추가] 새 이벤트 핸들러 등록
    on<HomeChurchInfoSubmitted>(_onChurchInfoSubmitted); // [추가]
    on<HomeNoticesUpdated>(_onNoticesUpdated); // ✨ [추가]
    on<HomeNoticeAdded>(_onNoticeAdded); // ✨ [추가]
    on<HomeNoticeUpdated>(_onNoticeUpdated); // ✨ [추가]
    on<HomeNoticeDeleted>(_onNoticeDeleted); // ✨ [추가]


  }

   @override
  Future<void> close() {
    _noticesSubscription?.cancel(); // ✨ [추가] Bloc이 닫힐 때 리스너도 해제
    return super.close();
  }

  // --- ▼ [추가] 공지사항 관련 이벤트 핸들러들 ---
  void _onNoticesUpdated(HomeNoticesUpdated event, Emitter<HomeState> emit) {
    if (state is HomeLoadSuccess) {
      emit((state as HomeLoadSuccess).copyWith(notices: event.notices));
    }
  }

  Future<void> _onNoticeAdded(
      HomeNoticeAdded event, Emitter<HomeState> emit) async {
    if (state is HomeLoadSuccess) {
      final currentState = state as HomeLoadSuccess;
      try {
        await _userService.addNotice(currentState.userProfile.church,
            event.content, currentState.userProfile.name);
      } catch (e) {
        // Handle error
      }
    }
  }

  Future<void> _onNoticeUpdated(
      HomeNoticeUpdated event, Emitter<HomeState> emit) async {
    if (state is HomeLoadSuccess) {
      final churchId = (state as HomeLoadSuccess).userProfile.church;
      try {
        await _userService.updateNotice(churchId, event.noticeId, event.content);
      } catch (e) {
        // Handle error
      }
    }
  }

  Future<void> _onNoticeDeleted(
      HomeNoticeDeleted event, Emitter<HomeState> emit) async {
    if (state is HomeLoadSuccess) {
      final churchId = (state as HomeLoadSuccess).userProfile.church;
      try {
        await _userService.deleteNotice(churchId, event.noticeId);
      } catch (e) {
        // Handle error
      }
    }
  }
  // --- ▲ [추가] ---


// --- ▼ [추가] 교회 정보 업데이트 이벤트 핸들러 ---
  Future<void> _onChurchInfoSubmitted(
    HomeChurchInfoSubmitted event,
    Emitter<HomeState> emit,
  ) async {
    final currentState = state;
    if (currentState is HomeLoadSuccess) {
      // 1. UI를 즉시 업데이트 (낙관적 UI)
      final optimisticChurch = currentState.churchInfo?.copyWith(
        zoomLink: event.updatedData['zoom'],
        districts: event.updatedData['구역'],
        presbytery: event.updatedData['노회명'],
        businessNumber: event.updatedData['사업자번호'],
        address: event.updatedData['주소'],
        positions: event.updatedData['직책'],
      );
      emit(currentState.copyWith(churchInfo: optimisticChurch));

      // 2. 백그라운드에서 Firestore 업데이트
      try {
        await _userService.updateChurchDetails(currentState.userProfile.church, event.updatedData);
      } catch (e) {
        print("교회 정보 업데이트 실패: $e");
        emit(currentState); // 실패 시 원래 상태로 복원
      }
    }
  }
  // --- ▲ [추가] ---

// --- ▼ [추가] 낙관적 UI 로직을 처리하는 이벤트 핸들러 ---
Future<void> _onPhraseSubmitted(
    HomePhraseSubmitted event,
    Emitter<HomeState> emit,
  ) async {
    final currentState = state;
    if (currentState is HomeLoadSuccess) {
      // 1. 현재 상태의 phrases 리스트를 복사하고 새 문구를 추가합니다.
      final newPhrases = List<String>.from(currentState.userProfile.phrases)
        ..add(event.newPhrase);

      // 2. 변경된 phrases 리스트를 포함한 새로운 UserProfile 객체를 만듭니다.
      final optimisticProfile = currentState.userProfile.copyWith(phrases: newPhrases);

      // 3. UI를 즉시 업데이트하기 위해 변경된 UserProfile로 새로운 상태를 emit합니다.
      emit(currentState.copyWith(userProfile: optimisticProfile));

      // 4. 백그라운드에서 실제 Firestore에 데이터를 저장합니다.
      try {
        await _userService.addUserPhrase(currentState.userProfile.uid, event.newPhrase);
        // 성공 시, 특별히 할 일은 없습니다. 이미 UI는 업데이트되었기 때문입니다.
        // 만약 실패 시, 이전 상태로 되돌리는 로직을 추가할 수 있습니다.
      } catch (e) {
        print("문구 저장 실패: $e");
        // [선택사항] 저장 실패 시 사용자에게 알리고 UI를 원래 상태로 되돌립니다.
        emit(currentState); // 이전 상태로 복원
      }
    }
  }
  // --- ▲ [추가] ---


Future<void> _onDataRequested(
    HomeDataRequested event,
    Emitter<HomeState> emit,
  ) async {
    UserProfile? userProfile;
    if (state is HomeLoadSuccess) {
      userProfile = (state as HomeLoadSuccess).userProfile;
    } else if (state is HomeInitial && _firebaseAuth.currentUser != null) {
      final userDoc = await _firestore.collection('users').doc(_firebaseAuth.currentUser!.uid).get();
      if (userDoc.exists) {
        userProfile = UserProfile.fromFirestore(userDoc.data()!, userDoc.id);
      }
    }

    if (userProfile == null) {
      emit(const HomeLoadFailure("사용자 프로필을 찾을 수 없습니다."));
      return;
    }

    try {
      final user = _firebaseAuth.currentUser!;
      String? userPosition;
      final phoneNumber = userProfile.phoneNumber;
      final church = userProfile.church;

      // --- ▼ [수정] 교회 전체 정보를 가져옵니다 ---
      final churchInfo = await _userService.getChurchDetails(church);
      // --- ▲ [수정] ---
      // --- ▼ [수정] approved_members에서 role과 houseHoldHead를 함께 가져옵니다. ---
      if (phoneNumber.isNotEmpty) {
        final approvedMemberQuery = await _firestore
            .collection('approved_members').doc(church).collection('members')
            .where('phoneNumber', isEqualTo: phoneNumber).limit(1).get();

        if (approvedMemberQuery.docs.isNotEmpty) {
          final memberData = approvedMemberQuery.docs.first.data();
          userPosition = memberData['role'] as String?;

          // 'houseHoldHead' 필드를 가져옵니다.
          final houseHoldHead = memberData['houseHoldHead'] as String?;

          // userProfile 객체를 새로운 정보로 업데이트합니다.
          userProfile = userProfile.copyWith(houseHoldHead: houseHoldHead);
        }
      }
      // --- ▲ [수정] ---

      if (userPosition == null || userPosition.isEmpty) {
        emit(HomeLoadNoPermission(userProfile: userProfile));
        return;
      }

      final layoutCollection = _firestore.collection('users').doc(user.uid).collection('layout_items');
      final layoutSnapshot = await layoutCollection.get();

      // 기본 아이템 목록 (역할에 따른 '교인 관리' 버튼 포함)
      List<BentoItem> defaultItems = BentoItem.defaultItems;
      const List<String> adminRoles = ['목회자', '서기', '개발자'];
      if (adminRoles.contains(userPosition)) {
        defaultItems.add(const BentoItem(id: 'member_management', title: '교인 관리', route: '/member_management', x: 0, y: 0, width: 0, height: 0));
      }

      // Firestore에 저장된 사용자 레이아웃
      final existingItems = layoutSnapshot.docs.map((doc) => BentoItem.fromFirestore(doc.data(), doc.id)).toList();

      // 새로 추가된 기본 아이템이 있는지 확인
      final existingItemIds = existingItems.map((item) => item.id).toSet();
      final missingItems = defaultItems.where((item) => !existingItemIds.contains(item.id)).toList();

      // 최종적으로 화면에 표시될 아이템 목록
      List<BentoItem> allItems = [...existingItems, ...missingItems];

      // 새로 추가된 아이템이 있으면 Firestore에 저장
      if (missingItems.isNotEmpty) {
        final batch = _firestore.batch();
        // 새로 추가된 아이템만 저장 (전체 재정렬은 나중에)
        for (final item in missingItems) {
          final docRef = layoutCollection.doc(item.id);
          batch.set(docRef, item.toFirestore());
        }
        await batch.commit();
      }

      // 최종 아이템 목록을 자동 정렬하여 emit
      final finalLaidOutItems = BentoItem.applyGridAutoLayout(allItems);

      emit(HomeLoadSuccess(
        userProfile: userProfile,
        userRole: userPosition, // role 정보를 상태에 담아서 전달
        churchInfo: churchInfo!, // [수정] 상태에 교회 정보 추가
        bentoItems: finalLaidOutItems,
        originalBentoItems: List.from(finalLaidOutItems),
        isEditing: (state is HomeLoadSuccess) ? (state as HomeLoadSuccess).isEditing : false,
      ));

      // ✨ [추가] 공지사항 실시간 리스닝 시작
      _noticesSubscription?.cancel();
      _noticesSubscription =
          _userService.getNotices(userProfile.church).listen((notices) {
        add(HomeNoticesUpdated(notices));
        });
      // ✨ [추가]
    } catch (e) {
      emit(HomeLoadFailure(e.toString()));
    }
  }

  // 프로필 새로고침 로직
  Future<void> _onProfileRefreshed(
    HomeProfileRefreshed event,
    Emitter<HomeState> emit,
  ) async {
    if (state is! HomeLoadSuccess) return;
    final currentState = state as HomeLoadSuccess;
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      emit(const HomeLoadFailure('사용자 정보가 없습니다.'));
      return;
    }

    try {
      // 1. users 컬렉션에서 사용자 정보 가져오기
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return;

      final phoneNumber = userDoc.data()?['phoneNumber'] as String?;
      final church = userDoc.data()?['church'] as String?;
      if (phoneNumber == null || phoneNumber.isEmpty) return;

      // 2. approved_members 컬렉션에서 최신 skyScore 가져오기
      final approvedMembersQuery = await _firestore
          .collection('approved_members')
          .doc(church)
          .collection('members')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();

      if (approvedMembersQuery.docs.isEmpty) return;

      final memberData = approvedMembersQuery.docs.first.data();
      final latestScore = memberData['skyScore'] as int?;
      final latestName = memberData['name'] as String?;
      final latestNumber = memberData['phoneNumber'] as String?;
      final latestHouseHoldHead = memberData['houseHoldHead'] as String?;
      final latestPhrase = memberData['phrases'] as List<String>?;

      // 3. 기존 상태를 새로운 점수로 업데이트하여 emit
      emit(currentState.copyWith(
        userProfile:
            currentState.userProfile.copyWith(heavenlyScore: latestScore, name: latestName, phoneNumber: latestNumber, houseHoldHead: latestHouseHoldHead, phrases: latestPhrase),
      ));
    } catch (e) {
      // 에러가 발생해도 기존 상태는 유지
      print("점수 새로고침 중 오류 발생: $e");
    }
  }

  Future<void> _onSignedOut(
    HomeSignedOut event,
    Emitter<HomeState> emit,
  ) async {
    try {
      // Google Sign-In을 먼저 로그아웃하고 Firebase에서 로그아웃합니다.
      await _googleSignIn.signOut();
      await _firebaseAuth.signOut();
    } catch (e) {
      // 오류 발생 시 콘솔에 로그를 출력합니다.
      print('Error signing out: $e');
    }
  }


  void _onEditModeToggled(
    HomeEditModeToggled event,
    Emitter<HomeState> emit,
  ) {
    if (state is HomeLoadSuccess) {
      final currentState = state as HomeLoadSuccess;
      final newIsEditing = !currentState.isEditing;

      if (newIsEditing) {
        emit(currentState.copyWith(
          isEditing: true,
          originalBentoItems: List.from(currentState.bentoItems),
        ));
      } else {
        // 편집 모드 종료 시 자동 저장 및 정렬
        add(HomeLayoutSaved());
      }
    }
  }

  bool _isColliding(BentoItem item1, BentoItem item2) {
    const epsilon = 0.001;

    final item1Right = item1.x + item1.width;
    final item1Bottom = item1.y + item1.height;
    final item2Right = item2.x + item2.width;
    final item2Bottom = item2.y + item2.height;

    return (item1.x < item2Right - epsilon &&
        item1Right > item2.x + epsilon &&
        item1.y < item2Bottom - epsilon &&
        item1Bottom > item2.y + epsilon);
  }

  void _onBentoItemUpdated(
    HomeBentoItemUpdated event,
    Emitter<HomeState> emit,
  ) {
    if (state is! HomeLoadSuccess) return;
    final currentState = state as HomeLoadSuccess;
    final movedItem = event.updatedItem;

    List<BentoItem> newItems = currentState.bentoItems.map((item) {
      return item.id == movedItem.id ? movedItem : item;
    }).toList();

    bool collisionOccurred;
    int iterations = 0;
    const maxIterations = 100;

    do {
      collisionOccurred = false;
      iterations++;
      newItems.sort((a, b) {
        int yCompare = a.y.compareTo(b.y);
        if (yCompare != 0) return yCompare;
        return a.x.compareTo(b.x);
      });

      for (int i = 0; i < newItems.length; i++) {
        for (int j = i + 1; j < newItems.length; j++) {
          final itemA = newItems[i];
          final itemB = newItems[j];

          if (_isColliding(itemA, itemB)) {
            final newY = itemA.y + itemA.height;
            if ((itemB.y - newY).abs() > 0.0001) {
              newItems[j] = itemB.copyWith(y: newY);
              collisionOccurred = true;
            }
          }
        }
      }
    } while (collisionOccurred && iterations < maxIterations);

    emit(currentState.copyWith(bentoItems: newItems));
  }

  // --- ▼ [수정] 레이아웃 저장 시 자동 정렬 로직 적용 ▼ ---
  Future<void> _onLayoutSaved(
    HomeLayoutSaved event,
    Emitter<HomeState> emit,
  ) async {
    if (state is HomeLoadSuccess) {
      final currentState = state as HomeLoadSuccess;
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        emit(const HomeLoadFailure('사용자 정보가 없어 저장할 수 없습니다.'));
        return;
      }

      // 1. 현재 아이템 목록을 가져와서 자동 정렬
      final realignedItems = BentoItem.applyGridAutoLayout(currentState.bentoItems);

      try {
        final layoutCollection = _firestore.collection('users').doc(user.uid).collection('layout_items');
        final batch = _firestore.batch();

        // 2. 정렬된 아이템을 Firestore에 저장
        for (final item in realignedItems) {
          batch.set(layoutCollection.doc(item.id), item.toFirestore());
        }
        await batch.commit();

        // 3. 정렬된 레이아웃으로 상태 업데이트 및 편집 모드 종료
        emit(currentState.copyWith(
          isEditing: false,
          bentoItems: realignedItems,
          originalBentoItems: List.from(realignedItems),
        ));
      } catch (e) {
        emit(HomeLoadFailure('레이아웃 저장 중 오류 발생: $e'));
      }
    }
  }
  // --- ▲ [수정] 레이아웃 저장 시 자동 정렬 로직 적용 ▲ ---



  void _onEditCancelled(
    HomeEditCancelled event,
    Emitter<HomeState> emit,
  ) {
    if (state is HomeLoadSuccess) {
      final currentState = state as HomeLoadSuccess;
      emit(currentState.copyWith(
        bentoItems: currentState.originalBentoItems,
        isEditing: false,
      ));
    }
  }

  // --- ▼ [수정] approved_members에서 role 정보를 가져오도록 수정 ▼ ---
  Future<void> _onLayoutResetRequested(
    HomeLayoutResetRequested event,
    Emitter<HomeState> emit,
  ) async {
    if (state is! HomeLoadSuccess) return;
    final currentState = state as HomeLoadSuccess;
    final user = _firebaseAuth.currentUser;
    if (user == null) return;

    try {
      final layoutCollection = _firestore.collection('users').doc(user.uid).collection('layout_items');
      final batch = _firestore.batch();

      final snapshot = await layoutCollection.get();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      // 기본 아이템 목록 가져오기
      List<BentoItem> defaultItems = BentoItem.defaultItems;
      const List<String> adminRoles = ['목회자', '서기', '개발자'];

      // BLoC의 현재 상태에 저장된 role 정보를 사용
      if (adminRoles.contains(currentState.userRole)) {
          defaultItems.add(const BentoItem(id: 'member_management', title: '교인 관리', route: '/member_management', x: 0, y: 0, width: 0, height: 0));
      }
      // --- ▲ [수정] Firestore를 다시 조회하는 대신, 현재 BLoC 상태의 userRole을 사용 ▲ ---


      // 자동 정렬 적용
      final finalDefaultItems = BentoItem.applyGridAutoLayout(defaultItems);

      for (final item in finalDefaultItems) {
        batch.set(layoutCollection.doc(item.id), item.toFirestore());
      }
      await batch.commit();

      emit(currentState.copyWith(
          bentoItems: finalDefaultItems,
          originalBentoItems: List.from(finalDefaultItems)));
    } catch (e) {
      emit(HomeLoadFailure('레이아웃 초기화 중 오류 발생: $e'));
    }
  }
  // --- ▲ [수정] approved_members에서 role 정보를 가져오도록 수정 ▲ ---
}
