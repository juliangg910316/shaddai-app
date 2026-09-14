import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/models/user_model.dart';

final authRepositoryProvider = Provider((ref) => AuthRepository());
final userRepositoryProvider = Provider((ref) => UserRepository());

final authStateProvider = StreamProvider((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) return null;

  final userRepo = ref.read(userRepositoryProvider);
  return await userRepo.getUser(authUser.uid);
});

class AuthController extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _authRepo;
  final UserRepository _userRepo;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _webAuthSubscription;

  AuthController(this._authRepo, this._userRepo)
    : super(const AsyncData(null)) {
    // Web has no imperative sign-in call: the user completes sign-in by
    // interacting with the GIS button rendered via renderButton(), and the
    // result arrives on this stream instead of a returned credential.
    if (kIsWeb) {
      _authRepo.ensureInitialized().then((_) {
        _webAuthSubscription = _authRepo.authenticationEvents.listen(
          _handleWebAuthEvent,
        );
      });
    }
  }

  Future<void> _handleWebAuthEvent(
    GoogleSignInAuthenticationEvent event,
  ) async {
    if (event is! GoogleSignInAuthenticationEventSignIn) return;
    state = const AsyncLoading();
    try {
      final credential = await _authRepo.signInWithGoogleAccount(event.user);
      await _syncFirestoreUser(credential);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    try {
      final credential = await _authRepo.signInWithGoogle();
      await _syncFirestoreUser(credential);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> _syncFirestoreUser(UserCredential? credential) async {
    if (credential != null && credential.user != null) {
      final fbUser = credential.user!;

      // Check if user exists in Firestore
      final existingUser = await _userRepo.getUser(fbUser.uid);

      if (existingUser == null) {
        // Create new user in Firestore
        final newUser = UserModel(
          uid: fbUser.uid,
          email: fbUser.email ?? '',
          displayName: fbUser.displayName ?? '',
          photoUrl: fbUser.photoURL,
        );
        await _userRepo.saveUser(newUser);
      } else if (existingUser.isBlocked) {
        await _authRepo.signOut();
        state = AsyncError(
          'Cuenta bloqueada por el administrador.',
          StackTrace.current,
        );
        return;
      }
    }
    state = const AsyncData(null);
  }

  Future<void> signOut() async {
    await _authRepo.signOut();
  }

  @override
  void dispose() {
    _webAuthSubscription?.cancel();
    super.dispose();
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
      return AuthController(
        ref.read(authRepositoryProvider),
        ref.read(userRepositoryProvider),
      );
    });
