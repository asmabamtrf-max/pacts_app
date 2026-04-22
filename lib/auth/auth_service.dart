import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _tokenKey = 'auth_token';
  static const String _rememberMeKey = 'remember_me';
  static const String _userEmailKey = 'user_email';
  static const String _userUidKey = 'user_uid';
  static const String _lastLoginKey = 'last_login';

  String? _verificationId;

  Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();

  Future<bool> isUserLoggedIn() async {
    if (_auth.currentUser != null) return true;
    final prefs = await _prefs;
    return prefs.getString(_tokenKey) != null;
  }

  Future<void> _saveUserData(User user) async {
    final prefs = await _prefs;
    await prefs.setString(_userUidKey, user.uid);
    await prefs.setString(_userEmailKey, user.email ?? '');
    final token = await user.getIdToken();
    if (token != null) {
      await prefs.setString(_tokenKey, token);
    }
    await prefs.setString(_lastLoginKey, DateTime.now().toIso8601String());
  }

  Future<void> _clearCache() async {
    final prefs = await _prefs;
    await prefs.remove(_tokenKey);
    await prefs.remove(_userUidKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_lastLoginKey);
    await prefs.remove(_rememberMeKey);
  }

  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
    bool rememberMe = true,
    required Function(String) onError,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = cred.user;
      if (user == null) {
        onError('Login failed');
        return null;
      }
      await user.reload();
      final refreshedUser = _auth.currentUser;
      if (refreshedUser == null) {
        onError('User reload failed');
        return null;
      }
      if (rememberMe) {
        final prefs = await _prefs;
        await prefs.setBool(_rememberMeKey, true);
        await _saveUserData(refreshedUser);
      }
      return cred;
    } on FirebaseAuthException catch (e) {
      onError(_getAuthErrorMessage(e.code));
      return null;
    } catch (e) {
      onError(e.toString());
      return null;
    }
  }

  Future<UserCredential?> registerWithEmail({
    required String email,
    required String password,
    required Function(String) onError,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await cred.user?.sendEmailVerification();
      return cred;
    } on FirebaseAuthException catch (e) {
      onError(_getAuthErrorMessage(e.code));
      return null;
    } catch (e) {
      onError(e.toString());
      return null;
    }
  }

  Future<User?> autoSignIn({
    required Function(String) onError,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await currentUser.getIdToken(true);
        return currentUser;
      }
      final prefs = await _prefs;
      final rememberMe = prefs.getBool(_rememberMeKey) ?? false;
      if (!rememberMe) return null;
      return _auth.currentUser;
    } catch (e) {
      onError('Auto login failed: $e');
      return null;
    }
  }

  Future<void> signOut({bool clearCache = true}) async {
    await _auth.signOut();
    if (clearCache) {
      await _clearCache();
    }
  }

  Future<bool> isEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  Future<void> sendEmailVerification({Function(String)? onSuccess, Function(String)? onError}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        onError?.call('No user logged in');
        return;
      }
      await user.sendEmailVerification();
      onSuccess?.call('Verification email sent');
    } catch (e) {
      onError?.call(e.toString());
    }
  }

  Future<void> resetPassword({
    required String email,
    required Function(String) onSuccess,
    required Function(String) onError,
  }) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      onSuccess('Password reset email sent to $email');
    } on FirebaseAuthException catch (e) {
      onError(_getAuthErrorMessage(e.code));
    } catch (e) {
      onError(e.toString());
    }
  }

  Future<void> sendOTP({
    required String phoneNumber,
    required Function() codeSent,
    required Function(String) onError,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (e) {
          onError(e.message ?? 'Verification failed');
        },
        codeSent: (verificationId, _) {
          _verificationId = verificationId;
          codeSent();
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  Future<UserCredential?> verifyOTP({
    required String smsCode,
    required Function(String) onError,
  }) async {
    try {
      if (_verificationId == null) {
        onError('Send OTP first');
        return null;
      }
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );
      final result = await _auth.signInWithCredential(credential);
      if (result.user != null) {
        await _saveUserData(result.user!);
      }
      return result;
    } catch (e) {
      onError(e.toString());
      return null;
    }
  }

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found';
      case 'wrong-password':
        return 'Wrong password';
      case 'email-already-in-use':
        return 'Email already used';
      case 'invalid-email':
        return 'Invalid email';
      case 'user-disabled':
        return 'Account disabled';
      case 'too-many-requests':
        return 'Too many attempts';
      default:
        return 'Auth error: $code';
    }
  }
}


