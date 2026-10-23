# Plan 004 — Servicios y precios en Firestore
Estado: aprobada

Spec: `specs/004-servicios-firestore/spec.md` (aprobada el 2026-10-22).

## 1. Qué existe ya en el código

| Pieza | Estado | Qué hace este plan |
| --- | --- | --- |
| `LandingContent.priceCards` y `LandingContent.combos` (`lib/features/landing/landing_content.dart`), con los tipos `PriceCard`, `PriceLine`, `PriceItem`, `PriceGroup` y `Combo` | Precios fijos en el código; textos en los `.arb` (`landingServices1…6*`, `landingCombo1…3*`) | Se borran (RF-12). Sus datos pasan a la carga inicial (RF-36). |
| `PricesSection` y `CombosSection` (`lib/features/landing/presentation/sections/`) | Pintan los datos fijos; 2 filas de 3 tarjetas en ancho y una columna en estrecho | Leen la base de datos; mismo diseño, más la flecha y los estados de carga, error y sin datos (RF-1 a RF-11, RF-41). |
| `CatalogSection` | Páginas fijas del catálogo | Añade el aviso de RF-42. |
| `ServicesView` (pestaña Servicios) y `LandingPage` (Web) | Montan las secciones | Sin cambios de estructura. |
| `MainScaffold._onSelected` | Tocar la pestaña activa sube al comienzo y vuelve a la ruta raíz de la rama | Distingue "detalle abierto" de "lista" (RF-45). |
| `HomeView._openPrices` | `jumpTo(0)` + `context.go('/services')` | Ya cierra un detalle abierto, porque `go` sustituye la pila de la rama. Solo se añade el test (RF-46). |
| `StatefulShellRoute.indexedStack` | Conserva la pila de cada rama al cambiar de pestaña | Cumple RF-47 si el detalle es una ruta hija de `/services`. Solo test. |
| `resolveRedirect` | Web: `/services` exacto → `/?section=prices`; `/admin…` solo admin | Las rutas de detalle son públicas sin regla nueva. Se añade `/admin/services` a los destinos válidos de `next`. |
| `AdminDashboardView` (cabecera) | Iconos de Usuarias y Ajustes | Añade el icono "Servicios" (RF-19). |
| `ConfigRepository` / `calendarSettingsProvider` | Duración global del turno | La carga inicial la usa (RF-37). |
| `WebAccountPage`, `WhatsappFloatButton`, `goToLandingSection` | Existen | El detalle Web los reutiliza (RF-43, RF-44). |
| URLs de Web | Estrategia por defecto, con `#` (no hay `usePathUrlStrategy`) | Los enlaces de detalle funcionan en Hostinger sin reglas de reescritura. |
| `firestore.rules`, entrada `firestore` en `firebase.json`, tests de reglas | No existen | Se crean, solo para `settings/priceList` (RNF-2). |
| `uuid` | Dependencia ya aprobada | Genera los ids de categorías, servicios y combos. |

## 2. Datos en Firestore (RF-1 a RF-6, RF-12, RF-26 a RF-40, RNF-2)

### Documento único `settings/priceList`
Toda la lista de precios vive en **un solo documento**, junto a `settings/calendar`:

```
settings/priceList
  schemaVersion: 1
  updatedAt: timestamp del servidor
  categories: [                         # el orden del array es el de la lista
    { id: uuid,
      name:     { es, pt },
      subtitle: { es, pt },             # vacíos en los dos idiomas = sin subtítulo
      note:     { es, pt },
      visible:  bool,
      items: [                          # servicios y adicionales mezclados, en su orden
        { id: uuid,
          kind: 'service' | 'addon',
          name:        { es, pt },
          description: { es, pt },      # solo service
          group:       { es, pt },      # solo service; vacío = sin grupo
          priceCents:  int,             # 3050 = R$ 30,50
          priceFrom:   bool,            # solo service
          durationMinutes: int,         # solo service
          visible: bool } ] } ]
  combos: [
    { id, name, description, priceCents, durationMinutes, visible } ]
```

- **Precio en céntimos (`int`)**: evita los errores de redondeo de `double` y hace exacta la regla "dos decimales como máximo" (RF-24).
- **Compatibilidad** (constitución, principio 5): es un documento nuevo, así que no hay documentos anteriores que migrar. La lectura es tolerante, para documentos editados a mano en la consola o de versiones futuras:
  - si falta `visible`, se toma `true`;
  - si un texto falta en un idioma, se muestra el del otro idioma;
  - si un elemento no tiene nombre en ningún idioma o tiene un precio que no es un entero ≥ 0, no se muestra, y se avisa con `debugPrint`;
  - si falta `kind`, se toma `'service'`; si falta `durationMinutes`, se toma 60;
  - los campos desconocidos se ignoran y no se pierden: el guardado los conserva.
- Sin índices: es una lectura directa por id de documento.

