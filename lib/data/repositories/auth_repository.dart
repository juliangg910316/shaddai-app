import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  // OAuth "Web application" client auto-created by Firebase Auth for this
  // project (see android/app/google-services.json, client_type 3). GIS on
  // web needs this explicitly; native platforms pick their client id up
  // from google-services.json / GoogleService-Info.plist instead.
  static const _webClientId =
      '788834679654-nic5seginmam9rtruq46g36g9pet3q9e.apps.googleusercontent.com';

  AuthRepository({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
    : _auth = auth ?? FirebaseAuth.instance,
      _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // GoogleSignIn.initialize() must be called exactly once and awaited before
  // any other method is used; memoize so repeated calls (e.g. from every
  // sign-in attempt) don't re-trigger it.
  Future<void>? _initFuture;

  Future<void> ensureInitialized() {
    return _initFuture ??= _googleSignIn.initialize(
      clientId: kIsWeb ? _webClientId : null,
    );
  }

  /// Fires when a user completes sign-in/sign-out, notably via the web
  /// GIS button rendered by `google_sign_in_web/web_only.dart`.
  Stream<GoogleSignInAuthenticationEvent> get authenticationEvents =>
      _googleSignIn.authenticationEvents;

  Future<UserCredential?> signInWithGoogle() async {
    try {
      await ensureInitialized();
      final googleUser = await _googleSignIn.authenticate();
      return await signInWithGoogleAccount(googleUser);
    } catch (e) {
      debugPrint('Error en Google Sign In: $e');
      return null;
    }
  }

  Future<UserCredential?> signInWithGoogleAccount(
    GoogleSignInAccount account,
  ) async {
    final credential = GoogleAuthProvider.credential(
      idToken: account.authentication.idToken,
    );
    return await _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
