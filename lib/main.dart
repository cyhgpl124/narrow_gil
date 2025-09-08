import 'package:flutter/foundation.dart' show kIsWeb; // kIsWeb import 추가
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:narrow_gil/firebase_options.dart';
import 'package:narrow_gil/home/models/user_profile.dart';
import 'package:narrow_gil/home/view/home_page.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null);
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '좁은길 생명의길',
      theme: ThemeData(
          brightness: Brightness.dark, // 전체적인 테마를 어둡게 설정
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: Colors.black, // Scaffold 배경을 검은색으로
          textTheme: const TextTheme(
            // 기본 텍스트 스타일을 흰색 계열로
            bodyLarge: TextStyle(color: Colors.white),
            bodyMedium: TextStyle(color: Colors.white70),
            titleLarge:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          )),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        } else if (snapshot.hasData) {
          return UserRegistrationChecker(user: snapshot.data!);
        } else {
          return const LoginPage();
        }
      },
    );
  }
}

/// 사용자가 로그인했을 때, Firestore에 프로필 정보가 있는지 확인하는 위젯
class UserRegistrationChecker extends StatelessWidget {
  final User user;
  const UserRegistrationChecker({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(
              body: Center(child: Text('오류가 발생했습니다: ${snapshot.error}')));
        }
        if (snapshot.hasData && snapshot.data!.exists) {
          return HeavenlyScoreChecker(user: user);
        } else {
          return const RegistrationPage();
        }
      },
    );
  }
}

/// 로그인 시 skyScore를 확인하고, 차감 및 접근 제한을 처리하는 위젯
class HeavenlyScoreChecker extends StatefulWidget {
  final User user;
  const HeavenlyScoreChecker({super.key, required this.user});

  @override
  State<HeavenlyScoreChecker> createState() => _HeavenlyScoreCheckerState();
}

class _HeavenlyScoreCheckerState extends State<HeavenlyScoreChecker> {
  late final Future<Widget> _pageFuture;

  @override
  void initState() {
    super.initState();
    _pageFuture = _checkScoreAndGetPage();
  }

