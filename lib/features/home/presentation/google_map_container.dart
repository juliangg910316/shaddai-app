import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GoogleMapContainer extends StatelessWidget {
  const GoogleMapContainer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      height: MediaQuery.of(context).size.height * 0.25,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey, width: 1),
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
