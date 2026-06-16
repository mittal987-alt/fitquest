import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:math';

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

        return await _auth.signInWithCredential(credential);
      }
    } catch (e) {
      print("Error during Google Sign-In: $e");
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

  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz.-_';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // =========================
  // CURRENT USER
  // =========================

  User? get currentUser =>
      _auth.currentUser;

  // =========================
  // SIGN UP
  // =========================

  Future<UserCredential> signUp({

    required String email,

    required String password,
  }) async {

    return await _auth
        .createUserWithEmailAndPassword(

      email: email,

      password: password,
    );
  }

  // =========================
  // LOGIN
  // =========================

  Future<UserCredential> login({

    required String email,

    required String password,
  }) async {

    return await _auth
        .signInWithEmailAndPassword(

      email: email,

      password: password,
    );
  }

  // =========================
  // LOGOUT
  // =========================

  Future<void> logout() async {

    await _auth.signOut();
  }

  // =========================
  // RESET PASSWORD
  // =========================

  Future<void> resetPassword(

      String email) async {

    await _auth
        .sendPasswordResetEmail(

      email: email,
    );
  }

  // =========================
  // AUTH STATE
  // =========================

  Stream<User?> authStateChanges() {

    return _auth.authStateChanges();
  }
}