### Reglas: `firestore.rules` (nuevo) y `firebase.json`
```
match /settings/priceList {
  allow read: if true;                                          // RNF-2: sin sesión
  allow create, update: if isAdmin();
  allow delete: if false;
}
function isAdmin() {
  return request.auth != null &&
    get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
}
```
- `firebase.json` añade `"firestore": { "rules": "firestore.rules" }`.
- **Resto de colecciones (A-2):** desplegar un `firestore.rules` que solo tenga `settings/priceList` **deniega todo lo demás** (usuarias, turnos, calendario) y rompe la app. Como las reglas de la consola nunca se tocaron, son las de por defecto: o "modo de prueba" (todo abierto hasta una fecha, que puede haber caducado) o "modo de producción" (todo cerrado). El archivo lleva para el resto una regla **provisional**, marcada para sustituirla en la spec 009:
  ```
  match /{document=**} {
    allow read, write: if request.auth != null;   // PROVISIONAL hasta la spec 009
  }
  ```
  Es lo mínimo que la app necesita hoy: todas las lecturas y escrituras de usuarias, turnos y calendario se hacen con sesión. Es más estricta que el modo de prueba y no rompe nada que funcione hoy. Como `settings/priceList` tiene su propio `match`, y Firestore permite si *alguna* regla permite, la regla provisional también dejaría escribir la lista de precios a cualquier persona con sesión. Por eso la provisional **excluye `settings/priceList`**: el comodín se divide en `match /users/{id}`, `match /appointments/{id}` y `match /settings/calendar`, cada uno con `request.auth != null`.
- **Despliegue (lo hace el autor):** antes, mira en la consola (Firestore → Reglas) qué hay y guarda una copia. Después ejecuta `firebase deploy --only firestore:rules`, y por último las comprobaciones manuales de § 9.

### Caché sin conexión (RF-40)
- **Android/iOS**: Firestore guarda en el dispositivo por defecto; no hay que cambiar nada.
- **Web**: la caché persistente viene desactivada. Una función de `lib/data/` (`configureFirestoreCache()`), llamada desde `main.dart` tras `Firebase.initializeApp`, la activa con IndexedDB. Si el navegador no la permite (modo privado, varias pestañas), se sigue con la caché en memoria, que solo dura mientras la página está abierta, y se avisa con `debugPrint`.

## 3. Capa `lib/data/`

| Archivo | Responsabilidad | RF |
| --- | --- | --- |
| `models/price_list_model.dart` (nuevo) | `BilingualText` (`es`, `pt`, `of(languageCode)` con respaldo al otro idioma, `isEmpty`); `PriceCategoryModel`, `PriceItemModel` (con `PriceItemKind { service, addon }`), `ComboModel`, `PriceListModel`. Cada uno con `fromMap` tolerante, `toMap` y `copyWith`. Conservan los campos desconocidos. | RF-1 a RF-5, principio 5 |
| `repositories/price_list_repository.dart` (nuevo) | Recibe `FirebaseFirestore?` en el constructor y usa `.instance` por defecto. Tres operaciones: **`watch()`** devuelve un stream de `PriceListSnapshot` (`PriceListModel?` + `fromCache`); **`update(transform)`** ejecuta una transacción: lee el documento, aplica `transform` (pura) y guarda con `updatedAt` del servidor; lanza `PriceListMissing` si el documento no existe y `PriceListItemGone` si `transform` lo indica; **`seed(initial)`** ejecuta una transacción que lanza `PriceListAlreadySeeded` si el documento ya existe y, si no, lo crea entero. | RF-6, RF-26 a RF-36, RF-38, RF-39 |
| `firestore_cache.dart` (nuevo) | `configureFirestoreCache({required bool isWeb})`: caché persistente en Web. | RF-40 |

La transacción de `seed` crea un único documento, así que es atómica: o se crea todo o no se crea nada (RF-39). Si se pide dos veces seguidas, la segunda encuentra el documento y no hace nada (RF-38). `update` en transacción hace que dos admins que cambian elementos distintos no se pisen; si cambian el mismo elemento, gana el último (caso límite de la spec).

## 4. Lógica pura (sin Flutter ni Firebase)

Los archivos van en `lib/features/services/logic/`, como `redirect_logic.dart` y `preferences_logic.dart`, y no importan ni Flutter ni Firebase. Ninguna regla de esta spec depende de la hora, así que no reciben "ahora".

### `price_list_view_logic.dart`: lo que ve la clienta
- `PriceListState resolvePriceListState({PriceListSnapshot? snapshot, bool timedOut})` (RF-7, RF-8, RF-10, RF-40):
  ```
  si hay snapshot con documento          → Ready(lista)   (también si viene de caché: RF-40)
  si hay snapshot sin documento:
      si NO viene de caché                → Ready(lista vacía)   → RF-10
      si viene de caché y timedOut        → Unavailable          → RF-8
      si viene de caché y no timedOut     → Loading              (puede llegar el servidor)
  sin snapshot: timedOut ? Unavailable : Loading
  ```
  Los errores del stream (permisos, red) dan `Unavailable` en el provider.
- `PublicPriceList visiblePriceList(PriceListModel list)` (RF-1, RF-3, RF-4, RF-11, RF-28):
  ```
  shown = categorías con visible == true
          cuyo items filtrados por visible no quedan vacíos
  número de cada categoría = su posición en shown, 1-based, con dos cifras ("01")
  dentro de cada categoría, partir items en bloques: un bloque nuevo cada vez
      que cambia group (comparando en el idioma activo; vacío = sin título)
  combos = combos con visible == true
  isEmpty = shown vacío      → RF-10 (también si hay categorías visibles pero todas vacías)
  ```
