/// Reglas de redirección del router, sin Flutter ni Firebase (spec 002, D-3).
library;

/// Lo que el router sabe al decidir una redirección.
class RedirectInput {
  const RedirectInput({
    required this.isWeb,
    required this.path,
    this.query = const {},
    required this.isLoggedIn,
    required this.isUserLoading,
    required this.needsPhone,
    required this.isAdmin,
  });

  final bool isWeb;

  /// Ruta pedida, sin la query (p. ej. `/booking`).
  final String path;
  final Map<String, String> query;
  final bool isLoggedIn;

  /// La ficha de la usuaria en Firestore aún se está cargando.
  final bool isUserLoading;

  /// Tiene sesión y ficha, pero no ha dado su WhatsApp.
  final bool needsPhone;
  final bool isAdmin;
}

/// Destinos a los que se puede volver tras el login (`?next=`).
const _allowedNext = {
  '/',
  '/booking',
  '/profile',
  '/admin',
  '/admin/users',
  '/admin/settings',
};

/// Páginas de cuenta de Web: piden sesión y WhatsApp.
bool _isAccountPage(String path) =>
    path == '/booking' ||
    path == '/profile' ||
    path == '/admin' ||
    path.startsWith('/admin/');

bool _isAdminPage(String path) =>
    path == '/admin' || path.startsWith('/admin/');

/// [next] si es un destino interno conocido; si no, la landing. Así un
/// enlace manipulado no saca a la persona de la web tras el login (D-4).
String safeNext(String? next) => _allowedNext.contains(next) ? next! : '/';

String _withNext(String path, String next) =>
    Uri(path: path, queryParameters: {'next': next}).toString();

/// Ruta a la que hay que ir, o `null` para quedarse en [RedirectInput.path].
String? resolveRedirect(RedirectInput input) =>
    input.isWeb ? _web(input) : _mobile(input);

/// Android/iOS: el comportamiento de antes de la spec 002, sin cambios.
String? _mobile(RedirectInput input) {
  final path = input.path;

  if (!input.isLoggedIn) {
    return path.startsWith('/booking') ? '/login' : null;
  }
  // Con la ficha cargando no se redirige con datos incompletos.
  if (input.isUserLoading) return null;

  if (input.needsPhone) {
    return path == '/capture_phone' ? null : '/capture_phone';
  }
  if (path == '/login' || path == '/capture_phone') return '/home';
  return null;
}

/// Web: landing pública y páginas de cuenta (spec 002, plan § 4).
String? _web(RedirectInput input) {
  final path = input.path;

  // Direcciones de las pestañas móviles (RF-29).
  if (path == '/home') return '/';
  if (path == '/services') return '/?section=prices';

  final isAccountPage = _isAccountPage(path);

  // Sin sesión, las páginas de cuenta piden iniciarla y vuelven después
  // (RF-19, RF-29; también si la sesión caducó).
  if (!input.isLoggedIn) {
    return isAccountPage ? _withNext('/login', path) : null;
  }
  if (input.isUserLoading) return null;

  // Sin WhatsApp, la landing se ve; las páginas de cuenta lo piden antes.
  if (input.needsPhone) {
    if (path == '/capture_phone') return null;
    if (isAccountPage || path == '/login') {
      return _withNext('/capture_phone', safeNext(input.query['next'] ?? path));
    }
    return null;
  }

  // La guarda de admin es solo de interfaz: la seguridad va en las reglas de
  // Firestore (spec 009).
  if (_isAdminPage(path) && !input.isAdmin) return '/';

  // Tras el login o la captura, al destino pedido o a la landing (RF-20, RF-24).
  if (path == '/login' || path == '/capture_phone') {
    return safeNext(input.query['next']);
  }
  return null;
}
