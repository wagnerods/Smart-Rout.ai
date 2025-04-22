import 'dart:io';
import 'dart:ui' as ui;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_routes_app/src/pages/profile_page.dart';
import 'package:smart_routes_app/src/services/rota_fatiada_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  List<Map<String, dynamic>> _stops = [];
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  final Color mainButtonColor = const Color(0xFF64B5F6);
  File? _localImage;
  double _startNavButtonOpacity = 1.0;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('profile_image_path');
    if (imagePath != null) {
      final file = File(imagePath);
      if (await file.exists()) {
        setState(() => _localImage = file);
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) await Geolocator.openLocationSettings();

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() => _currentPosition = LatLng(position.latitude, position.longitude));
  }

  Future<void> _navigateToAddStops() async {
    final result = await Navigator.pushNamed(
      context,
      '/addStops',
      arguments: _stops.map((stop) => {
        'cep': stop['cep'] ?? '',
        'endereco': stop['endereco'] ?? '',
        'latitude': stop['latitude'],
        'longitude': stop['longitude'],
      }).toList(),
    );

    if (result != null && result is List) {
      List<Map<String, dynamic>> loadedStops = [];
      for (var item in result) {
        if (item is Map<String, dynamic> && item.containsKey('latitude') && item.containsKey('longitude')) {
          loadedStops.add({
            'cep': item['cep'] ?? '',
            'endereco': item['endereco'] ?? '',
            'latitude': item['latitude'],
            'longitude': item['longitude'],
          });
        }
      }
      setState(() => _stops = loadedStops);
      await _drawMarkers();
      _drawRoute();
    }
  }

  Future<BitmapDescriptor> _createCustomMarker(int number) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = Colors.blueAccent;
    const size = 100.0;

    canvas.drawCircle(const Offset(size/2, size/2), size/2, paint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: number.toString(),
        style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2));

    final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  Future<void> _drawMarkers() async {
    Set<Marker> newMarkers = {};

    for (int i = 0; i < _stops.length; i++) {
      final markerIcon = await _createCustomMarker(i + 1);
      newMarkers.add(Marker(
        markerId: MarkerId('stop_$i'),
        position: LatLng(_stops[i]['latitude'], _stops[i]['longitude']),
        infoWindow: InfoWindow(title: '${i + 1} - Parada'),
        icon: markerIcon,
      ));
    }

    if (_currentPosition != null) {
      newMarkers.add(Marker(
        markerId: const MarkerId('current_location'),
        position: _currentPosition!,
        infoWindow: const InfoWindow(title: 'Você está aqui'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
    }

    setState(() => _markers = newMarkers);
  }

  void _drawRoute() {
    if (_currentPosition == null || _stops.isEmpty) return;

    List<LatLng> fullPath = [
      _currentPosition!,
      ..._stops.map((stop) => LatLng(stop['latitude'], stop['longitude'])),
    ];

    final polyline = Polyline(
      polylineId: const PolylineId('route'),
      color: mainButtonColor,
      width: 5,
      points: fullPath,
    );

    setState(() => _polylines = {polyline});
  }

  void _clearRoute() async {
    setState(() => _startNavButtonOpacity = 0.0);
    await Future.delayed(const Duration(milliseconds: 400));
    setState(() {
      _stops.clear();
      _markers.clear();
      _polylines.clear();
      _startNavButtonOpacity = 1.0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rota limpa!'), backgroundColor: Colors.redAccent),
    );
  }

  void _startNavigation() {
    if (_currentPosition == null || _stops.isEmpty) return;

    final origem = {
      'latitude': _currentPosition!.latitude,
      'longitude': _currentPosition!.longitude,
    };

    final paradas = List<Map<String, double>>.from(
      _stops.map((stop) => {
        'latitude': stop['latitude'],
        'longitude': stop['longitude'],
      }),
    );

    RotaFatiadaService.iniciarNavegacaoFatiada(
      context: context,
      origem: origem,
      paradas: paradas,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('NextStop')),
      drawer: _buildDrawer(user),
      body: _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(target: _currentPosition!, zoom: 14),
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  onMapCreated: (controller) => _mapController = controller,
                ),
                _buildBottomControls(),
              ],
            ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 150,
      left: 20,
      right: 20,
      child: Column(
        children: [
          ElevatedButton.icon(
            onPressed: _navigateToAddStops,
            icon: const Icon(Icons.add_location_alt),
            label: Text('Adicionar Parada (${_stops.length})'),
            style: ElevatedButton.styleFrom(
              backgroundColor: mainButtonColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 6,
            ),
          ),
          const SizedBox(height: 12),
          if (_stops.isNotEmpty)
            AnimatedOpacity(
              opacity: _startNavButtonOpacity,
              duration: const Duration(milliseconds: 400),
              child: ElevatedButton.icon(
                onPressed: _startNavigation,
                icon: const Icon(Icons.directions),
                label: Text('Iniciar Navegação (${_stops.length} Paradas)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 40),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 6,
                ),
              ),
            ),
          const SizedBox(height: 8),
          if (_stops.isNotEmpty)
            Align(
              alignment: Alignment.bottomLeft,
              child: GestureDetector(
                onTap: _clearRoute,
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent,
                  ),
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(left: 8, bottom: 8),
                  child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Drawer _buildDrawer(User? user) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32),
            alignment: Alignment.center,
            color: mainButtonColor,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: _localImage != null ? FileImage(_localImage!) : null,
                  child: _localImage == null ? const Icon(Icons.person, size: 40, color: Colors.blue) : null,
                ),
                const SizedBox(height: 12),
                Text(user?.displayName ?? 'Usuário', style: const TextStyle(color: Colors.white)),
                Text(user?.email ?? '', style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Perfil'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())),
          ),
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
    );
  }
}
