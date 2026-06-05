import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

/// Firebase Authentication Service
class FirebaseAuthService {
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => _instance;
  FirebaseAuthService._internal();

  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  UserModel? _currentUser;

  /// Lấy user hiện tại
  UserModel? get currentUser => _currentUser;

  /// Kiểm tra đã đăng nhập chưa
  bool get isAuthenticated => _currentUser != null;

  /// Khởi tạo - Kiểm tra user đã đăng nhập
  Future<void> initialize() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      await _loadUserFromFirestoreByEmail(firebaseUser.email ?? '');
    }
  }

  // ==========================================================
  // THÊM MỚI: ĐĂNG NHẬP GOOGLE
  // ==========================================================
  Future<UserModel?> signInWithGoogle() async {
    try {
      // 1. Kích hoạt luồng đăng nhập Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // Người dùng hủy đăng nhập

      // 2. Lấy thông tin xác thực từ Google
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final firebase_auth.AuthCredential credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 3. Đăng nhập vào Firebase bằng Credential
      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        // 4. Kiểm tra xem user đã có trong Firestore chưa (dùng email để tìm)
        final querySnapshot = await _firestore
            .collection('users')
            .where('email', isEqualTo: firebaseUser.email)
            .limit(1)
            .get();

        if (querySnapshot.docs.isEmpty) {
          // Nếu chưa có (Lần đầu đăng nhập bằng Google), tạo bản ghi mới
          // Dùng UID hoặc Email prefix làm username tạm thời
          String tempUsername = firebaseUser.email!.split('@')[0];
          
          await _firestore.collection('users').doc(tempUsername).set({
            'id': firebaseUser.uid,
            'username': tempUsername,
            'email': firebaseUser.email,
            'name': firebaseUser.displayName ?? 'Người dùng Google',
            'role': 'student', // Mặc định là học sinh
            'telephone': '',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        
        await _loadUserFromFirestoreByEmail(firebaseUser.email!);
        return _currentUser;
      }
      return null;
    } catch (e) {
      throw Exception('Lỗi đăng nhập Google: $e');
    }
  }

  // ==========================================================
  // THÊM MỚI: QUÊN MẬT KHẨU
  // ==========================================================
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    } catch (e) {
      throw Exception('Không thể gửi email khôi phục: $e');
    }
  }

  /// Đăng ký tài khoản mới với Username làm Document ID
  Future<UserModel> register({
    required String username,
    required String email,
    required String password,
    required String name,
    required UserRole role,
    String? telephone,
  }) async {
    try {
      final docSnapshot = await _firestore.collection('users').doc(username).get();
      if (docSnapshot.exists) {
        throw Exception('Username này đã tồn tại, vui lòng chọn tên khác.');
      }

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw Exception('Không thể tạo tài khoản xác thực');
      }

      final userData = {
        'id': firebaseUser.uid,
        'username': username,
        'email': email,
        'name': name,
        'role': role.toString().split('.').last,
        'telephone': telephone ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(username).set(userData);

      _currentUser = UserModel(
        id: firebaseUser.uid,
        email: email,
        name: name,
        role: role,
        createdAt: DateTime.now(),
      );

      return _currentUser!;
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  /// Đăng nhập bằng Email hoặc Username
  Future<UserModel> login({
    required String identifier,
    required String password,
  }) async {
    try {
      String email = identifier;

      if (!identifier.contains('@')) {
        final userDoc = await _firestore.collection('users').doc(identifier).get();
        if (!userDoc.exists) {
          throw Exception('Username không tồn tại');
        }
        email = userDoc.data()?['email'] as String;
      }

      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) throw Exception('Đăng nhập thất bại');

      await _loadUserFromFirestoreByEmail(email);
      return _currentUser!;
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> _loadUserFromFirestoreByEmail(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        throw Exception('Dữ liệu người dùng không tồn tại trong hệ thống');
      }

      final doc = querySnapshot.docs.first;
      final data = doc.data();
      
      _currentUser = UserModel(
        id: data['id'] as String,
        email: data['email'] as String,
        name: data['name'] as String,
        role: _parseRole(data['role'] as String),
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    } catch (e) {
      throw Exception('Lỗi tải thông tin: $e');
    }
  }

  UserRole _parseRole(String roleStr) {
    switch (roleStr.toLowerCase()) {
      case 'admin': return UserRole.admin;
      case 'teacher': return UserRole.teacher;
      case 'student': return UserRole.student;
      case 'parent': return UserRole.parent;
      default: return UserRole.student;
    }
  }

  String _handleAuthException(firebase_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use': return 'Email này đã được sử dụng.';
      case 'invalid-email': return 'Email không hợp lệ.';
      case 'weak-password': return 'Mật khẩu quá yếu.';
      case 'user-not-found': return 'Tài khoản không tồn tại.';
      case 'wrong-password': return 'Sai mật khẩu.';
      case 'too-many-requests': return 'Thử lại sau ít phút.';
      default: return 'Lỗi: ${e.message}';
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    try { await _googleSignIn.signOut(); } catch (_) {}
    _currentUser = null;
  }
}