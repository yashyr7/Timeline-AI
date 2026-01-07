import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth;
  AuthService(this._auth);

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    // Your signup logic here
    UserCredential user = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return user;
  }

  Future<UserCredential> signInWithGoogle() async {
    // Trigger the Google Authentication flow
    // For mobile platforms use GoogleSignIn; on web the FirebaseAuth JS provider is used by default
    try {
      // Use the singleton instance and call authenticate to start interactive sign-in
      final GoogleSignInAccount account = await GoogleSignIn.instance
          .authenticate();
      // The plugin's authentication currently exposes an idToken. Use it to build the credential.
      final GoogleSignInAuthentication auth = account.authentication;
      final String? idToken = auth.idToken;

      if (idToken == null) {
        throw FirebaseAuthException(
          code: 'ERROR_MISSING_GOOGLE_ID_TOKEN',
          message: 'Missing Google ID token',
        );
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      // Sign in to Firebase with the Google [UserCredential]
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      print("FIREBASE AUTH EXCEPTION ${e.toString()}");
      // Wrap non-Firebase exceptions
      throw FirebaseAuthException(
        code: 'ERROR_GOOGLE_SIGN_IN_FAILED',
        message: e.toString(),
      );
    }
  }

  Future<UserCredential> login({
    required String email,
    required String password,
  }) {
    // Your login logic here
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> logout() async {
    // Sign out from both Firebase and GoogleSignIn to fully disconnect the account
    try {
      await _auth.signOut();
    } finally {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // ignore GoogleSignIn sign out errors
      }
    }
  }
}
