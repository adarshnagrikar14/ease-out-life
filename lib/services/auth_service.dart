import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId:
        '768198234267-vtc7iaauqpcd0mm2fd6huh661clnt0uo.apps.googleusercontent.com',
    scopes: [
      'email',
      'profile',
    ],
  );

  static const String calendarScope = gcal.CalendarApi.calendarScope;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Email & password sign-up
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Email & password sign-in
  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Google sign-in (basic — no calendar scope yet)
  Future<UserCredential> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw AuthCancelledException();
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return await _auth.signInWithCredential(credential);
  }

  // Request Google Calendar permission (adds calendar scope)
  Future<bool> requestCalendarPermission() async {
    final granted = await _googleSignIn.requestScopes([calendarScope]);
    return granted;
  }

  // Check if calendar scope is already granted
  bool get isSignedInWithGoogle => _googleSignIn.currentUser != null;

  // Get authenticated Calendar API client
  Future<gcal.CalendarApi?> getCalendarApi() async {
    final httpClient = await _googleSignIn.authenticatedClient();
    if (httpClient == null) return null;
    return gcal.CalendarApi(httpClient);
  }

  // Password reset
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Sign out
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }
}

class AuthCancelledException implements Exception {
  @override
  String toString() => 'Sign-in was cancelled.';
}