- `DetailResult findDetail(PriceListModel list, DetailKind kind, String id)` (RF-14, RF-15, RF-17):
  ```
  kind service: buscar el item con ese id y kind service;
      NotAvailable si no existe, si está oculto o si su categoría está oculta
      (también para la admin: no hay vista previa de ocultos)
      si no → ServiceDetail(item, categoría)
  kind combo: NotAvailable si no existe u oculto; si no → ComboDetail(combo)
  un adicional nunca tiene detalle (RF-18) → NotAvailable
  ```
- `String formatPrice(int cents, {bool addon = false, String Function(String)? from})`: devuelve "R$ 30", "R$ 30,50" o "+R$ 15"; con `from`, "desde R$ 110" / "a partir de R$ 110" (el texto viene del `.arb`). El separador decimal es la coma en ES y en PT.
- `String formatDuration(int minutes)`: "45 min", "1 h", "1 h 30 min" (igual en los dos idiomas).

### `price_list_edit_logic.dart`: cambios de la admin (RF-26 a RF-32)
Todas reciben la lista y devuelven una lista nueva, o lanzan `ItemGone` si el id ya no existe (otra admin lo borró):
- `upsertCategory`, `upsertItem(categoryId, item)` y `upsertCombo`: un elemento nuevo va **al final** de su lista o categoría. Si se edita un servicio o adicional y cambia de categoría, se quita de la vieja y se añade al final de la nueva (RF-32).
- `moveCategory`, `moveItem` y `moveCombo`, con un desplazamiento de −1 o +1: intercambian el elemento con su vecino. No hacen nada en los extremos (la interfaz desactiva esos botones). Mover un servicio no tiene en cuenta los grupos: si un grupo queda partido, su título sale dos veces, y la admin lo ve en la gestión.
- `setCategoryVisible`, `setItemVisible` y `setComboVisible` (RF-27): no borran ningún dato.
- `deleteItem` y `deleteCombo` (RF-29).
- `CategoryDeleteCheck canDeleteCategory(list, id)`: `HasItems` o `Empty` (RF-30, RF-31). `deleteCategory` lanza un error si la categoría tiene elementos (doble seguro).

### `price_list_form_logic.dart`: validaciones (RF-21 a RF-25)
- `int? parsePriceCents(String input)`: quita los espacios y acepta coma o punto decimal; acepta "30", "30,5", "30,50" y "30.50". Devuelve `null` si está vacío, es negativo, no es un número, tiene más de 2 decimales o pasa de R$ 99.999,99.
- `int? parseDuration(String input)`: un entero entre 5 y 480; si no, `null`.
- `Map<FormField, FormError> validateCategory / validateService / validateAddon / validateCombo(form)`. Cada texto se recorta antes de comprobarlo: un texto con solo espacios cuenta como vacío. Errores posibles:
  - `required`: falta el nombre en un idioma (RF-22);
  - `missingTranslation`: un texto opcional (subtítulo, nota, descripción o grupo) está escrito en un idioma y vacío en el otro (RF-23);
  - `invalidPrice` (RF-24);
  - `invalidDuration`: solo en servicios y combos (RF-25);
  - `tooLong`, con estos máximos: nombre y subtítulo 80, grupo 40, descripción y nota 600 caracteres.

  Los nombres duplicados se permiten. Un precio de 0 es válido en servicios, adicionales y combos ("R$ 0" / "+R$ 0").

### `lib/features/admin/initial_price_list.dart`: datos de la carga inicial (RF-36, RF-37; la excepción de RF-12)
- `PriceListModel buildInitialPriceList({required AppLocalizations es, required AppLocalizations pt, required int defaultDurationMinutes, required String Function() newId})`.
- Reproduce, en el mismo orden, los 6 bloques y los 3 combos de hoy:
  - Alargamientos: 8 servicios con los grupos "Nueva aplicación" y "Mantenimiento".
  - Soft Gel: "Mantenimiento / reaplicación · desde". Para que se vea igual (RNF-1), se carga con su nombre actual y `priceFrom: false`.
  - Decoración y adicionales: todo `addon`.
  - Nota de Retiradas: pasa a ser la nota de la categoría.
- Las duraciones son las de `defaultDurationMinutes` y las descripciones quedan vacías.
- Los textos se leen de los `.arb` actuales con `lookupAppLocalizations(Locale('es'|'pt'))`. Así no se copian a mano y no pueden diferir de lo que se ve hoy (RNF-1). Los precios en céntimos son los de `LandingContent` hoy. Es el único sitio del código con precios (RF-12).
- No es lógica de negocio sino datos, y depende de `AppLocalizations` (que importa Flutter): por eso vive en `lib/features/admin/` y no en `logic/`.

## 5. Interfaz

