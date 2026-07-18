import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // =========================
  // GOOGLE SIGN IN
  // =========================

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCredential = await _auth.signInWithCredential(credential);
        if (userCredential.user != null) {
          final firebaseService = FirebaseService(auth: _auth);
          await firebaseService.ensurePlayerProfileExists(
            userCredential.user!.uid,
            userCredential.user!.email ?? "",
            userCredential.user!.displayName ?? "Explorer",
          );
        }
        return userCredential;
      }
    } catch (e) {
      debugPrint("Error during Google Sign-In: $e");
    }
    return null;
  }

  // =========================
  // ANONYMOUS SIGN IN
  // =========================

  Future<UserCredential> signInAnonymously() async {
    return await _auth.signInAnonymously();
  }

  // =========================
  // PHONE SIGN IN
  // =========================

  Future<void> verifyPhone({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  Future<UserCredential> signInWithPhone(String verificationId, String smsCode) async {
    PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return await _auth.signInWithCredential(credential);
  }

  // =========================
  // CURRENT USER
  // =========================

  User? get currentUser => _auth.currentUser;

  // =========================
  // LOGOUT
  // =========================

  Future<void> logout() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }

  // =========================
  // AUTH STATE
  // =========================

  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }
}