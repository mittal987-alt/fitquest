import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import '../services/pedometer_service.dart';
import '../services/step_sync_service.dart';
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please fill in all standard validation fields.")),
        );
      }
      return;
    }

    try {
      setState(() => loading = true);

      if (isLogin) {
        await auth.signInWithEmailAndPassword(email: email, password: password);
        PedometerService().reset();
        StepSyncService().reset();
      } else {
        UserCredential userCredential = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        PedometerService().reset();
        StepSyncService().reset();
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
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return StatefulBuilder(
          builder: (builderContext, setDialogState) => AlertDialog(
            backgroundColor: colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: colorScheme.onSurface.withValues(alpha: 0.1)),
            ),
            title: Text(
              "SECURE PHONE LINK",
              style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1),
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
                        style: TextStyle(color: colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: "Phone Number",
                          labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                          hintText: "+1234567890",
                          hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                          prefixIcon: Icon(Icons.phone_rounded, color: colorScheme.primary),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: colorScheme.outlineVariant)),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: colorScheme.primary)),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          "Enter a valid phone number in E.164 format (e.g. +1234567890)",
                          style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  )
                else
                  TextField(
                    controller: codeController,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: "Verification Token",
                      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                      prefixIcon: Icon(Icons.lock_clock_rounded, color: colorScheme.primary),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: colorScheme.outlineVariant)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: colorScheme.primary)),
                    ),
                    keyboardType: TextInputType.number,
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text("CANCEL", style: TextStyle(color: colorScheme.onSurfaceVariant)),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [colorScheme.primary, colorScheme.secondary]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    if (vId == null) {
                      final phone = phoneController.text.trim();
                      if (!RegExp(r'^\+[1-9]\d{1,14}$').hasMatch(phone)) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Enter a valid phone number in E.164 format (e.g. +1234567890)")),
                          );
                        }
                        return;
                      }

                      await authService.verifyPhone(
                        phoneNumber: phone,
                        verificationCompleted: (cred) async {
                          try {
                            UserCredential userCredential = await auth.signInWithCredential(cred);
                            PedometerService().reset();
                            StepSyncService().reset();
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
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.message ?? "Verification Fault")),
                            );
                          }
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
                        PedometerService().reset();
                        StepSyncService().reset();
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
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      }
                    }
                  },
                  child: Text(vId == null ? "REQUEST CODE" : "VERIFY CODE", style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.05), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.public_rounded, size: 70, color: colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  "FITQUEST",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: colorScheme.onSurface, letterSpacing: 2),
                ),
                const SizedBox(height: 6),
                Text(
                  isLogin ? "START PLAYER SESSION" : "CREATE PLAYER PROFILE",
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
                const SizedBox(height: 32),

                if (!isLogin) ...[
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: "Player Name",
                      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                      prefixIcon: Icon(Icons.person_outline_rounded, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colorScheme.outlineVariant)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colorScheme.primary)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                TextField(
                  controller: emailController,
                  style: TextStyle(color: colorScheme.onSurface),
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: "Email Address",
                    labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    prefixIcon: Icon(Icons.email_outlined, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colorScheme.outlineVariant)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colorScheme.primary)),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: passwordController,
                  style: TextStyle(color: colorScheme.onSurface),
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "Password",
                    labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    prefixIcon: Icon(Icons.lock_outline_rounded, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colorScheme.outlineVariant)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colorScheme.primary)),
                  ),
                ),
                const SizedBox(height: 28),

                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: loading ? null : LinearGradient(colors: [colorScheme.primary, colorScheme.secondary]),
                    borderRadius: BorderRadius.circular(16),
                    color: loading ? colorScheme.onSurface.withValues(alpha: 0.1) : null,
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: loading ? null : handleAuth,
                    child: loading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Text(isLogin ? "SIGN IN" : "SIGN UP", style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                ),
                const SizedBox(height: 24),
                const Row(
                  children: [
                    Expanded(child: Divider(color: Colors.black12)),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text("SOCIAL SIGN IN", style: TextStyle(color: Colors.black26, fontSize: 10, fontWeight: FontWeight.w900))),
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
                            PedometerService().reset();
                            StepSyncService().reset();
                            // Profile creation/existence check is now handled inside authService.signInWithGoogle()
                            if (mounted) {
                              Navigator.pushReplacement(
                                context, 
                                MaterialPageRoute(
                                  builder: (_) => (userCredential.additionalUserInfo?.isNewUser ?? true)
                                    ? ClassSelectionScreen(uid: userCredential.user!.uid) 
                                    : const MainNavigation()
                                )
                              );
                            }
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                          }
                        }
                      },
                    ),
                    _socialButton(
                      icon: Icons.no_accounts_rounded,
                      color: Colors.orange,
                      onTap: () async {
                        try {
                          UserCredential userCredential = await authService.signInAnonymously();
                          PedometerService().reset();
                          StepSyncService().reset();
                          await firebaseService.ensurePlayerProfileExists(
                            userCredential.user!.uid,
                            "Anonymous Player",
                            "Guest Player",
                          );
                          if (mounted) {
                            Navigator.pushReplacement(
                              context, 
                              MaterialPageRoute(builder: (_) => ClassSelectionScreen(uid: userCredential.user!.uid))
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                          }
                        }
                      },
                    ),
                    _socialButton(
                      icon: Icons.phone_android_rounded,
                      color: Colors.cyanAccent,
                      onTap: _showPhoneSignInDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextButton(
                  onPressed: () => setState(() => isLogin = !isLogin),
                  child: Text(
                    isLogin ? "CREATE AN ACCOUNT" : "ALREADY HAVE AN ACCOUNT?",
                    style: TextStyle(color: colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5),
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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          shape: BoxShape.circle,
          border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.05),
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
