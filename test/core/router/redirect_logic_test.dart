import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/router/redirect_logic.dart';

/// Estados de sesión de la tabla.
enum _Session {
  /// Sin sesión.
  none,

  /// Con sesión, cargando su ficha de Firestore.
  loading,

  /// Con sesión y sin WhatsApp.
  noPhone,

  /// Clienta con sesión y WhatsApp.
  client,

  /// Admin con sesión y WhatsApp.
  admin,
}

String? _redirect(
  String location, {
  required bool isWeb,
  _Session session = _Session.none,
}) {
  final uri = Uri.parse(location);
  return resolveRedirect(
    RedirectInput(
      isWeb: isWeb,
      path: uri.path,
      query: uri.queryParameters,
      isLoggedIn: session != _Session.none,
      isUserLoading: session == _Session.loading,
      needsPhone: session == _Session.noPhone,
      isAdmin: session == _Session.admin,
    ),
  );
}

void main() {
  group('móvil: igual que el redirect de antes de la spec 002', () {
    final cases = <(String, _Session, String?)>[
      // Sin sesión: solo la reserva pide iniciar sesión.
      ('/home', _Session.none, null),
      ('/services', _Session.none, null),
      ('/profile', _Session.none, null),
      ('/booking', _Session.none, '/login'),
      ('/login', _Session.none, null),
      ('/admin', _Session.none, null),
      // Ficha cargando: no se redirige con datos incompletos.
      ('/login', _Session.loading, null),
      ('/booking', _Session.loading, null),
      // Sin WhatsApp: siempre a la captura.
      ('/home', _Session.noPhone, '/capture_phone'),
      ('/booking', _Session.noPhone, '/capture_phone'),
      ('/login', _Session.noPhone, '/capture_phone'),
      ('/capture_phone', _Session.noPhone, null),
      // Con sesión completa: login y captura llevan a Inicio.
      ('/login', _Session.client, '/home'),
      ('/capture_phone', _Session.client, '/home'),
      ('/booking', _Session.client, null),
      ('/profile', _Session.client, null),
      // Sin guarda de admin en móvil (D-10).
      ('/admin', _Session.client, null),
      ('/admin', _Session.admin, null),
    ];

    for (final (location, session, expected) in cases) {
      test('$location (${session.name}) → $expected', () {
        expect(_redirect(location, isWeb: false, session: session), expected);
      });
    }
  });

  group('Web', () {
    group('direcciones de las pestañas móviles (RF-29)', () {
      for (final session in _Session.values) {
        test('/home → / (${session.name})', () {
          expect(_redirect('/home', isWeb: true, session: session), '/');
        });

        test('/services → landing en precios (${session.name})', () {
          expect(
            _redirect('/services', isWeb: true, session: session),
            '/?section=prices',
          );
        });
      }
    });

    group('sin sesión', () {
      for (final path in [
        '/booking',
        '/profile',
        '/admin',
        '/admin/users',
        '/admin/settings',
      ]) {
        test('$path pide iniciar sesión y vuelve después (RF-19, RF-29)', () {
          final redirect = _redirect(path, isWeb: true);

          expect(Uri.parse(redirect!).path, '/login');
          expect(Uri.parse(redirect).queryParameters['next'], path);
        });
      }

      for (final path in ['/', '/login', '/capture_phone']) {
        test('$path se muestra sin redirigir', () {
          expect(_redirect(path, isWeb: true), isNull);
        });
      }
    });

    test('con la ficha cargando no se redirige', () {
      for (final path in ['/', '/login', '/booking', '/admin']) {
        expect(
          _redirect(path, isWeb: true, session: _Session.loading),
          isNull,
          reason: path,
        );
      }
    });

    group('sin WhatsApp', () {
      test('la landing se ve', () {
        expect(_redirect('/', isWeb: true, session: _Session.noPhone), isNull);
      });

      test('la captura se ve', () {
        expect(
          _redirect(
            '/capture_phone?next=/booking',
            isWeb: true,
            session: _Session.noPhone,
          ),
          isNull,
        );
      });

      for (final path in ['/booking', '/profile', '/admin']) {
        test('$path pide el WhatsApp y vuelve después (RF-20)', () {
          final redirect = _redirect(
            path,
            isWeb: true,
            session: _Session.noPhone,
          );

          expect(Uri.parse(redirect!).path, '/capture_phone');
          expect(Uri.parse(redirect).queryParameters['next'], path);
        });
      }

      test('al volver del login, la captura conserva el destino (RF-20)', () {
        final redirect = _redirect(
          '/login?next=/booking',
          isWeb: true,
          session: _Session.noPhone,
        );

        expect(Uri.parse(redirect!).path, '/capture_phone');
        expect(Uri.parse(redirect).queryParameters['next'], '/booking');
      });

      test('"Entrar" sin destino pide el WhatsApp y vuelve a la landing', () {
        final redirect = _redirect(
          '/login',
          isWeb: true,
          session: _Session.noPhone,
        );

        expect(Uri.parse(redirect!).path, '/capture_phone');
        expect(Uri.parse(redirect).queryParameters['next'], '/');
      });
    });

    group('con sesión completa', () {
      test('el login lleva al destino pedido (RF-20)', () {
        expect(
          _redirect(
            '/login?next=/booking',
            isWeb: true,
            session: _Session.client,
          ),
          '/booking',
        );
      });

      test('la captura lleva al destino pedido (RF-20)', () {
        expect(
          _redirect(
            '/capture_phone?next=/booking',
            isWeb: true,
            session: _Session.client,
          ),
          '/booking',
        );
      });

      test('"Entrar" sin destino vuelve a la landing (RF-24)', () {
        expect(_redirect('/login', isWeb: true, session: _Session.client), '/');
      });

      for (final path in ['/', '/booking', '/profile']) {
        test('$path se muestra (RF-21)', () {
          expect(
            _redirect(path, isWeb: true, session: _Session.client),
            isNull,
          );
        });
      }

      for (final path in ['/admin', '/admin/users', '/admin/settings']) {
        test('una clienta en $path va a la landing', () {
          expect(_redirect(path, isWeb: true, session: _Session.client), '/');
        });

        test('la admin ve $path', () {
          expect(_redirect(path, isWeb: true, session: _Session.admin), isNull);
        });
      }
    });
  });

  group('safeNext (D-4)', () {
    for (final next in [
      '/',
      '/booking',
      '/profile',
      '/admin',
      '/admin/users',
      '/admin/settings',
    ]) {
      test('$next se acepta', () => expect(safeNext(next), next));
    }

    for (final next in [
      null,
      '',
      'https://x.com',
      '//x.com',
      '/nada',
      'booking',
      '/login',
      '/capture_phone',
    ]) {
      test('${next ?? 'null'} se cambia por /', () {
        expect(safeNext(next), '/');
      });
    }

    test('un destino externo no sale de la web tras el login', () {
      expect(
        _redirect(
          '/login?next=https://x.com',
          isWeb: true,
          session: _Session.client,
        ),
        '/',
      );
    });
  });
}
