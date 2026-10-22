import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/brand_colors.dart';

/// Mapa del salón que muestra la app. Los tests lo sustituyen: la vista
/// nativa de Google Maps no se pinta en ellos.
final salonMapProvider = Provider<Widget>((ref) => const GoogleMapContainer());

/// Mapa del salón. El mapa en sí es una *excepción de color* de la spec 001:
/// se ve claro también en el tema oscuro. Solo su borde sigue el tema.
class GoogleMapContainer extends StatelessWidget {
  const GoogleMapContainer({super.key});

  /// Alto fijo: el mapa va dentro del scroll del contacto de Inicio
  /// (spec 003, D-7).
  static const height = 220.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: context.brand.hairlineStrong, width: 1),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(10),
          bottomRight: Radius.circular(10),
          topLeft: Radius.circular(10),
        ),
      ),
      child: GoogleMap(
        key: ValueKey('google_map_widget'),
        initialCameraPosition: CameraPosition(
          target: LatLng(-25.4380063, -49.219404),
          zoom: 16,
        ),
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        mapType: MapType.normal,
        markers: {
          Marker(
            markerId: const MarkerId('selected'),
            position: LatLng(-25.4380063, -49.219404),
            icon: BitmapDescriptor.defaultMarker,
            consumeTapEvents: true,
          ),
        },
      ),
    );
  }
}
