import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/utils/app_logger.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential?> signInWithGoogle() async {
    log.i('[Auth] Starting Google Sign-In');
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        log.w('[Auth] Google Sign-In cancelled by user');
        return null;
      }
      log.d('[Auth] Google user: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      log.d('[Auth] Got Google auth tokens (accessToken: ${googleAuth.accessToken != null}, idToken: ${googleAuth.idToken != null})');

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      log.i('[Auth] Sign-in successful: ${userCredential.user?.uid}');
      log.d('[Auth] Display name: ${userCredential.user?.displayName}');
      log.d('[Auth] Email: ${userCredential.user?.email}');
      log.d('[Auth] Is new user: ${userCredential.additionalUserInfo?.isNewUser}');
      return userCredential;
    } catch (e, stackTrace) {
      log.e('[Auth] Sign-in failed: $e');
      log.e('[Auth] Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<UserCredential> registerWithEmail(String email, String password) async {
    log.i('[Auth] Registering with email: $email');
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      log.i('[Auth] Registration successful: ${credential.user?.uid}');
      return credential;
    } on FirebaseAuthException catch (e) {
      log.e('[Auth] Registration failed: ${e.code}');
      throw _mapAuthException(e);
    } catch (e) {
      log.e('[Auth] Registration error: $e');
      throw 'Please check your internet connection and try again.';
    }
  }

  Future<UserCredential> signInWithEmail(String email, String password) async {
    log.i('[Auth] Signing in with email: $email');
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      log.i('[Auth] Email sign-in successful: ${credential.user?.uid}');
      return credential;
    } on FirebaseAuthException catch (e) {
      log.e('[Auth] Email sign-in failed: ${e.code}');
      throw _mapAuthException(e);
    } catch (e) {
      log.e('[Auth] Sign-in error: $e');
      throw 'Please check your internet connection and try again.';
    }
  }

  Future<void> sendPasswordReset(String email) async {
    log.i('[Auth] Sending password reset to: $email');
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      log.e('[Auth] Password reset failed: ${e.code}');
      throw _mapAuthException(e);
    } catch (e) {
      log.e('[Auth] Password reset error: $e');
      throw 'Please check your internet connection and try again.';
    }
  }

  String _mapAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered. Try signing in.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'user-disabled':
        return 'This account has been disabled.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }

  Future<void> signOut() async {
    log.i('[Auth] Signing out user: ${_auth.currentUser?.uid}');
    await _googleSignIn.signOut();
    await _auth.signOut();
    log.i('[Auth] Sign-out complete');
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      log.e('[Auth] Cannot delete account — no user signed in');
      throw Exception('No user signed in');
    }
    log.w('[Auth] Deleting account: ${user.uid}');
    try {
      await user.delete();
      log.i('[Auth] Account deleted');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        log.w('[Auth] Re-authentication required for deletion');
        rethrow;
      }
      rethrow;
    }
  }

  Future<void> reauthenticateWithGoogle() async {
    log.i('[Auth] Re-authenticating with Google');
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google re-auth cancelled');
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    await _auth.currentUser!.reauthenticateWithCredential(credential);
    log.i('[Auth] Google re-authentication successful');
  }

  Future<void> reauthenticateWithEmail(String password) async {
    log.i('[Auth] Re-authenticating with email');
    final user = _auth.currentUser!;
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
    log.i('[Auth] Email re-authentication successful');
  }

  /// Returns true if the current user signed in with Google.
  bool get isGoogleUser {
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.providerData.any((p) => p.providerId == 'google.com');
  }
}
