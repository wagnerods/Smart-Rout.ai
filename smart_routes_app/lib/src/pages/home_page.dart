import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:smart_routes_app/src/pages/profile_info_screen.dart';
import 'package:smart_routes_app/src/pages/profile_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';
import 'package:sliding_up_panel/sliding_up_panel.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoadingNavigation = false;
  File? _localImage;
  List<Map<String, dynamic>> _stops = [];
  String? _ultimaParada;
  Position? _currentPosition;
  late final MapController _mapController;
  Map<String, dynamic>? _proximaParada;

  static const platform = MethodChannel('com.smartroutes.navigation');
  final PanelController _panelController = PanelController();

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
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
    _mapController.move(LatLng(position.latitude, position.longitude), 16);
    _definirProximaParada();
  }

  void _definirProximaParada() {
    if (_currentPosition == null || _stops.isEmpty) return;
    double menorDistancia = double.infinity;
    Map<String, dynamic>? maisProxima;
    for (var stop in _stops) {
      final double dist = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        stop['latitude'],
        stop['longitude'],
      );
      if (dist < menorDistancia) {
        menorDistancia = dist;
        maisProxima = stop;
      }
    }
    setState(() => _proximaParada = maisProxima);
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

    if (result != null && result is Map<String, dynamic>) {
      final List rota = result['rota'] ?? [];
      final bool expandir = result['expandir'] ?? false;

      List<Map<String, dynamic>> loadedStops = [];
      for (var item in rota) {
        if (item is Map<String, dynamic> && item.containsKey('latitude') && item.containsKey('longitude')) {
          loadedStops.add({
            'cep': item['cep'] ?? '',
            'endereco': item['endereco'] ?? '',
            'latitude': item['latitude'],
            'longitude': item['longitude'],
          });
        }
      }

      setState(() {
        _stops = loadedStops;
        _definirProximaParada();
      });

      if (expandir) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _panelController.open();
        });
      }
    }
  }

  void _limparParadas() {
    setState(() {
      _stops.clear();
      _proximaParada = null;
    });
    _panelController.close();
  }

  void _startNavigation() async {
    if (_currentPosition == null || _stops.isEmpty) return;

    setState(() => _isLoadingNavigation = true);

    final origem = {
      'latitude': _currentPosition!.latitude,
      'longitude': _currentPosition!.longitude,
    };

    final paradas = _stops.map((stop) => {
      'latitude': (stop['latitude'] as num).toDouble(),
      'longitude': (stop['longitude'] as num).toDouble(),
    }).toList();

    try {
      // 🔄 Delay para garantir estabilidade do GPS
      await Future.delayed(const Duration(seconds: 2));

      // 🔄 (Opcional) reinicializar localização antes da chamada
      final freshPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      final novaOrigem = {
        'latitude': freshPosition.latitude,
        'longitude': freshPosition.longitude,
      };

      await platform.invokeMethod('startNavigationWithStops', {
        'stops': [novaOrigem, ...paradas],
      });
    } on PlatformException catch (e) {
      debugPrint("Erro ao iniciar navegação embutida: ${e.message}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Falha ao iniciar rota: ${e.message}")),
      );
    } finally {
      if (mounted) setState(() => _isLoadingNavigation = false);
    }
  }

  double _calcularDistanciaTotal() {
    if (_stops.length < 2) return 0.0;
    double total = 0.0;
    for (int i = 0; i < _stops.length - 1; i++) {
      total += Geolocator.distanceBetween(
        _stops[i]['latitude'], _stops[i]['longitude'],
        _stops[i + 1]['latitude'], _stops[i + 1]['longitude'],
      );
    }
    return total / 1000;
  }  
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      drawer: _buildDrawer(user),
      body: Stack(
        children: [
          SlidingUpPanel(
            controller: _panelController,
            minHeight: 100,
            maxHeight: 340,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            panelBuilder: (controller) => ListView(
              controller: controller,
              padding: const EdgeInsets.all(16),
              children: [
                // BARRA DE PESQUISA NO TOPO
                GestureDetector(
                  onTap: _navigateToAddStops,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: const [
                        Icon(Icons.search, color: Colors.grey),
                        SizedBox(width: 10),
                        Expanded(child: Text("Tap to add stops", style: TextStyle(color: Colors.grey))),
                        Icon(Icons.qr_code_scanner, color: Colors.grey),
                        SizedBox(width: 8),
                        Icon(Icons.mic, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                if (_proximaParada != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.place),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _proximaParada!['cep'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: _navigateToAddStops,
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: _limparParadas,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _proximaParada!['endereco'] ?? '',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Paradas: ${_stops.length}"),
                      Text("Distância total: ${_calcularDistanciaTotal().toStringAsFixed(2)} km"),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.navigation),
                    label: const Text('Iniciar Navegação'),
                    onPressed: _startNavigation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            body: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(-23.55052, -46.633308),
                    initialZoom: 15.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                      subdomains: ['a', 'b', 'c'],
                    ),
                    MarkerLayer(
                      markers: _stops.map((stop) => Marker(
                        point: LatLng(stop['latitude'], stop['longitude']),
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.flag, color: Colors.blue, size: 30),
                      )).toList(),
                    ),
                  ],
                ),
                Positioned(
                  top: 40,
                  left: 16,
                  child: Material(
                    color: const Color(0xFF64B5F6),
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const UserInfoScreen()),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 👇 LOADING OVERLAY (aparece por cima de tudo)
          if (_isLoadingNavigation)
            Positioned.fill(
              child: Container(
                color: Colors.white.withOpacity(0.85),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/nextstop_logo.png', width: 80),
                      const SizedBox(height: 16),
                      const Text('Carregando rota...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 20),
                      const CircularProgressIndicator(color: Color(0xFF64B5F6)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  Drawer _buildDrawer(User? user) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF64B5F6)),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: _localImage != null ? FileImage(_localImage!) : null,
                  child: _localImage == null ? const Icon(Icons.person, size: 40, color: Colors.white) : null,
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
          const Spacer(),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}