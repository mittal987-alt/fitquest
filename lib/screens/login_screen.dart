import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../services/firebase_service.dart';

import 'main_navigation.dart';

class LoginScreen extends StatefulWidget {

  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState
    extends State<LoginScreen> {

  final emailController =
  TextEditingController();

  final passwordController =
  TextEditingController();

  final nameController =
  TextEditingController();

  bool isLogin = true;

  bool loading = false;

  final FirebaseAuth auth =
      FirebaseAuth.instance;

  final FirebaseService
  firebaseService =
  FirebaseService();

  // =========================
  // AUTH
  // =========================

  Future<void> handleAuth()
  async {

    try {

      setState(() {

        loading = true;
      });

      String email =
      emailController.text
          .trim();

      String password =
      passwordController.text
          .trim();

      if (isLogin) {

        await auth
            .signInWithEmailAndPassword(

          email: email,

          password: password,
        );

      } else {

        UserCredential userCredential =

        await auth
            .createUserWithEmailAndPassword(

          email: email,

          password: password,
        );

        await firebaseService
            .createPlayer(

          uid:
          userCredential
              .user!
              .uid,

          name:
          nameController.text
              .trim(),

          email: email,
        );
      }

      if (mounted) {

        Navigator.pushReplacement(

          context,

          MaterialPageRoute(

            builder: (_) =>
            const MainNavigation(),
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content:
            Text(e.toString()),
          ),
        );
      }
    }

    setState(() {

      loading = false;
    });
  }

  Widget _socialButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(icon, color: color, size: 30),
      ),
    );
  }

  void _showPhoneSignInDialog() {
    final phoneController = TextEditingController();
    final codeController = TextEditingController();
    String? vId;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (builderContext, setDialogState) => AlertDialog(
          title: const Text("Phone Login"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (vId == null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: "Phone Number",
                        hintText: "+1234567890",
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        "Include country code (e.g., +1 for US)",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                )
              else
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: "Verification Code",
                    prefixIcon: Icon(Icons.lock_clock),
                  ),
                  keyboardType: TextInputType.number,
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (vId == null) {
                  final phone = phoneController.text.trim();
                  if (!RegExp(r'^\+[1-9]\d{1,14}$').hasMatch(phone)) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Enter a valid phone number in E.164 format (e.g. +1234567890)"),
                        ),
                      );
                    }
                    return;
                  }

                  await firebaseService.verifyPhone(
                    phoneNumber: phone,
                    verificationCompleted: (cred) async {
                      try {
                        await auth.signInWithCredential(cred);
                        if (mounted) {
                          if (Navigator.canPop(dialogContext)) {
                            Navigator.pop(dialogContext);
                          }
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const MainNavigation()),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Auto-verification failed: ${e.toString()}")),
                          );
                        }
                      }
                    },
                    verificationFailed: (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.message ?? "Verification failed")),
                        );
                      }
                    },
                    codeSent: (id, resendToken) {
                      if (mounted) {
                        setDialogState(() => vId = id);
                      }
                    },
                    codeAutoRetrievalTimeout: (id) {
                      if (mounted) {
                        setDialogState(() => vId = id);
                      }
                    },
                  );
                } else {
                  try {
                    UserCredential userCredential = await firebaseService.signInWithPhone(
                      vId!,
                      codeController.text.trim(),
                    );
                    if (userCredential.additionalUserInfo!.isNewUser) {
                      await firebaseService.createPlayer(
                        uid: userCredential.user!.uid,
                        name: "Phone User",
                        email: userCredential.user!.phoneNumber ?? "",
                      );
                    }
                    if (mounted) {
                      if (Navigator.canPop(dialogContext)) {
                        Navigator.pop(dialogContext);
                      }
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const MainNavigation()),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  }
                }
              },
              child: Text(vId == null ? "Send Code" : "Verify"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor:
      Colors.grey.shade100,

      body: Center(

        child: SingleChildScrollView(

          padding:
          const EdgeInsets.all(
              24),

          child: Container(

            padding:
            const EdgeInsets.all(
                24),

            decoration: BoxDecoration(

              color: Colors.white,

              borderRadius:
              BorderRadius.circular(
                  28),

              boxShadow: [

                BoxShadow(

                  color:
                  Colors.black12,

                  blurRadius: 12,
                ),
              ],
            ),

            child: Column(

              mainAxisSize:
              MainAxisSize.min,

              children: [

                const Icon(

                  Icons.public,

                  size: 80,

                  color: Colors.blue,
                ),

                const SizedBox(
                    height: 20),

                const Text(

                  "FitQuest",

                  style: TextStyle(

                    fontSize: 34,

                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(
                    height: 8),

                Text(

                  isLogin
                      ? "Welcome Back"
                      : "Create Account",

                  style: TextStyle(

                    color:
                    Colors.grey
                        .shade700,

                    fontSize: 18,
                  ),
                ),

                const SizedBox(
                    height: 30),

                // NAME
                if (!isLogin)

                  TextField(

                    controller:
                    nameController,

                    decoration:
                    InputDecoration(

                      labelText:
                      "Name",

                      prefixIcon:
                      const Icon(
                          Icons.person),

                      border:
                      OutlineInputBorder(

                        borderRadius:
                        BorderRadius.circular(
                            18),
                      ),
                    ),
                  ),

                if (!isLogin)
                  const SizedBox(
                      height: 16),

                // EMAIL
                TextField(

                  controller:
                  emailController,

                  decoration:
                  InputDecoration(

                    labelText:
                    "Email",

                    prefixIcon:
                    const Icon(
                        Icons.email),

                    border:
                    OutlineInputBorder(

                      borderRadius:
                      BorderRadius.circular(
                          18),
                    ),
                  ),
                ),

                const SizedBox(
                    height: 16),

                // PASSWORD
                TextField(

                  controller:
                  passwordController,

                  obscureText: true,

                  decoration:
                  InputDecoration(

                    labelText:
                    "Password",

                    prefixIcon:
                    const Icon(
                        Icons.lock),

                    border:
                    OutlineInputBorder(

                      borderRadius:
                      BorderRadius.circular(
                          18),
                    ),
                  ),
                ),

                const SizedBox(
                    height: 24),

                // BUTTON
                SizedBox(

                  width:
                  double.infinity,

                  child:
                  ElevatedButton(

                    style:
                    ElevatedButton.styleFrom(

                      backgroundColor:
                      Colors.blue,

                      padding:
                      const EdgeInsets.symmetric(
                        vertical: 18,
                      ),

                      shape:
                      RoundedRectangleBorder(

                        borderRadius:
                        BorderRadius.circular(
                            18),
                      ),
                    ),

                    onPressed:
                    loading
                        ? null
                        : handleAuth,

                    child: loading

                        ? const CircularProgressIndicator(
                      color:
                      Colors.white,
                    )

                        : Text(

                      isLogin
                          ? "Login"
                          : "Sign Up",
                    ),
                  ),
                ),

                const SizedBox(
                    height: 16),

                // SOCIAL SIGN IN
                const Divider(),

                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _socialButton(
                      icon: Icons.g_mobiledata,
                      color: Colors.red,
                      onTap: () async {
                        try {
                          UserCredential? userCredential = await firebaseService.signInWithGoogle();
                          if (userCredential != null && userCredential.additionalUserInfo!.isNewUser) {
                            await firebaseService.createPlayer(
                              uid: userCredential.user!.uid,
                              name: userCredential.user!.displayName ?? "New Explorer",
                              email: userCredential.user!.email ?? "",
                            );
                          }
                          if (mounted) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const MainNavigation()),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      },
                    ),
                    _socialButton(
                      icon: Icons.person_outline,
                      color: Colors.orange,
                      onTap: () async {
                        try {
                          UserCredential userCredential = await firebaseService.signInAnonymously();
                          await firebaseService.createPlayer(
                            uid: userCredential.user!.uid,
                            name: "Guest",
                            email: "anonymous",
                          );
                          if (mounted) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const MainNavigation()),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      },
                    ),
                    _socialButton(
                      icon: Icons.phone,
                      color: Colors.green,
                      onTap: () {
                        // Logic for phone sign-in (could open a dialog)
                        _showPhoneSignInDialog();
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                TextButton(

                  onPressed: () {

                    setState(() {

                      isLogin =
                      !isLogin;
                    });
                  },

                  child: Text(

                    isLogin

                        ? "Create New Account"

                        : "Already Have Account?",
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}