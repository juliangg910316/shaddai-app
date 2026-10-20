import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Si la app corre en Web. Las vistas lo leen de aquí en lugar de usar
/// `kIsWeb` directamente, para que los tests puedan simular cada plataforma.
final isWebProvider = Provider<bool>((ref) => kIsWeb);
