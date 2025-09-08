// lib/home/models/bento_item.dart

import 'package:equatable/equatable.dart';

class BentoItem extends Equatable {
  final String id;
  final String title;
  final String route;
  final double x;
  final double y;
  final double width;
  final double height;

  const BentoItem({
    required this.id,
    required this.title,
    required this.route,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  BentoItem copyWith({
    String? id,
    String? title,
    String? route,
    double? x,
    double? y,
    double? width,
    double? height,
  }) {
    return BentoItem(
      id: id ?? this.id,
      title: title ?? this.title,
      route: route ?? this.route,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  factory BentoItem.fromFirestore(Map<String, dynamic> data, String id) {
    return BentoItem(
      id: id,
      title: data['title'] ?? '',
      route: data['route'] ?? '/',
      x: (data['x'] as num? ?? 0.0).toDouble(),
      y: (data['y'] as num? ?? 0.0).toDouble(),
      width: (data['width'] as num? ?? 0.2).toDouble(),
      height: (data['height'] as num? ?? 0.2).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'route': route,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    };
  }

  @override
  List<Object?> get props => [id, title, route, x, y, width, height];

  // --- ▼ [수정] 기본 아이템 목록을 좌표 정보 없이 정의 ▼ ---
  static List<BentoItem> get defaultItems {
    // 좌표(x, y, width, height)는 applyGridAutoLayout에서 동적으로 계산되므로 여기서는 0으로 초기화합니다.
    return [
      const BentoItem(
          id: 'my_page',
          title: '마이페이지',
          route: '/my_page',
          x: 0,
          y: 0,
          width: 0,
          height: 0),
      const BentoItem(
          id: 'attendance_check',
          title: '출석체크',
          route: '/attendance_check',
          x: 0,
          y: 0,
          width: 0,
          height: 0),
      const BentoItem(
          id: 'new_life',
          title: '신생활',
          route: '/new_life',
          x: 0,
          y: 0,
          width: 0,
          height: 0),
      const BentoItem(
          id: 'gallery',
          title: '밀알스타그램',
          route: '/gallery',
          x: 0,
          y: 0,
          width: 0,
          height: 0),
      const BentoItem(
          id: 'forum',
          title: '제직회의',
          route: '/forum',
          x: 0,
          y: 0,
          width: 0,
          height: 0),
      const BentoItem(
          id: 'schedule',
          title: '일정',
          route: '/schedule',
          x: 0,
          y: 0,
          width: 0,
          height: 0),
      const BentoItem(
          id: 'announcements',
          title: '공지',
          route: '/announcements',
          x: 0,
          y: 0,
          width: 0,
          height: 0),
      const BentoItem(
          id: 'bible',
          title: '말씀필사',
          route: '/bible',
          x: 0,
          y: 0,
          width: 0,
          height: 0),
      const BentoItem(
          id: 'accounting',
          title: '회계',
          route: '/accounting',
          x: 0,
          y: 0,
          width: 0,
          height: 0),
      const BentoItem(
          id: 'events',
          title: '행사',
          route: '/events',
          x: 0,
          y: 0,
          width: 0,
          height: 0),
      const BentoItem(
          id: 'questions',
          title: '자유게시판',
          route: '/questions',
          x: 0,
          y: 0,
          width: 0,
          height: 0),
      // '교인 관리'는 BLoC에서 권한에 따라 동적으로 추가됩니다.
    ];
  }

  // --- ▼ [추가] 그리드 자동 정렬 로직을 모델 파일로 이동 및 개선 ▼ ---
  static List<BentoItem> applyGridAutoLayout(List<BentoItem> items) {
    // 레이아웃 상수 정의
    const int columnCount = 2;
    const double horizontalGap = 0.04; // 좌우 여백 (4%)
    const double verticalGap = 0.02; // 상하 여백 (2%)
    const double totalHorizontalGap = horizontalGap * (columnCount + 1);
    const itemWidth = (1.0 - totalHorizontalGap) / columnCount;

    // '교인 관리' 버튼을 임시로 분리
    BentoItem? memberManagementItem;
    List<BentoItem> otherItems = [];
    for (var item in items) {
      if (item.id == 'member_management') {
        memberManagementItem = item;
      } else {
        otherItems.add(item);
      }
    }

    // 사용자가 드래그한 순서를 최대한 보존하기 위해 y, x 좌표 순으로 정렬
    otherItems.sort((a, b) {
      // y 좌표를 기준으로 정렬하되, 약간의 오차(tolerance)를 허용하여 같은 줄에 있도록 함
      final double tolerance = 0.1; // itemHeight의 절반 정도
      if ((a.y - b.y).abs() > tolerance) {
        return a.y.compareTo(b.y);
      }
      return a.x.compareTo(b.x);
    });

    // 최종 아이템 목록 (교인 관리 포함)
    final finalItems = [
      ...otherItems,
      if (memberManagementItem != null) memberManagementItem
    ];
    final int rowCount = (finalItems.length / columnCount).ceil();

    // 버튼이 많아져 화면을 넘어갈 경우, 세로 크기를 동적으로 줄임
    double itemHeight = 0.18; // 기본 세로 크기 (약 5줄 기준)
    final requiredHeight =
        (rowCount * itemHeight) + ((rowCount + 1) * verticalGap);
    if (requiredHeight > 1.0) {
      itemHeight = (1.0 - ((rowCount + 1) * verticalGap)) / rowCount;
    }

    List<BentoItem> newLayout = [];
    for (int i = 0; i < finalItems.length; i++) {
      final int row = i ~/ columnCount;
      final int col = i % columnCount;
      newLayout.add(finalItems[i].copyWith(
        x: (col * (itemWidth + horizontalGap)) + horizontalGap,
        y: (row * (itemHeight + verticalGap)) + verticalGap,
        width: itemWidth,
        height: itemHeight,
      ));
    }

    return newLayout;
  }
  // --- ▲ [추가] 그리드 자동 정렬 로직을 모델 파일로 이동 및 개선 ▲ ---
}
