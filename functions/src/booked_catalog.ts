// Lo reservado contra la lista de precios vigente (spec 012, RF-11 a RF-13;
// plan D-5).
//
// Traducción de `PriceListModel.fromMap`, `BookedServiceModel.fromMap` y
// `bookable_catalog.dart` (`bookableCatalog`, `findBookable`,
// `availableAddons`, `snapshotOf`) de la app. El servidor construye la copia
// de lo reservado desde la lista y la compara con la que mostraba la app:
// así se guarda siempre la de la lista, y si no coincide se avisa en lugar de
// guardar un precio que la clienta no vio. Sin Firebase.

export interface Bilingual {
  es: string;
  pt: string;
}

export interface PriceItem {
  id: string;
  kind: 'service' | 'addon';
  name: Bilingual;
  priceCents: number;
  priceFrom: boolean;
  durationMinutes: number;
  visible: boolean;
}

export interface PriceCategory {
  id: string;
  visible: boolean;
  items: PriceItem[];
}

export interface Combo {
  id: string;
  name: Bilingual;
  priceCents: number;
  durationMinutes: number;
  visible: boolean;
}

export interface PriceList {
  categories: PriceCategory[];
  combos: Combo[];
}

export interface BookedAddon {
  id: string;
  name: Bilingual;
  priceCents: number;
}

/** La copia de lo reservado que se guarda en el turno (`BookedServiceModel.toMap`). */
export interface Booked {
  kind: 'service' | 'combo';
  id: string;
  name: Bilingual;
  priceCents: number;
  priceFrom: boolean;
  durationMinutes: number;
  addons: BookedAddon[];
}

/** Un servicio o combo de la lista. */
export interface BookableRef {
  kind: 'service' | 'combo';
  id: string;
}

export type BookedCheck =
  | { ok: true; booked: Booked }
  | { ok: false; reason: 'item_unavailable' | 'item_changed' };

const DEFAULT_DURATION_MINUTES = 60;

type Data = Record<string, unknown>;

const isRecord = (value: unknown): value is Data =>
  typeof value === 'object' && value !== null && !Array.isArray(value);

const isWhole = (value: unknown): value is number =>
  typeof value === 'number' && Number.isInteger(value);

/** `BilingualText.fromMap`: lo que no es texto, vacío. */
function readBilingual(value: unknown): Bilingual {
  if (!isRecord(value)) return { es: '', pt: '' };
  return {
    es: typeof value.es === 'string' ? value.es : '',
    pt: typeof value.pt === 'string' ? value.pt : '',
  };
}

const isEmptyName = (name: Bilingual) =>
  name.es.trim() === '' && name.pt.trim() === '';

/** Un entero ≥ 0 (`_readPriceCents`), o `null`. */
const readCents = (value: unknown): number | null =>
  isWhole(value) && value >= 0 ? value : null;

/** Un entero > 0, o 60 (`_readDuration`). */
const readDuration = (value: unknown): number =>
  isWhole(value) && value > 0 ? value : DEFAULT_DURATION_MINUTES;

const readId = (value: unknown): string | null =>
  typeof value === 'string' && value.length > 0 ? value : null;

function readItem(data: unknown): PriceItem | null {
  if (!isRecord(data)) return null;
  const id = readId(data.id);
  const name = readBilingual(data.name);
  const priceCents = readCents(data.priceCents);
  if (id === null || isEmptyName(name) || priceCents === null) return null;
  return {
    id,
    kind: data.kind === 'addon' ? 'addon' : 'service',
    name,
    priceCents,
    priceFrom: data.priceFrom === true,
    durationMinutes: readDuration(data.durationMinutes),
    visible: data.visible !== false,
  };
}

function readCategory(data: unknown): PriceCategory | null {
  if (!isRecord(data)) return null;
  const id = readId(data.id);
  if (id === null || isEmptyName(readBilingual(data.name))) return null;
  const items = Array.isArray(data.items) ? data.items : [];
  return {
    id,
    visible: data.visible !== false,
    items: items.map(readItem).filter((item): item is PriceItem => item !== null),
  };
}

function readCombo(data: unknown): Combo | null {
  if (!isRecord(data)) return null;
  const id = readId(data.id);
  const name = readBilingual(data.name);
  const priceCents = readCents(data.priceCents);
  if (id === null || isEmptyName(name) || priceCents === null) return null;
  return {
    id,
    name,
    priceCents,
    durationMinutes: readDuration(data.durationMinutes),
    visible: data.visible !== false,
  };
}

/** `settings/priceList` como lo lee la app: las líneas no válidas se omiten. */
export function readPriceList(data: unknown): PriceList {
  const d = isRecord(data) ? data : {};
  const categories = Array.isArray(d.categories) ? d.categories : [];
  const combos = Array.isArray(d.combos) ? d.combos : [];
  return {
    categories: categories
      .map(readCategory)
      .filter((c): c is PriceCategory => c !== null),
    combos: combos.map(readCombo).filter((c): c is Combo => c !== null),
  };
}