### Providers (`lib/features/services/providers/price_list_provider.dart`, nuevo)
- `priceListRepositoryProvider = Provider((ref) => PriceListRepository())`: el único provider de este repositorio. La gestión de la admin lo reutiliza.
- `priceListLoadTimeoutProvider = Provider((_) => const Duration(seconds: 8))`: los tests lo sustituyen por un tiempo corto.
- `priceListStateProvider` (`StreamProvider<PriceListState>`):
  - escucha `watch()` y emite `resolvePriceListState` con cada snapshot;
  - pasado el tiempo límite sin un estado `Ready`, emite con `timedOut: true`;
  - un error del stream se convierte en `Unavailable` y el detalle va a `debugPrint` (RNF-6);
  - "Reintentar" ejecuta `ref.invalidate(priceListStateProvider)` (RF-9).
- `publicPriceListProvider` (`Provider`): `visiblePriceList` de la lista lista para mostrar (RF-1 a RF-4, RF-11).
- `priceDetailProvider` (`Provider.family<DetailState, (DetailKind, String)>`): `Loading` / `Unavailable` / el `findDetail` correspondiente (RF-14, RF-15, RF-17). Como depende de `priceListStateProvider`, se actualiza en vivo (RF-6).
- El idioma: las vistas eligen `BilingualText.of(l10n.localeName)`. Al cambiar de idioma se repintan sin recargar datos (RF-5, RC-1).

### Lista pública (Web y Android/iOS)
- **`PricesSection`** pasa a `ConsumerWidget`. La cabecera (eyebrow, título y nota general, que siguen en los `.arb`) se muestra siempre. Debajo, según el estado:
  - `Loading`: un indicador con la etiqueta "Cargando precios" para el lector de pantalla (RF-7);
  - `Unavailable`: `PriceListUnavailable`, con un texto, "Reintentar" y "Agenda por WhatsApp" (enlace de `externalLinkLauncherProvider`) (RF-8, RF-9);
  - `Ready` vacío: `PriceListEmpty`, con un texto y "Agenda por WhatsApp" (RF-10);
  - `Ready`: tarjetas en filas de 3 en ancho (con un número variable de categorías, la última fila puede quedar incompleta) y una columna en estrecho, con el mismo estilo de hoy (RNF-1).

  En las líneas de la lista:
  - una línea de **servicio** es un `InkWell` de al menos 48 px de alto, con una flecha `Icons.chevron_right` de 16 px en `accentIcon` al final y el resaltado del tema al pasar el ratón o al pulsar (RF-41). Lleva `Semantics(button: true, label: "<nombre>, <precio>")` (RNF-5) y abre el detalle (RF-13);
  - una línea de **adicional** muestra "+R$ …", sin flecha ni acción (RF-2, RF-18);
  - los **grupos** se pintan como hoy.
- **`CombosSection`**: solo con `Ready` y algún combo visible; si no, `SizedBox.shrink()` (RF-11). Mientras carga o si falla, no se muestra: el aviso único va en la lista de precios, y la spec habla de un solo lugar para los dos. Cada combo se puede tocar, con flecha y `Semantics` (RF-13, RF-41, RNF-5).
- **`CatalogSection`**: el texto de RF-42 bajo las páginas, con `inkMuted`.
- **Navegación al detalle:** `context.go('/services/service/<id>')` o `context.go('/services/combo/<id>')`, igual en las dos plataformas (D-7).
  - En Android/iOS es una ruta hija de `/services` dentro de la rama Servicios, así que la barra inferior sigue visible.
  - En Web es una ruta hija de `/`: la landing queda debajo, y "atrás" del navegador vuelve a ella en la misma posición.

### Detalle (`lib/features/services/presentation/price_detail_view.dart`, nuevo; RF-13 a RF-17, RF-43 a RF-47)
- `PriceDetailView(kind, id)` es un `ConsumerWidget` sobre `priceDetailProvider`. Muestra:
  - el nombre de la categoría como eyebrow (solo servicios);
  - el nombre (serif);
  - el precio (`formatPrice`, con "desde" si toca);
  - la duración (`formatDuration`);
  - la descripción, si tiene;
  - la nota de la categoría, si tiene;
  - el botón "Reservar cita" (`landingHeroCtaReserve`), que hace `context.go('/booking')` igual que el hero y Servicios. En Web, sin sesión, `resolveRedirect` lleva al login y después a `/booking`; en Android/iOS cambia a la pestaña Reservas, que muestra su propio aviso si no hay sesión. Una clienta bloqueada o una admin siguen el mismo camino que hoy (RF-16).
- Los estados `Loading` y `Unavailable` usan los mismos widgets que la lista. `NotAvailable` muestra el texto de RF-17 y un botón para volver a la lista de precios.
- **Web** (RF-43, RF-44):
  - la ruta va dentro del `ShellRoute`, envuelta en `WebAccountPage` (barra superior, centrada a 640 px), con un `Stack` que añade `WhatsappFloatButton` en su `FocusTraversalGroup`;
  - el botón "Volver a la lista de precios" y el de `NotAvailable` llaman a `goToLandingSection(context, LandingSection.prices)`. Si se llegó por enlace, la landing no está montada y esa función va a `/?section=prices`;
  - en ancho estrecho, el detalle ocupa el ancho de la ventana con un margen de 24 px.
