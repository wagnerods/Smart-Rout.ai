import 'package:flutter/material.dart';
import 'package:flutter_google_places_hoc081098/flutter_google_places_hoc081098.dart';
import 'package:google_maps_webservice/places.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const String googleApiKey = "AIzaSyDIzvJPnyFN8eUJGBiUR4KlOx6V2THwQkM"; // Use a mesma do Maps

class AddAddressPage extends StatefulWidget {
  const AddAddressPage({super.key});

  @override
  State<AddAddressPage> createState() => _AddAddressPageState();
}

class _AddAddressPageState extends State<AddAddressPage> {
  final List<Map<String, dynamic>> _stops = [];

  final places = GoogleMapsPlaces(apiKey: googleApiKey);

  void _addStop() {
    setState(() {
      _stops.add({
        'address': '',
        'lat': null,
        'lng': null,
      });
    });
  }

  void _removeStop(int index) {
    setState(() {
      _stops.removeAt(index);
    });
  }

  Future<void> _selectAddress(int index) async {
    final Prediction? p = (await PlacesAutocomplete.show(
      context: context,
      apiKey: googleApiKey,
      mode: Mode.overlay,
      language: "pt-BR",
      strictbounds: false, // Pode ser true se quiser limitar mais
      types: [], // Deixar vazio para pegar todos tipos (endereços, locais etc)
      components: [Component(Component.country, "br")],
    ));

    if (p != null) {
      final detail = await places.getDetailsByPlaceId(p.placeId!);
      final location = detail.result.geometry!.location;

      setState(() {
        _stops[index]['address'] = p.description ?? '';
        _stops[index]['lat'] = location.lat;
        _stops[index]['lng'] = location.lng;
      });
    }
  }

  Future<void> _saveStops() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário não autenticado.')),
      );
      return;
    }

    for (final stop in _stops) {
      if (stop['address'].toString().isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('addresses')
            .add({
          'address': stop['address'],
          'latitude': stop['lat'],
          'longitude': stop['lng'],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Endereços salvos com sucesso!')),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adicionar Paradas')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _stops.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(_stops[index]['address'].isEmpty
                        ? 'Selecione o endereço'
                        : _stops[index]['address']),
                    leading: const Icon(Icons.location_on),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _removeStop(index),
                    ),
                    onTap: () => _selectAddress(index),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _addStop,
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar Parada'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _stops.isEmpty ? null : _saveStops,
                  icon: const Icon(Icons.save),
                  label: const Text('Salvar Todos Endereços'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
// //       body: Column(