/** La copia guardada en un turno, como `BookedServiceModel.fromMap`; `null` sin nombre. */
export function readBooked(data: unknown): Booked | null {
  if (!isRecord(data)) return null;
  const name = readBilingual(data.name);
  if (isEmptyName(name)) return null;
  const rawAddons = Array.isArray(data.addons) ? data.addons : [];
  const addons: BookedAddon[] = [];
  for (const raw of rawAddons) {
    if (!isRecord(raw)) continue;
    const addonName = readBilingual(raw.name);
    const cents = readCents(raw.priceCents);
    if (isEmptyName(addonName) || cents === null) continue;
    addons.push({
      id: typeof raw.id === 'string' ? raw.id : '',
      name: addonName,
      priceCents: cents,
    });
  }
  return {
    kind: data.kind === 'combo' ? 'combo' : 'service',
    id: typeof data.id === 'string' ? data.id : '',
    name,
    priceCents: readCents(data.priceCents) ?? 0,
    priceFrom: data.priceFrom === true,
    durationMinutes: readDuration(data.durationMinutes),
    addons,
  };
}

/** Un servicio de una categoría visible, o un combo visible. */
type Bookable =
  | { kind: 'service'; item: PriceItem; category: PriceCategory }
  | { kind: 'combo'; combo: Combo };

/** `findBookable` sobre `bookableCatalog`: lo que se ofrece en la reserva. */
function findBookable(list: PriceList, ref: BookableRef): Bookable | null {
  if (ref.kind === 'combo') {
    const combo = list.combos.find((c) => c.visible && c.id === ref.id);
    return combo === undefined ? null : { kind: 'combo', combo };
  }
  for (const category of list.categories) {
    if (!category.visible) continue;
    const services = category.items.filter((i) => i.visible && i.kind === 'service');
    const item = services.find((i) => i.id === ref.id);
    if (item !== undefined) return { kind: 'service', item, category };
  }
  return null;
}

/** Los adicionales visibles de la categoría del servicio; un combo, ninguno. */
function availableAddons(bookable: Bookable): PriceItem[] {
  if (bookable.kind === 'combo') return [];
  return bookable.category.items.filter((i) => i.visible && i.kind === 'addon');
}

/** `snapshotOf`: la copia que guarda el turno. */
function snapshotOf(bookable: Bookable, addons: PriceItem[]): Booked {
  const base =
    bookable.kind === 'combo'
      ? {
          kind: 'combo' as const,
          id: bookable.combo.id,
          name: bookable.combo.name,
          priceCents: bookable.combo.priceCents,
          priceFrom: false,
          durationMinutes: bookable.combo.durationMinutes,
        }
      : {
          kind: 'service' as const,
          id: bookable.item.id,
          name: bookable.item.name,
          priceCents: bookable.item.priceCents,
          priceFrom: bookable.item.priceFrom,
          durationMinutes: bookable.item.durationMinutes,
        };
  return {
    ...base,
    addons: addons.map((a) => ({ id: a.id, name: a.name, priceCents: a.priceCents })),
  };
}

/**
 * Lo reservado ([ref] con [addonIds]) contra la lista vigente (RF-11,
 * RF-12): `item_unavailable` si el servicio, el combo o un adicional ya no
 * se ofrece (un combo no lleva adicionales); `item_changed` si la copia que
 * mostraba la app ([sent]) no es la de la lista. Si todo coincide, la copia
 * construida desde la lista, con los adicionales en su orden.
 */
export function checkBooked(
  list: PriceList,
  ref: BookableRef,
  addonIds: string[],
  sent: unknown,
): BookedCheck {
  const bookable = findBookable(list, ref);
  if (bookable === null) return { ok: false, reason: 'item_unavailable' };
  const available = availableAddons(bookable);
  const chosen = new Set(addonIds);
  for (const id of chosen) {
    if (!available.some((a) => a.id === id)) {
      return { ok: false, reason: 'item_unavailable' };
    }
  }
  const booked = snapshotOf(
    bookable,
    available.filter((a) => chosen.has(a.id)),
  );
  const shown = readBooked(sent);
  if (shown === null || bookedKey(shown) !== bookedKey(booked)) {
    return { ok: false, reason: 'item_changed' };
  }
  return { ok: true, booked };
}

/** JSON con las claves ordenadas: el mismo para la misma copia (RF-13). */
export function bookedKey(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(bookedKey).join(',')}]`;
  if (isRecord(value)) {
    return `{${Object.keys(value)
      .sort()
      .map((key) => `${JSON.stringify(key)}:${bookedKey(value[key])}`)
      .join(',')}}`;
  }
  return JSON.stringify(value ?? null);
}