- **Android/iOS:** sin botón "Volver" propio: tiene el `AppBar` con la flecha atrás del sistema. `NotAvailable` lleva a `context.go('/services')`.
- **Rutas** (`app_router.dart`):
  - Web: ruta hija `services/:kind/:id` de `GoRoute('/')` dentro del `ShellRoute` (D-7). `resolveRedirect` solo redirige `/services` exacto, así que estas rutas son públicas sin cambios. Se añade un test de la tabla.
  - Android/iOS: rutas hijas `service/:id` y `combo/:id` de `GoRoute('/services')` en la rama Servicios.

### Barra inferior (RF-45 a RF-47)
- Nueva función pura `TabTapAction tabTapAction({required bool isActive, required bool isAtBranchRoot})` en `lib/features/navigation/tab_tap_logic.dart`. Devuelve:
  - `switchTab` si la pestaña no está activa;
  - `popToRoot` si está activa con un detalle abierto: `goBranch(index, initialLocation: true)` sin mover el scroll, de modo que la lista sigue donde estaba (RF-45);
  - `scrollToTop` si está activa en su raíz (comportamiento de la spec 003, RF-4).
- `MainScaffold._onSelected` sabe si está en la raíz comparando la ruta actual de la rama (`GoRouterState.of(context).uri.path`) con la raíz de la pestaña.
- RF-46 y RF-47: ya se cumplen (§ 1); solo se añaden tests.

### Gestión de servicios (admin; RF-19 a RF-39)
- **Entrada (RF-19):** `IconButton` "Servicios" (`Icons.spa_outlined`, con tooltip y 48 px) en la cabecera de `AdminDashboardView`, junto a Usuarias y Ajustes, que hace `context.push('/admin/services')`.
- **Rutas:** `/admin/services`, `/admin/services/category/:id`, `/admin/services/category/:categoryId/item/:id?kind=service|addon` y `/admin/services/combo/:id`. El id `new` sirve para crear. En Web van con `WebAccountPage` y la guarda `/admin…` que ya existe; en Android/iOS son rutas de primer nivel, como el resto del panel. `safeNext` acepta `/admin/services`.
- **`AdminServicesView`** (`lib/features/admin/presentation/admin_services_view.dart`):
  - Usa `priceListStateProvider`, sin filtrar.
  - `Ready` sin documento: un texto y el botón "Cargar la lista de precios actual" (RF-35). El botón pide confirmación (RF-36); al confirmar, el controlador ejecuta `seed`. Si ya hay datos, el botón no aparece (RF-38).
  - Con datos: la lista de categorías y, dentro de cada una, sus servicios y adicionales, con su precio. Los elementos ocultos llevan la etiqueta "Oculto" (RF-20).
  - Cada elemento tiene sus acciones como `IconButton` con tooltip: editar, subir, bajar, ocultar o mostrar, y borrar.
  - Cada categoría tiene "Añadir servicio" y "Añadir adicional". Al final están "Añadir categoría" y la sección Combos, con "Añadir combo".
  - `Unavailable`: el mismo aviso con "Reintentar".
- **Formularios** (`admin_category_form_view.dart`, `admin_price_item_form_view.dart`, `admin_combo_form_view.dart`; RF-21 a RF-25):
  - Cada texto bilingüe son dos `TextField`, "… en español" y "… en portugués".
  - El precio se escribe con teclado decimal y la duración con teclado numérico; el formulario del servicio tiene además la casilla "Precio «desde»" y un desplegable de categoría.
  - El formulario de adicional no tiene descripción, grupo, duración ni "desde".
  - "Guardar" valida con las funciones de § 4 y marca cada campo con su error.
  - Al guardar bien, aviso breve (`SnackBar`, que el lector de pantalla anuncia) y vuelta a la gestión (RF-34).
  - Si falla, el formulario se queda con lo escrito y sale un `SnackBar` de error con la acción "Reintentar" (RF-33).
  - "Cancelar" o "atrás" vuelven sin guardar. La spec no pide confirmar antes de descartar lo escrito, así que no se pide.
- **Confirmaciones** (RF-29 a RF-31): `AlertDialog` con el nombre del elemento en el idioma activo. Los textos se leen dentro del `builder`, como manda `CLAUDE.md`. Si la categoría tiene elementos, sale un diálogo informativo, sin opción de borrar.
- **Errores de mover, ocultar o borrar** (RF-33, punto 14 de la revisión QA): `SnackBar` de error con "Reintentar". `ItemGone` muestra "Este elemento ya no existe". Sin conexión, la transacción falla y sale ese mismo aviso.
- **Controlador** (`lib/features/admin/providers/admin_services_provider.dart`): `AdminServicesController(PriceListRepository, ConfigRepository)` expuesto como `adminServicesControllerProvider`; reutiliza `priceListRepositoryProvider` y `configRepositoryProvider`.
  - Cada método llama a `repository.update((list) => <función pura de § 4>)`.
  - `seedInitialList(es, pt)` lee la duración global con `configRepository.getCalendarSettings().first` (60 si falla) y llama a `repository.seed(buildInitialPriceList(...))`.
  - Devuelve un resultado tipado: `ok`, `failed` o `itemGone`, nunca el error en crudo (RNF-6).

