import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/models/user_model.dart';
import 'auth_failure.dart';

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

void _noop() {}

class AuthController extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _authRepo;
  final UserRepository _userRepo;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _webAuthSubscription;

  /// Vuelve a leer la ficha de la usuaria con sesión.
  final void Function() _reloadCurrentUser;

  AuthController(
    this._authRepo,
    this._userRepo, {
    void Function()? reloadCurrentUser,
  }) : _reloadCurrentUser = reloadCurrentUser ?? _noop,
       super(const AsyncData(null)) {
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
      _fail(e, st);
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    try {
      final credential = await _authRepo.signInWithGoogle();
      await _syncFirestoreUser(credential);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  /// Error técnico de un servicio externo: al log, y a la vista solo
  /// [AuthFailure.unknown] (RF-22).
  void _fail(Object error, StackTrace stackTrace) {
    debugPrint('Error al iniciar sesión: $error');
    state = AsyncError(AuthFailure.unknown, stackTrace);
  }

  Future<void> _syncFirestoreUser(UserCredential? credential) async {
    // El repositorio devuelve null cuando se cancela el diálogo de Google.
    if (credential == null) {
      state = AsyncError(AuthFailure.cancelled, StackTrace.current);
      return;
    }
    if (credential.user != null) {
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
        // La sesión se avisa antes de crear la ficha, así que
        // `currentUserProvider` la leyó vacía: sin esto no se pide el
        // WhatsApp hasta reiniciar la app.
        _reloadCurrentUser();
      } else if (existingUser.isBlocked) {
        await _authRepo.signOut();
        state = AsyncError(AuthFailure.blocked, StackTrace.current);
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
        reloadCurrentUser: () => ref.invalidate(currentUserProvider),
      );
    });
