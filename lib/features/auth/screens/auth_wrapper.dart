import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../services/firebase_auth_service.dart';
import '../../../core/utils/role_resolver.dart';
import 'login_screen.dart';

/// Auth Wrapper - Check authentication state on app start
/// Restores user session after browser refresh
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _authService = FirebaseAuthService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    try {
      print('🔐 AuthWrapper: Checking auth state...');
      
      // Wait a bit for Firebase to initialize
      await Future.delayed(const Duration(milliseconds: 500));
      
      final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
      
      if (firebaseUser == null) {
        print('🔐 AuthWrapper: No user logged in');
        setState(() => _isLoading = false);
        return;
      }

      print('🔐 AuthWrapper: Found Firebase user: ${firebaseUser.email}');
      
      // Get user data from Firestore
      await _authService.initialize();
final user = _authService.currentUser;
      
      if (user == null) {
        print('🔐 AuthWrapper: User data not found in Firestore, logging out...');
        await firebase_auth.FirebaseAuth.instance.signOut();
        setState(() => _isLoading = false);
        return;
      }

      print('🔐 AuthWrapper: User authenticated: ${user.email} (${user.role})');
      
      if (!mounted) return;
      
      // Navigate to appropriate dashboard
      RoleResolver.navigateToDashboard(context, user);
      
    } catch (e) {
      print('🔐 AuthWrapper ERROR: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.blue.shade400,
                Colors.blue.shade700,
              ],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                SizedBox(height: 24),
                Text(
                  'Đang tải...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const LoginScreen();
  }
}
