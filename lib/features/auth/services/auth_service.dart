// Vị trí file: lib/features/auth/data/sources/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

/// Authentication service handling login/register operations connected with Firebase
class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Current authenticated user
  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  /// Fetch user profile from Firestore using UID
  Future<UserModel?> _fetchUserProfile(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        
        // Chuyển đổi Timestamp từ Firestore sang DateTime của Dart
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final lastLoginAt = (data['lastLoginAt'] as Timestamp?)?.toDate() ?? DateTime.now();

        return UserModel(
          id: uid,
          email: data['email'] as String? ?? '',
          name: data['name'] as String? ?? '',
          role: UserRole.values.firstWhere(
            (e) => e.name == (data['role'] as String? ?? 'student'),
            orElse: () => UserRole.student,
          ),
          createdAt: createdAt,
          lastLoginAt: lastLoginAt,
          avatarUrl: data['avatarUrl'] as String?,
        );
      }
      return null;
    } catch (e) {
      print('❌ Lỗi khi lấy thông tin user từ Firestore: $e');
      return null;
    }
  }

  /// Login with email and password
  Future<UserModel> login(String email, String password) async {
    try {
      // 1. Đăng nhập qua Firebase Authentication
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw Exception('Không thể lấy thông tin người dùng.');
      }

      // 2. Cập nhật thời gian đăng nhập mới nhất lên Firestore
      await _db.collection('users').doc(firebaseUser.uid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      }).catchError((_) => null); // Bỏ qua nếu tài liệu chưa tồn tại để xử lý ở bước sau

      // 3. Lấy thông tin chi tiết từ Firestore
      var userModel = await _fetchUserProfile(firebaseUser.uid);

      // Dự phòng: Nếu lỡ tay xóa mất tài liệu dưới Firestore nhưng Auth vẫn còn
      if (userModel == null) {
        userModel = UserModel(
          id: firebaseUser.uid,
          email: firebaseUser.email ?? email,
          name: firebaseUser.displayName ?? 'Người dùng HSK',
          role: UserRole.student, // Mặc định nếu bị mất profile
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        );

        // Tạo bù lại tài liệu trong collection 'users'
        await _db.collection('users').doc(firebaseUser.uid).set({
          'email': userModel.email,
          'name': userModel.name,
          'role': userModel.role.name,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
      }

      _currentUser = userModel;
      return _currentUser!;
    } on FirebaseAuthException catch (e) {
      String message = 'Đăng nhập thất bại';
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Email hoặc mật khẩu không chính xác';
      } else if (e.code == 'invalid-email') {
        message = 'Định dạng email không hợp lệ';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception('Đăng nhập thất bại: ${e.toString()}');
    }
  }

  /// Register new user và tự động khởi tạo dữ liệu trong collection 'users'
  Future<UserModel> register({
    required String email,
    required String password,
    required String name,
    required UserRole role,
  }) async {
    try {
      // 1. Tạo tài khoản trên Firebase Authentication
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw Exception('Đăng ký không thành công.');
      }

      // Cập nhật Profile Name hiển thị trên Auth cơ bản
      await firebaseUser.updateDisplayName(name);

      // 2. Ghi đè thiết lập / Tự tạo mới collection 'users' trên Firestore
      // Hành động .set() này sẽ tự động sinh lại collection 'users' nếu nó không tồn tại
      await _db.collection('users').doc(firebaseUser.uid).set({
        'email': email,
        'name': name,
        'role': role.name,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'avatarUrl': null,
      });

      // 3. Khởi tạo dữ liệu Object local
      _currentUser = UserModel(
        id: firebaseUser.uid,
        email: email,
        name: name,
        role: role,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
      );

      return _currentUser!;
    } on FirebaseAuthException catch (e) {
      String message = 'Đăng ký thất bại';
      if (e.code == 'email-already-in-use') {
        message = 'Email này đã được đăng ký bởi tài khoản khác';
      } else if (e.code == 'weak-password') {
        message = 'Mật khẩu quá yếu, vui lòng nhập tối thiểu 6 ký tự';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception('Đăng ký thất bại: ${e.toString()}');
    }
  }

  /// Logout current user
  Future<void> logout() async {
    await _auth.signOut();
    _currentUser = null;
  }

  /// Check if user is authenticated
  bool get isAuthenticated => _auth.currentUser != null;

  /// Get user role
  UserRole? get userRole => _currentUser?.role;

  /// Reset password qua email thực tế của Firebase
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception('Email không tồn tại trong hệ thống');
      }
      throw Exception('Gửi mail đặt lại mật khẩu thất bại: ${e.message}');
    }
  }

  /// Update user profile
  Future<UserModel> updateProfile({
    String? name,
    String? avatarUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null || _currentUser == null) {
      throw Exception('Người dùng chưa đăng nhập');
    }

    try {
      final Map<String, dynamic> updates = {};
      if (name != null) {
        updates['name'] = name;
        await user.updateDisplayName(name);
      }
      if (avatarUrl != null) {
        updates['avatarUrl'] = avatarUrl;
        await user.updatePhotoURL(avatarUrl);
      }

      if (updates.isNotEmpty) {
        await _db.collection('users').doc(user.uid).update(updates);
        _currentUser = _currentUser!.copyWith(
          name: name ?? _currentUser!.name,
          avatarUrl: avatarUrl ?? _currentUser!.avatarUrl,
        );
      }

      return _currentUser!;
    } catch (e) {
      throw Exception('Cập nhật tài khoản thất bại: ${e.toString()}');
    }
  }
}