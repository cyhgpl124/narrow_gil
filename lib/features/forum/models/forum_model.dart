import 'package:cloud_firestore/cloud_firestore.dart';

class ForumTopic {
  final String id;
  final String title;
  final List<String> responsiblePosition;
  final String thisMonthExecution;
  final String nextMonthPlan;
  final String lastEditor;
  final Timestamp lastEditedAt;

  // 회계/기금 관련 필드
  final num broughtForward; // 이월금액
  final num income; // 수입금액
  final num expenditure; // 지출금액
  final num balance; // 잔액
  final String incomeDetails;  // 수입 내역
  final String expenditureDetails; // 지출 내역

  // --- ▼ [추가] 안건토의 관련 필드 ▼ ---
  final String agendaContent;      // 안건내용
  final String discussionResult;   // 안건토의결과
  final String actionLog;          // 안건실행내역

  // --- ▼ [추가] 서기 보고용 총원 필드 ▼ ---
  final int totalMembersForMonth;  // 해당 월의 총원 (출석률 계산 기준)

  ForumTopic({
    required this.id,
    required this.title,
    required this.responsiblePosition,
    required this.thisMonthExecution,
    required this.nextMonthPlan,
    required this.lastEditor,
    required this.lastEditedAt,
    this.broughtForward = 0,
    this.income = 0,
    this.expenditure = 0,
    this.balance = 0,
    this.incomeDetails = '',
    this.expenditureDetails = '',
    // --- ▼ [추가] 생성자 파라미터 추가 ▼ ---
    this.agendaContent = '',
    this.discussionResult = '',
    this.actionLog = '',
    this.totalMembersForMonth = 0,
  });

  factory ForumTopic.fromMap(String id, Map<String, dynamic> data) {
    final responsible = data['responsiblePosition'];
    return ForumTopic(
      id: id,
      title: data['title'] ?? '',
      responsiblePosition: responsible is List
          ? responsible.map((e) => e.toString()).toList()
          : (responsible is String ? [responsible] : []),
      thisMonthExecution: data['thisMonthExecution'] ?? '',
      nextMonthPlan: data['nextMonthPlan'] ?? '',
      lastEditor: data['lastEditor'] ?? '',
      lastEditedAt: data['lastEditedAt'] ?? Timestamp.now(),
      broughtForward: data['broughtForward'] ?? 0,
      income: data['income'] ?? 0,
      expenditure: data['expenditure'] ?? 0,
      balance: data['balance'] ?? 0,
      incomeDetails: data['incomeDetails'] ?? '',
      expenditureDetails: data['expenditureDetails'] ?? '',
      // --- ▼ [추가] Map에서 데이터 읽어오기 ▼ ---
      agendaContent: data['agendaContent'] ?? '',
      discussionResult: data['discussionResult'] ?? '',
      actionLog: data['actionLog'] ?? '',
      totalMembersForMonth: data['totalMembersForMonth'] ?? 0,
    );
  }

  ForumTopic copyWith({
    String? thisMonthExecution,
    String? nextMonthPlan,
    num? broughtForward,
    num? income,
    num? expenditure,
    num? balance,
    String? incomeDetails,
    String? expenditureDetails,
    // --- ▼ [추가] copyWith에 파라미터 추가 ▼ ---
    String? agendaContent,
    String? discussionResult,
    String? actionLog,
    int? totalMembersForMonth,
    // --- ▲ [추가] copyWith에 파라미터 추가 ▲ ---
  }) {
    return ForumTopic(
      id: id,
      title: title,
      responsiblePosition: responsiblePosition,
      thisMonthExecution: thisMonthExecution ?? this.thisMonthExecution,
      nextMonthPlan: nextMonthPlan ?? this.nextMonthPlan,
      lastEditor: lastEditor,
      lastEditedAt: lastEditedAt,
      broughtForward: broughtForward ?? this.broughtForward,
      income: income ?? this.income,
      expenditure: expenditure ?? this.expenditure,
      balance: balance ?? this.balance,
      incomeDetails: incomeDetails ?? this.incomeDetails,
      expenditureDetails: expenditureDetails ?? this.expenditureDetails,
      // --- ▼ [추가] copyWith 로직 추가 ▼ ---
      agendaContent: agendaContent ?? this.agendaContent,
      discussionResult: discussionResult ?? this.discussionResult,
      actionLog: actionLog ?? this.actionLog,
      totalMembersForMonth: totalMembersForMonth ?? this.totalMembersForMonth,
      // --- ▲ [추가] copyWith 로직 추가 ▲ ---
    );
  }
}