### Limpieza (RF-12)
- Se borran `priceCards`, `combos` y los tipos `PriceCard`, `PriceLine`, `PriceItem`, `PriceGroup` y `Combo` de `LandingContent`.
- Las claves `landingServices1…6*` y `landingCombo1…3*` **se quedan** en los `.arb`, porque las usa `buildInitialPriceList`. Se comentan en el `.arb` con `@` + `description`: "Solo para la carga inicial (spec 004)".
- `landingSoftGelTitle` sigue usándose en `MarqueeStrip`.
- `test/core/legacy_cleanup_test.dart` gana una comprobación: ningún archivo de `lib/` salvo `initial_price_list.dart` contiene `R$` seguido de un número.

## 6. Textos nuevos en los `.arb` (ES / PT; RNF-3, RC-1)

| Clave | ES | PT |
| --- | --- | --- |
| `pricesLoading` | Cargando precios | Carregando preços |
| `pricesLoadError` | No se pudieron cargar los precios. | Não foi possível carregar os preços. |
| `pricesRetry` | Reintentar | Tentar novamente |
| `pricesEmpty` | Consulta los precios por WhatsApp. | Consulte os preços pelo WhatsApp. |
| `priceFrom` (`{price}`) | desde {price} | a partir de {price} |
| `pricesCatalogDisclaimer` | Los precios vigentes son los de la lista de precios. | Os preços vigentes são os da lista de preços. |
| `priceDetailDuration` | Duración | Duração |
| `priceDetailBackToPrices` | Volver a la lista de precios | Voltar à lista de preços |
| `priceDetailUnavailable` | Este servicio ya no está disponible. | Este serviço não está mais disponível. |
| `priceDetailOpenHint` | Ver detalle | Ver detalhes |
| `adminServicesTitle` | Servicios | Serviços |
| `adminServicesSeed` | Cargar la lista de precios actual | Carregar a lista de preços atual |
| `adminServicesSeedConfirmTitle` | ¿Cargar la lista de precios actual? | Carregar a lista de preços atual? |
| `adminServicesSeedConfirmBody` | Se crearán las categorías, servicios y combos de hoy. Después podrás editarlos. | Serão criadas as categorias, serviços e combos de hoje. Depois você poderá editá-los. |
| `adminServicesEmpty` | Todavía no hay servicios. | Ainda não há serviços. |
| `adminServicesCombos` | Combos | Combos |
| `adminServicesHidden` | Oculto | Oculto |
| `adminServicesAddCategory` / `AddService` / `AddAddon` / `AddCombo` | Añadir categoría / servicio / adicional / combo | Adicionar categoria / serviço / adicional / combo |
| `adminServicesEdit` / `MoveUp` / `MoveDown` / `Hide` / `Show` / `Delete` | Editar / Subir / Bajar / Ocultar / Mostrar / Borrar | Editar / Subir / Descer / Ocultar / Mostrar / Excluir |
| `adminServicesDeleteTitle` (`{name}`) | ¿Borrar «{name}»? | Excluir «{name}»? |
| `adminServicesDeleteBody` | No se puede deshacer. | Não é possível desfazer. |
| `adminServicesCategoryNotEmpty` | Esta categoría tiene servicios o adicionales. Bórralos o muévelos a otra categoría antes de borrarla. | Esta categoria tem serviços ou adicionais. Exclua-os ou mova-os para outra categoria antes de excluí-la. |
| `adminServicesSaved` | Cambios guardados | Alterações salvas |
| `adminServicesSaveError` | No se pudieron guardar los cambios. | Não foi possível salvar as alterações. |
| `adminServicesItemGone` | Este elemento ya no existe. | Este item não existe mais. |
| `adminServicesNew…` / `adminServicesEdit…` (títulos de los 4 formularios) | Nueva categoría, Editar servicio… | Nova categoria, Editar serviço… |
| `adminFieldNameEs` / `adminFieldNamePt` (y lo mismo para subtítulo, nota, descripción y grupo) | Nombre en español / Nombre en portugués | Nome em espanhol / Nome em português |
| `adminFieldPrice` | Precio (R$) | Preço (R$) |
| `adminFieldPriceFrom` | Precio «desde» | Preço «a partir de» |
| `adminFieldDuration` | Duración (minutos) | Duração (minutos) |
| `adminFieldCategory` | Categoría | Categoria |
| `adminFieldRequired` | Obligatorio | Obrigatório |
| `adminFieldMissingTranslation` | Escríbelo también en este idioma | Escreva também neste idioma |
| `adminFieldInvalidPrice` | Precio no válido (hasta 2 decimales) | Preço inválido (até 2 casas decimais) |
| `adminFieldInvalidDuration` | Entre 5 y 480 minutos | Entre 5 e 480 minutos |
| `adminFieldTooLong` (`{max}`) | Máximo {max} caracteres | Máximo {max} caracteres |
| `adminSave` | GUARDAR | SALVAR |

Se reutilizan `cancelAction`, `landingHeroCtaReserve` y `landingContactCtaWhatsapp`. Después de editar los `.arb` se ejecuta `flutter gen-l10n`.

