
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:smart_routes_app/src/pages/profile_page.dart';
import 'package:smart_routes_app/src/services/rota_fatiada_service.dart';
import 'package:flutter/services.dart'; // no topo do arquivo

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  File? _localImage;
  double _startNavButtonOpacity = 1.0;
  List<Map<String, dynamic>> _stops = [];
  Position? _currentPosition;

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
    setState(() => _currentPosition = position);
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
    }
  }

  static const platform = MethodChannel('com.smartroutes.navigation');

  void _startNavigation() async {
    if (_currentPosition == null || _stops.isEmpty) return;

    final origem = {
      'latitude': _currentPosition!.latitude,
      'longitude': _currentPosition!.longitude,
    };

    final paradas = _stops.map((stop) => {
      'latitude': (stop['latitude'] as num).toDouble(),
      'longitude': (stop['longitude'] as num).toDouble(),
    }).toList();

    try {
      await platform.invokeMethod('startNavigationWithStops', {
        'stops': [origem, ...paradas],
      });
    } on PlatformException catch (e) {
      debugPrint("Erro ao iniciar navegação embutida: ${e.message}");
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('NextStop')),
      drawer: _buildDrawer(user),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _navigateToAddStops,
              icon: const Icon(Icons.add_location_alt),
              label: Text('Adicionar Parada (${_stops.length})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF64B5F6),
                foregroundColor: Colors.white,
                minimumSize: const Size(200, 40),
              ),
            ),
            const SizedBox(height: 20),
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
                    minimumSize: const Size(200, 40),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Drawer _buildDrawer(User? user) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF64B5F6)),
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
