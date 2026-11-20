import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/push_repository.dart';

/// El repositorio de los avisos push (spec 011, plan D-11). `main` lo
/// sustituye por uno con el almacenamiento del dispositivo; los tests, por
/// `FakePushRepository`.
final pushRepositoryProvider = Provider<PushRepository>(
  (ref) => PushRepository(),
);