  // 점수가 부족할 때 경고창을 띄우는 함수
  Future<void> _showScoreDeficitDialog(int score) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('로그인 실패'),
        content: Text('skyScore가 $score점 입니다. 점수가 부족하여 로그인할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await FirebaseAuth.instance.signOut(); // 로그아웃 처리
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  // 사용자 점수를 확인하고 적절한 페이지 위젯을 반환하는 함수
  Future<Widget> _checkScoreAndGetPage() async {
    final firestore = FirebaseFirestore.instance;
    try {
      final userDoc =
          await firestore.collection('users').doc(widget.user.uid).get();

      // 사용자 프로필이 없는 경우 처리
      if (!userDoc.exists || userDoc.data() == null) {
        await FirebaseAuth.instance.signOut();
        return const LoginPage();
      }

      final userData = userDoc.data()!;
      final phoneNumber = userData['phoneNumber'] as String?;

      // 전화번호 정보가 없는 경우, 홈 페이지로 바로 이동
      if (phoneNumber == null || phoneNumber.isEmpty) {
        final incompleteProfile =
            UserProfile.fromFirestore(userData, widget.user.uid);
        return HomePage(userProfile: incompleteProfile);
      }

      final approvedMembersQuery = await firestore
          .collection('approved_members')
          .doc(userData['church'] as String?)
          .collection('members')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();

      // 등록된 멤버가 아닌 경우, 기본 프로필로 홈 페이지 이동
      if (approvedMembersQuery.docs.isEmpty) {
        final profile = UserProfile.fromFirestore(userData, widget.user.uid);
        return HomePage(userProfile: profile);
      }

      // 점수 계산 및 업데이트 로직
      final memberDocRef = approvedMembersQuery.docs.first.reference;
      final memberDoc = await memberDocRef.get();
      final memberData = memberDoc.data();
      int currentScore = memberData?['skyScore'] as int? ?? 0;
      final lastLoginTimestamp = memberData?['lastLogin'] as Timestamp?;
      final now = DateTime.now();

      if (lastLoginTimestamp != null) {
        final lastLoginDate = lastLoginTimestamp.toDate();
        if (now.difference(lastLoginDate).inDays > 0) {
          int monthsPassed = (now.year - lastLoginDate.year) * 12 +
              now.month -
              lastLoginDate.month;
          if (monthsPassed > 0) {
            currentScore -= (monthsPassed * 10);
          }
        }
      }

      await memberDocRef.update({
        'skyScore': currentScore,
        'lastLogin': Timestamp.fromDate(now),
      });

      // 점수가 0보다 낮은 경우, 경고창을 띄우고 로그아웃
      if (currentScore < 0) {
        Future.microtask(() => _showScoreDeficitDialog(currentScore));
        return const Scaffold(body: Center(child: Text("점수가 부족하여 로그아웃됩니다.")));
      } else {
        final String houseHoldHead = memberData?['houseHoldHead'] as String? ?? '';
        // 모든 조건 통과 시, 사용자 프로필과 함께 홈 페이지 반환
        final finalUserProfile = UserProfile.fromFirestore(
          userData,
          widget.user.uid,
          score: currentScore,
          loginTime: Timestamp.fromDate(now),
          houseHoldHead: houseHoldHead,
        );
        return HomePage(userProfile: finalUserProfile);
      }
    } catch (e) {
      // 오류 발생 시 로그아웃
      Future.microtask(() => FirebaseAuth.instance.signOut());
      return Scaffold(body: Center(child: Text('로그인 처리 중 오류가 발생했습니다: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _pageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return snapshot.data!; // 비동기 작업 후 결정된 페이지를 보여줌
        }
        if (snapshot.hasError) {
          Future.microtask(() => FirebaseAuth.instance.signOut());
          return Scaffold(
              body: Center(child: Text('오류 발생: ${snapshot.error}')));
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}

/// 신규 사용자 정보(이름, 생년월일, 핸드폰번호)를 입력받는 페이지
class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _birthdateController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _selectedChurch;
  bool _isLoadingChurches = true;
  List<String> _churches = [];

  @override
  void initState() {
    super.initState();
    _fetchChurches();
  }

  Future<void> _fetchChurches() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('churches').get();
      final churches = snapshot.docs.map((doc) => doc.id).toList()..sort();
      if (mounted) {
        setState(() {
          _churches = churches;
          _isLoadingChurches = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('교회 목록을 불러오는 중 오류가 발생했습니다: $e')),
        );
        setState(() {
          _isLoadingChurches = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthdateController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final phoneNumber = _phoneController.text;
      final churchName = _selectedChurch;
      final firestore = FirebaseFirestore.instance;

      // --- ▼ [추가] 전화번호 중복 확인 로직 ▼ ---
      final existingUserQuery = await firestore
          .collection('users')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();

      if (existingUserQuery.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이미 가입된 번호입니다. 다른 번호를 입력해주세요.')),
          );
        }
        setState(() => _isLoading = false);
        return; // 중복된 번호이므로 가입 절차 중단
      }
      // --- ▲ [추가] 전화번호 중복 확인 로직 ▲ ---

      // 1. 현재 로그인된 사용자 정보를 가져옵니다.
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('로그인된 사용자 정보가 없습니다.');
      }

      if (churchName == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('교회를 선택해주세요.')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // 2. 전화번호로 기존 approved_members 문서를 찾습니다.
      final membersCollection = firestore
          .collection('approved_members')
          .doc(churchName)
          .collection('members');

      final approvedMembersQuery = await membersCollection
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();

      if (approvedMembersQuery.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('해당 교회에 등록된 번호가 아닙니다. 관리자에게 문의해주세요.')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // 3. 일괄 쓰기(Batch)를 시작하여 모든 작업을 원자적으로 처리합니다.
      final batch = firestore.batch();

      // 3-1. 기존 문서의 참조와 데이터를 가져옵니다.
      final oldDocRef = approvedMembersQuery.docs.first.reference;
      final oldDocData = approvedMembersQuery.docs.first.data();

      // --- ▼ [수정 2] oldDocData에서 houseHoldHead 값을 가져옵니다. ---
      final String houseHoldHead = oldDocData['houseHoldHead'] as String? ?? '';

      // 3-2. 'users' 컬렉션에 사용자 프로필 문서를 생성합니다. (ID: user.uid)
      final userDocRef = firestore.collection('users').doc(user.uid);
      batch.set(userDocRef, {
        'uid': user.uid,
        'email': user.email,
        'name': _nameController.text,
        'church': churchName,
        'birthdate': _birthdateController.text,
        'phoneNumber': phoneNumber,
        'photoURL': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3-3. 'approved_members'에 새 문서(ID: user.uid)를 생성하고 기존 데이터를 복사합니다.
      final newMemberDocRef = membersCollection.doc(user.uid);
      batch.set(newMemberDocRef, oldDocData);

      // 3-4. 새 문서에 lastLogin 시간을 업데이트합니다.
      batch.update(newMemberDocRef, {
        'lastLogin': FieldValue.serverTimestamp(),
      });

      // 3-5. 기존 문서를 삭제합니다.
      batch.delete(oldDocRef);

      // 4. 모든 작업을 한 번에 실행합니다.
      await batch.commit();

      // 5. HomePage로 이동합니다.
      if (mounted) {
        final newUserProfile = UserProfile(
          uid: user.uid,
          name: _nameController.text,
          email: user.email!,
          photoURL: user.photoURL,
          church: churchName,
          phoneNumber: phoneNumber,
          birthdate: _birthdateController.text,
          houseHoldHead: houseHoldHead,
          heavenlyScore: 100,
          lastLogin: null,
        );

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (context) => HomePage(userProfile: newUserProfile)),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('등록 중 오류가 발생했습니다: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // <<< 🚀 추가된 부분 시작 🚀 >>>
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            // 뒤로가기 버튼을 누르면 구글 로그인을 취소(로그아웃)합니다.
            await FirebaseAuth.instance.signOut();
            // AuthWrapper가 상태 변화를 감지하고 자동으로 LoginPage로 보내줍니다.
          },
        ),
        // <<< 🚀 추가된 부분 끝 🚀 >>>
        title: const Text('추가 정보 입력'),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('서비스 이용을 위해 추가 정보를 입력해주세요.',
                    style: TextStyle(fontSize: 16)),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                      labelText: '이름', border: OutlineInputBorder()),
                  validator: (value) =>
                      value == null || value.isEmpty ? '이름을 입력해주세요.' : null,
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _selectedChurch,
                  decoration: const InputDecoration(
                    labelText: '교회',
                    border: OutlineInputBorder(),
                  ),
                  hint: _isLoadingChurches
                      ? const Text('교회 목록을 불러오는 중...')
                      : const Text('교회를 선택해주세요'),
                  onChanged: _isLoadingChurches
                      ? null
                      : (String? newValue) {
                          setState(() => _selectedChurch = newValue);
                        },
                  items:
                      _churches.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  validator: (value) => value == null ? '교회를 선택해주세요.' : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _birthdateController,
                  decoration: const InputDecoration(
                      labelText: '생년월일 (예: 900101)',
                      border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '생년월일을 입력해주세요.';
                    }
                    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
                      return '6자리 숫자로 입력해주세요. (예: 900101)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                      labelText: '핸드폰 번호 (예: 01012345678)',
                      border: OutlineInputBorder()),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '핸드폰 번호를 입력해주세요.';
                    }
                    if (!RegExp(r'^010\d{8}$').hasMatch(value)) {
                      return '올바른 핸드폰 번호 양식이 아닙니다. (예: 01012345678)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 40),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _submitRegistration,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                        child: const Text('가입 완료'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ✨✨✨ 여기가 수정된 LoginPage 위젯입니다. ✨✨✨
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isSigningIn = false;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isSigningIn = true;
    });
    try {
      final String? webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
      final GoogleSignInAccount? googleUser =
          await GoogleSignIn(clientId: webClientId).signIn();

      if (googleUser == null) {
        if (mounted) setState(() => _isSigningIn = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Firebase 로그인 오류: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('알 수 없는 오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 배경 이미지
          Image.asset(
            'assets/images/splash_bg.png',
            fit: BoxFit.cover,
          ),
          // 2. 어두운 오버레이
          Container(
            color: Colors.black.withOpacity(0.5),
          ),
          // 3. UI 콘텐츠
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(flex: 3),
                // 앱 타이틀
                const Text(
                  '좁은 길, 생명의 길',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                    shadows: [
                      Shadow(
                        blurRadius: 10.0,
                        color: Colors.black54,
                        offset: Offset(2.0, 2.0),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // 부제
                Text(
                  '하늘에 보물을 쌓는 여정',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const Spacer(flex: 4),
                // 로그인 버튼 또는 로딩 인디케이터
                if (_isSigningIn)
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                else
                  _buildGoogleSignInButton(),
                const Spacer(flex: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 구글 로그인 버튼을 별도의 위젯으로 분리하여 가독성 향상
  Widget _buildGoogleSignInButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: ElevatedButton.icon(
        onPressed: _signInWithGoogle,
        icon: Image.asset(
          'assets/images/google_logo.png', // 구글 로고 이미지 경로
          height: 24.0,
        ),
        label: const Text(
          'Google 계정으로 시작하기',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.black87, // 텍스트 및 아이콘 색상
          backgroundColor: Colors.white, // 버튼 배경색
          minimumSize: const Size(double.infinity, 50), // 버튼 최소 크기
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30.0), // 둥근 모서리
          ),
          elevation: 5, // 그림자 효과
        ),
      ),
    );
  }
}
