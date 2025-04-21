import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smart_routes_app/src/pages/profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  List<LatLng> _stops = [];
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  final Color mainButtonColor = const Color(0xFF64B5F6); // Azul claro bonito
  final Color secondaryButtonColor = const Color(0xFF90CAF9); // Azul ainda mais clarinho

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });
  }

  Future<void> _navigateToAddStops() async {
    final result = await Navigator.pushNamed(context, '/addStops');
    if (result != null && result is List<Map<String, dynamic>>) {
      List<LatLng> loadedStops = result
          .map((stop) => LatLng(stop['latitude'] as double, stop['longitude'] as double))
          .toList();
      setState(() {
        _stops = loadedStops;
      });
      _drawMarkers();
      _drawRoute();
    }
  }

  void _drawMarkers() {
    Set<Marker> newMarkers = {};

    for (int i = 0; i < _stops.length; i++) {
      newMarkers.add(
        Marker(
          markerId: MarkerId('stop_$i'),
          position: _stops[i],
          infoWindow: InfoWindow(title: '${i + 1} - Parada'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    }

    if (_currentPosition != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentPosition!,
          infoWindow: const InfoWindow(title: 'Você está aqui'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }

    setState(() {
      _markers = newMarkers;
    });
  }

  void _drawRoute() {
    if (_currentPosition == null || _stops.isEmpty) return;

    List<LatLng> fullPath = [_currentPosition!, ..._stops];

    final polyline = Polyline(
      polylineId: const PolylineId('route'),
      color: mainButtonColor,
      width: 5,
      points: fullPath,
    );

    setState(() {
      _polylines = {polyline};
    });
  }

  Future<void> _startNavigation() async {
    if (_currentPosition == null || _stops.isEmpty) return;

    String origin = '${_currentPosition!.latitude},${_currentPosition!.longitude}';
    String destination = '${_stops.last.latitude},${_stops.last.longitude}';

    String waypoints = '';
    if (_stops.length > 1) {
      waypoints = _stops.sublist(0, _stops.length - 1)
          .map((stop) => '${stop.latitude},${stop.longitude}')
          .join('|');
    }

    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination&waypoints=$waypoints&travelmode=driving',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível iniciar o Google Maps.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NextStop')),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Builder(
              builder: (context) {
                final user = FirebaseAuth.instance.currentUser;

                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  alignment: Alignment.center,
                  color: mainButtonColor,
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white,
                        backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                        child: user?.photoURL == null
                            ? const Icon(Icons.person, size: 40, color: Colors.blue)
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user?.displayName ?? 'Usuário',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      ),
                      Text(
                        user?.email ?? '',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Perfil'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sair'),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              },
            ),
          ],
        ),
      ),
      body: _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition!,
                    zoom: 14,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                ),
                Positioned(
                  bottom: 150,
                  left: 20,
                  right: 20,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _navigateToAddStops,
                        icon: const Icon(Icons.add_location_alt),
                        label: const Text('Adicionar Parada'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF64B5F6), // Azul claro
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 40),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 6,
                          shadowColor: Colors.black45,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_stops.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: _startNavigation,
                          icon: const Icon(Icons.navigation),
                          label: const Text('Iniciar Navegação'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E88E5), // Um azul um pouco mais forte para diferenciar
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 40),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 6,
                            shadowColor: Colors.black45,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
