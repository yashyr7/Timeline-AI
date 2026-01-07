import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sign_in_button/sign_in_button.dart';
import 'package:timeline_flutter/services/auth_service.dart';
import 'package:timeline_flutter/services/user_service.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  late TextEditingController emailController;
  late TextEditingController passwordController;

  bool isLoading = false;

  void initState() {
    super.initState();
    emailController = TextEditingController();
    passwordController = TextEditingController();
  }

  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    setState(() {
      isLoading = true;
    });
    try {
      AuthService authService = AuthService(FirebaseAuth.instance);
      UserRepository repo = UserRepository();
      UserCredential user = await authService.signUpWithEmail(
        email: email,
        password: password,
      );
      await repo.createUserInDatabase(
        FirebaseAuth.instance.currentUser,
        displayName: user.user!.displayName,
      );
    } on FirebaseAuthException catch (e) {
      print(e.message);
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => isLoading = true);
    try {
      final authService = AuthService(FirebaseAuth.instance);
      UserRepository repo = UserRepository();
      final userCred = await authService.signInWithGoogle();
      if (!mounted) return;

      print(userCred.additionalUserInfo?.isNewUser);
      if (userCred.additionalUserInfo?.isNewUser == true) {
        await repo.createUserInDatabase(
          FirebaseAuth.instance.currentUser,
          displayName: userCred.user!.displayName,
        );
      }

      final userEmail = userCred.user?.email ?? 'unknown';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Signed in as $userEmail')));
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Google sign-in failed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Google sign-in error: $e')));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: SafeArea(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
            child: Column(
              children: [
                Text("Sign up"),
                Text(
                  "Timeline",
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                SignInButton(Buttons.google, onPressed: _handleGoogleSignIn),
                TextField(controller: emailController),
                TextField(controller: passwordController),
                TextButton(onPressed: _handleSignup, child: Text("Sign Up")),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