## 7. Decisiones técnicas

| # | Decisión | Alternativa descartada y por qué |
| --- | --- | --- |
| D-1 | Toda la lista en **un documento** (`settings/priceList`) | Una colección por tipo (`categories`, `services`, `combos`): la carga inicial y el reordenado serían escrituras en lote de muchos documentos, y RF-38 ("aunque se pida dos veces") no se puede garantizar en el cliente, porque una transacción no puede comprobar que una colección está vacía. Un documento da carga atómica, una sola lectura y una sola escucha. El límite de 1 MB queda muy lejos (unos 30 KB). |
| D-2 | Precio en **céntimos enteros** | `double`: redondeos (0,1 + 0,2) y una validación de decimales poco fiable. |
| D-3 | Cambios de la admin en **transacción** con funciones puras | `set` del documento entero: dos admins se pisarían cambios de elementos distintos. |
| D-4 | "No hay datos" (`fromCache` sin documento) espera **8 s** antes de dar error | Error inmediato: al abrir con conexión, la caché vacía responde antes que el servidor y saldría un aviso falso de un instante. |
| D-5 | Un **solo aviso** de carga o error en la lista de precios; los combos no se muestran mientras tanto | Un aviso por sección: dos "Reintentar" seguidos, para un solo origen de datos. |
| D-6 | Carga inicial a partir de los **`.arb` actuales** (`lookupAppLocalizations`) | Copiar los textos a mano en Dart: riesgo de diferencias con lo de hoy (RNF-1) y textos duplicados. |
| D-7 | El detalle es una **ruta hija** (de `/` en Web y de `/services` en Android/iOS) y se abre con **`go`**. La página de debajo sigue montada: "atrás" vuelve a ella en la misma posición, y la dirección del navegador es la del detalle. *Cambiado el 2026-10-22 en T7, con la aprobación del autor.* | `push`: en Web no cambia la dirección del navegador (go_router solo la refleja con la opción global `optionURLReflectsImperativeAPIs`, que desaconseja), y la spec pide una dirección propia que se pueda compartir. `go` a una ruta suelta: perdería la posición de la landing. |
| D-8 | Mismas rutas de detalle en las dos plataformas (`/services/service/:id`, `/services/combo/:id`) | Rutas distintas por plataforma: más casos en `resolveRedirect` y en los enlaces compartidos. |
| D-9 | Sin vista previa de elementos ocultos | La spec no la pide. La admin ve los ocultos en la gestión, no en el detalle público. |
| D-10 | Caché persistente de Firestore en **Web** | Sin ella, RF-40 no se cumpliría en Web al volver a abrir la página sin conexión. |

## 8. Decisiones del autor

- **A-1. Reglas comprobadas a mano** (decidido por el autor el 2026-10-22). No se añaden herramientas de Node ni el emulador. Las reglas se comprueban en el simulador de reglas de la consola (Rules Playground) con los pasos de § 9. El criterio de finalización de la spec se cambió en consecuencia.
- **A-2. Reglas actuales sin tocar** (respuesta del autor). El archivo lleva una regla provisional para el resto de colecciones (§ 2). El autor mira la consola y guarda una copia antes de desplegar.
- **A-3. Nueva colección o documento:** `settings/priceList`, con el esquema de § 2 (`CLAUDE.md`: "preguntar antes de cambiar colecciones o campos"). Se aprueba con este plan.

## 9. Estrategia de tests

Ningún test usa Firebase:
- `FakePriceListRepository` (`test/helpers/fake_price_list.dart`, escrito a mano y heredando del real con un `FirebaseFirestore` nunca usado, como `FakeAuthRepository`) tiene:
  - un `StreamController<PriceListSnapshot>` para emitir datos, datos de caché, documento inexistente o error;
  - `update` y `seed`, que aplican la función a una lista en memoria y lo registran;
  - un interruptor `failNext` para simular fallos y `ItemGone`.
- `testPriceList()` construye una lista pequeña: 2 categorías, una con grupo y un adicional, una oculta y un combo oculto.

