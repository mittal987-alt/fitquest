import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import 'main_navigation.dart';
import 'class_selection_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  bool isLogin = true;
  bool loading = false;

  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseService firebaseService = FirebaseService();
  final AuthService authService = AuthService();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    super.dispose();
  }

  Future<void> handleAuth() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final name = nameController.text.trim();

    if (email.isEmpty || password.isEmpty || (!isLogin && name.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all standard validation fields.")),
      );
      return;
    }

    try {
      setState(() => loading = true);

      if (isLogin) {
        await auth.signInWithEmailAndPassword(email: email, password: password);
      } else {
        UserCredential userCredential = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        await firebaseService.createPlayer(
          uid: userCredential.user!.uid,
          name: name,
          email: email,
        );

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => ClassSelectionScreen(uid: userCredential.user!.uid)),
          );
        }
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void _showPhoneSignInDialog() {
    final phoneController = TextEditingController();
    final codeController = TextEditingController();
    String? vId;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (builderContext, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
          ),
          title: const Text(
            "SECURE PHONE LINK",
            style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (vId == null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: phoneController,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        labelText: "Phone Number",
                        labelStyle: const TextStyle(color: Colors.black54),
                        hintText: "+1234567890",
                        hintStyle: const TextStyle(color: Colors.black26),
                        prefixIcon: const Icon(Icons.phone_rounded, color: Colors.blueAccent),
                        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.black12)),
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        "Enter a valid phone number in E.164 format (e.g. +1234567890)",
                        style: TextStyle(fontSize: 11, color: Colors.black38),
                      ),
                    ),
                  ],
                )
              else
                TextField(
                  controller: codeController,
                  style: const TextStyle(color: Colors.black87),
                  decoration: const InputDecoration(
                    labelText: "Verification Token",
                    labelStyle: TextStyle(color: Colors.black54),
                    prefixIcon: Icon(Icons.lock_clock_rounded, color: Colors.blueAccent),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black12)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                  ),
                  keyboardType: TextInputType.number,
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("CANCEL", style: TextStyle(color: Colors.black38)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                if (vId == null) {
                  final phone = phoneController.text.trim();
                  if (!RegExp(r'^\+[1-9]\d{1,14}$').hasMatch(phone)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Enter a valid phone number in E.164 format (e.g. +1234567890)")),
                    );
                    return;
                  }

                  await authService.verifyPhone(
                    phoneNumber: phone,
                    verificationCompleted: (cred) async {
                      try {
                        UserCredential userCredential = await auth.signInWithCredential(cred);
                        bool isNew = userCredential.additionalUserInfo?.isNewUser == true;
                        if (isNew) {
                          await firebaseService.createPlayer(
                            uid: userCredential.user!.uid,
                            name: "Operator ${userCredential.user!.uid.substring(0, 5)}",
                            email: userCredential.user!.phoneNumber ?? "Phone User",
                          );
                        }
                        if (Navigator.canPop(dialogContext)) Navigator.pop(dialogContext);
                        if (mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => isNew 
                                ? ClassSelectionScreen(uid: userCredential.user!.uid) 
                                : const MainNavigation()
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Auto-verification breakdown: $e")),
                          );
                        }
                      }
                    },
                    verificationFailed: (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.message ?? "Verification Fault")),
                      );
                    },
                    codeSent: (id, resendToken) {
                      setDialogState(() => vId = id);
                    },
                    codeAutoRetrievalTimeout: (id) {
                      setDialogState(() => vId = id);
                    },
                  );
                } else {
                  try {
                    UserCredential userCredential = await authService.signInWithPhone(
                      vId!,
                      codeController.text.trim(),
                    );
                    bool isNew = userCredential.additionalUserInfo?.isNewUser == true;
                    if (isNew) {
                      await firebaseService.createPlayer(
                        uid: userCredential.user!.uid,
                        name: "Operator ${userCredential.user!.uid.substring(0, 5)}",
                        email: userCredential.user!.phoneNumber ?? "",
                      );
                    }
                    if (Navigator.canPop(dialogContext)) Navigator.pop(dialogContext);
                    if (mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => isNew 
                            ? ClassSelectionScreen(uid: userCredential.user!.uid) 
                            : const MainNavigation()
                        ),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
              child: Text(vId == null ? "REQUEST CODE" : "VERIFY CODE", style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.black.withValues(alpha: 0.05), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.public_rounded, size: 70, color: Colors.blueAccent),
                const SizedBox(height: 16),
                const Text(
                  "FITQUEST",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: 2),
                ),
                const SizedBox(height: 6),
                Text(
                  isLogin ? "INITIALIZE OPERATOR SESSION" : "REGISTER SYSTEM PROFILE",
                  style: const TextStyle(color: Colors.black45, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
                const SizedBox(height: 32),

                if (!isLogin) ...[
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      labelText: "Operator Name",
                      labelStyle: const TextStyle(color: Colors.black54),
                      prefixIcon: const Icon(Icons.person_outline_rounded, color: Colors.black38),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.black12)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.blueAccent)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                TextField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.black87),
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: "Secure Email Address",
                    labelStyle: const TextStyle(color: Colors.black54),
                    prefixIcon: const Icon(Icons.email_outlined, color: Colors.black38),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.black12)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.blueAccent)),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: passwordController,
                  style: const TextStyle(color: Colors.black87),
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "Access Token Password",
                    labelStyle: const TextStyle(color: Colors.black54),
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.black38),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.black12)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.blueAccent)),
                  ),
                ),
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: loading ? null : handleAuth,
                    child: loading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Text(isLogin ? "EXECUTE LOGIN" : "INITIALIZE SIGN UP", style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                ),
                const SizedBox(height: 24),
                const Row(
                  children: [
                    Expanded(child: Divider(color: Colors.black12)),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text("FEDERATED NODES", style: TextStyle(color: Colors.black26, fontSize: 10, fontWeight: FontWeight.w900))),
                    Expanded(child: Divider(color: Colors.black12)),
                  ],
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _socialButton(
                      icon: Icons.g_mobiledata_rounded,
                      color: Colors.redAccent,
                      onTap: () async {
                        try {
                          UserCredential? userCredential = await authService.signInWithGoogle();
                          if (userCredential != null) {
                            bool isNew = userCredential.additionalUserInfo?.isNewUser == true;
                            if (isNew) {
                              await firebaseService.createPlayer(
                                uid: userCredential.user!.uid,
                                name: userCredential.user!.displayName ?? "Explorer",
                                email: userCredential.user!.email ?? "",
                              );
                            }
                            if (mounted) {
                              Navigator.pushReplacement(
                                context, 
                                MaterialPageRoute(
                                  builder: (_) => isNew 
                                    ? ClassSelectionScreen(uid: userCredential.user!.uid) 
                                    : const MainNavigation()
                                )
                              );
                            }
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      },
                    ),
                    _socialButton(
                      icon: Icons.no_accounts_rounded,
                      color: Colors.orange,
                      onTap: () async {
                        try {
                          UserCredential userCredential = await authService.signInAnonymously();
                          await firebaseService.createPlayer(
                            uid: userCredential.user!.uid,
                            name: "Guest Operator",
                            email: "Anonymous Node",
                          );
                          if (mounted) {
                            Navigator.pushReplacement(
                              context, 
                              MaterialPageRoute(builder: (_) => ClassSelectionScreen(uid: userCredential.user!.uid))
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      },
                    ),
                    _socialButton(
                      icon: Icons.phone_android_rounded,
                      color: Colors.green,
                      onTap: _showPhoneSignInDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextButton(
                  onPressed: () => setState(() => isLogin = !isLogin),
                  child: Text(
                    isLogin ? "REQUEST NEW LINK ACCOUNT" : "SWAP TO SYSTEM SIGN IN",
                    style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _socialButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.01),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }
}
