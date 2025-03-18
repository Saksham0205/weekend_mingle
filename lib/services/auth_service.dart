import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(
      String email,
      String password,
      ) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update FCM token
      await NotificationService.updateToken(userCredential.user!.uid);

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword(
      String email,
      String password,
      String name,
      String profession,
      ) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user profile in Firestore
      await _createUserProfile(
        userCredential.user!.uid,
        name,
        email,
        profession,
      );

      // Update FCM token
      await NotificationService.updateToken(userCredential.user!.uid);

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Sign in with Google
  Future<UserCredential> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw 'Google sign in aborted';

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      // Create/Update user profile in Firestore
      await _createUserProfile(
        userCredential.user!.uid,
        userCredential.user!.displayName ?? '',
        userCredential.user!.email ?? '',
        '', // Profession will need to be updated later
      );

      // Update FCM token
      await NotificationService.updateToken(userCredential.user!.uid);

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Create user profile in Firestore
  Future<void> _createUserProfile(
      String uid,
      String name,
      String email,
      String profession,
      ) async {
    await _firestore.collection('users').doc(uid).set({
      'name': name,
      'email': email,
      'profession': profession,
      'createdAt': FieldValue.serverTimestamp(),
      'interests': [],
      'bio': '',
      'photoUrl': '',
      'location': null,
      'lastActive': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Clear FCM token on sign out
      final uid = currentUser?.uid;
      if (uid != null) {
        await _firestore.collection('users').doc(uid).update({
          'fcmToken': null,
        });
      }

      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      rethrow;
    }
  }
}