import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserRepository {
  // Simulated database interaction
  Future<bool> createUserInDatabase(User? user, {String? displayName}) async {
    if (user == null) return false;
    try {
      // Logic to create user in the database
      FirebaseFirestore db = FirebaseFirestore.instance;
      print(
        "Creating user in database: ${user.uid}, ${user.email}, $displayName",
      );
      final userDoc = db.collection('users').doc(user.uid);
      print("Found user doc");
      await userDoc.set({
        'uid': user.uid,
        'email': user.email,
        'displayName': displayName ?? user.displayName ?? '',
        'workflowsCreated': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating user in database: $e');
      return false;
    }

    return true;
  }
}
