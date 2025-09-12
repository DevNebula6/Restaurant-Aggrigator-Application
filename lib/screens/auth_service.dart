// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:google_sign_in/google_sign_in.dart';
//
// class AuthService {
//   final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
//   final GoogleSignIn _googleSignIn = GoogleSignIn();
//
//   // Sign in with Google
//   Future<User?> signInWithGoogle() async {
//     try {
//       // Trigger the Google Sign-In flow
//       final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
//
//       if (googleUser == null) {
//         // If the user cancels the sign-in flow
//         return null;
//       }
//
//       // Obtain the Google Sign-In authentication details
//       final GoogleSignInAuthentication googleAuth =
//       await googleUser.authentication;
//
//       // Create a new credential for Firebase Authentication
//       final AuthCredential credential = GoogleAuthProvider.credential(
//         accessToken: googleAuth.accessToken,
//         idToken: googleAuth.idToken,
//       );
//
//       // Use the credential to sign in to Firebase
//       final UserCredential userCredential =
//       await _firebaseAuth.signInWithCredential(credential);
//
//       return userCredential.user;
//     } catch (e) {
//       print('Error during Google Sign-In: $e');
//       return null;
//     }
//   }
//
//   // Sign out
//   Future<void> signOut() async {
//     try {
//       await _googleSignIn.signOut();
//       await _firebaseAuth.signOut();
//     } catch (e) {
//       print('Error signing out: $e');
//     }
//   }
//
//   // Get the currently signed-in user
//   User? get currentUser => _firebaseAuth.currentUser;
//
//   // Listen to authentication state changes
//   Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
// }