| RF / RNF | Test | Tipo |
| --- | --- | --- |
| Modelo y lectura tolerante (principio 5) | `test/data/models/price_list_model_test.dart`: `fromMap`/`toMap` de ida y vuelta, campos que faltan, respaldo de idioma, elementos inválidos omitidos, campos desconocidos conservados | unitario |
| RF-7, RF-8, RF-10, RF-40 | `price_list_view_logic_test.dart`: tabla de `resolvePriceListState` | unitario |
| RF-1, RF-3, RF-4, RF-11, RF-28, numeración, grupos | `price_list_view_logic_test.dart`: `visiblePriceList` | unitario |
| RF-14, RF-15, RF-17, RF-18 | `price_list_view_logic_test.dart`: `findDetail` (oculto, categoría oculta, borrado, adicional, combo) | unitario |
| Formato del precio y la duración | `price_list_view_logic_test.dart` | unitario |
| RF-26, RF-27, RF-29 a RF-32 | `price_list_edit_logic_test.dart` | unitario |
| RF-22 a RF-25 | `price_list_form_logic_test.dart`: `parsePriceCents`, `parseDuration` y los validadores | unitario |
| RF-36, RF-37, RNF-1 (datos) | `initial_price_list_test.dart`: 6 categorías, 3 combos, textos ES/PT iguales a los de los `.arb`, precios de hoy, duración por defecto, descripciones vacías | unitario |
| RF-45 | `tab_tap_logic_test.dart` | unitario |
| Rutas de detalle públicas, `/admin/services` | `test/core/router/redirect_logic_test.dart` (casos nuevos) | unitario |
| RF-1, RF-2, RF-5, RF-6, RF-41, RNF-5 | `test/features/services/prices_section_test.dart`: pinta la lista con el fake, cambia de idioma, emite un cambio y se ve sin recargar, flecha solo en servicios, semántica de botón | widget |
| RF-7 a RF-11 | `prices_section_states_test.dart`: carga, error con "Reintentar" (vuelve a escuchar), vacío con WhatsApp (`RecordingLinkLauncher`), sin combos y caché sin conexión | widget |
| RF-42 | `landing_combos_catalog_info_test.dart` (ampliado) | widget |
| RF-13 a RF-17, RF-43, RF-44 (Web) | `test/features/services/price_detail_web_test.dart` con `pumpWebApp`: abrir desde la lista, abrir por dirección sin sesión, "Volver a la lista de precios", WhatsApp flotante, "Reservar cita" sin sesión → login, elemento borrado mientras está abierto, ancho de 600 y de 1280 px | widget |
| RF-13 a RF-17, RF-45 a RF-47 (Android/iOS) | `price_detail_mobile_test.dart` con `pumpMobileApp`: la barra sigue visible, tocar Servicios cierra el detalle y mantiene la posición y un segundo toque sube al comienzo, "Ver lista de precios" desde Inicio, cambiar de pestaña y volver | widget |
| RF-19 a RF-34 | `test/features/admin/admin_services_test.dart`: entrada en la cabecera, ocultos marcados, formularios con errores por campo, mover, ocultar, confirmación de borrado, categoría con elementos, fallo con "Reintentar", `SnackBar` de guardado | widget |
| RF-35, RF-36, RF-38, RF-39 | `admin_services_seed_test.dart`: el botón solo sin documento, confirmación, `AlreadySeeded` y fallo sin datos parciales | widget |
| RNF-2 | **Manual, en el Rules Playground de la consola** (A-1), con estos casos: (1) `get` de `settings/priceList` sin autenticar → permitido; (2) `update` sin autenticar → denegado; (3) `update` autenticado con el uid de una clienta (`role: 'cliente'`) → denegado; (4) `update` y `create` con el uid de la admin → permitido; (5) `delete` con la admin → denegado; (6) `get` de `users/<uid>` autenticado → permitido y sin autenticar → denegado (regla provisional). Además, tras desplegar, la app sigue funcionando: inicio de sesión, reserva y panel de la admin | manual |
| RNF-3, RC-1 | `app_locale_test.dart` (ampliado): las claves nuevas existen en ES y PT | unitario |
| RNF-4 | `screens_theme_test.dart` y `mobile_accessibility_test.dart` (ampliados): contraste en claro y oscuro con `textContrastGuideline`, `androidTapTargetGuideline`, y escala de texto 2,0 sin desbordes en la lista, el detalle y la gestión | widget |
| RNF-6 | Tests de estados: con un error del fake, el texto en pantalla no contiene el mensaje de la excepción | widget |
| RF-12 | `legacy_cleanup_test.dart` (ampliado) | unitario |
| Estilo | `no_hardcoded_style_test.dart` ya cubre los archivos nuevos de `lib/features` | unitario |

Los tests de la landing y de Servicios que hoy leen los datos fijos (`landing_hero_prices_test.dart`, `mobile_services_test.dart`, `landing_combos_catalog_info_test.dart`) pasan a montar la app con `FakePriceListRepository` y la lista inicial. `pumpWebApp` y `pumpMobileApp` aceptan un `priceList` opcional, que por defecto es la lista inicial, para no tocar cada test.

## 10. Cobertura

- **RF-1 a RF-47 y RNF-1 a RNF-6:** cubiertos en § 4, § 5 y § 9.
- **RC-1:** textos de la base de datos en ES y PT y textos nuevos de la interfaz en los `.arb`.
- **RC-2:** todo usa `context.brand`; el contraste se prueba en los dos temas.
- **RC-3:** el idioma activo elige el texto bilingüe.
- **RC-4:** las mismas funciones en las dos plataformas, con su navegación propia (§ 5).
- **Constitución:**
  - principio 1: sin dependencias nuevas;
  - principio 3: lógica pura en § 4 y solo `lib/data/` toca Firebase;
  - principio 4: tests primero y sin Firebase real;
  - principio 5: reglas en `firestore.rules`, confirmación antes de borrar y lectura tolerante;
  - principio 6 (precisado): el contenido de la admin va en la base de datos, en ES y PT, y la interfaz en los `.arb`.
- **Fuera de este plan** (spec 010): una dirección propia sin `#` para Web y la vista previa del enlace compartido.
