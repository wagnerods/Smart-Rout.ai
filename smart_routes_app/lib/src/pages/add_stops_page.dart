import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:smart_routes_app/sevices/geocoding_service.dart';
import 'package:smart_routes_app/sevices/viacep_service.dart';

class AddStopsPage extends StatefulWidget {
  const AddStopsPage({super.key});

  @override
  State<AddStopsPage> createState() => _AddStopsPageState();
}

class _AddStopsPageState extends State<AddStopsPage> {
  final TextEditingController _cepController = TextEditingController();
  final List<Map<String, dynamic>> _stops = [];
  bool _isLoading = false;

  Future<void> _buscarCep(String cep, {String? numeroResidencia}) async {
    if (cep.length != 8 || int.tryParse(cep) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CEP inválido! Digite 8 números.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final endereco = await ViaCepService.buscarEnderecoPorCep(cep);

    if (endereco != null) {
      String enderecoCompleto =
          '${endereco['logradouro']}${numeroResidencia != null ? ", $numeroResidencia" : ''}, ${endereco['bairro']}, ${endereco['localidade']} - ${endereco['uf']}';

      final location = await GeocodingService.buscarCoordenadas(enderecoCompleto);

      if (location != null) {
        setState(() {
          _stops.add({
            'cep': cep,
            'endereco': enderecoCompleto,
            'latitude': location.latitude,
            'longitude': location.longitude,
          });
          _cepController.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível localizar o endereço.')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CEP não encontrado!')),
      );
    }

    setState(() => _isLoading = false);
  }

  Future<void> _tirarFotoEOCR() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile == null) return;

    final inputImage = InputImage.fromFile(File(pickedFile.path));
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

    String? cepEncontrado;
    String? numeroEncontrado;

    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        final textoLimpo = line.text.replaceAll(RegExp(r'[^0-9]'), '');
        if (textoLimpo.length == 8 && cepEncontrado == null) {
          cepEncontrado = textoLimpo;
        } else if (textoLimpo.length >= 1 && textoLimpo.length <= 5 && numeroEncontrado == null) {
          numeroEncontrado = textoLimpo;
        }
      }
    }

    if (cepEncontrado != null) {
      bool confirmar = await _mostrarDialogConfirmacao(cepEncontrado, numeroEncontrado);
      if (confirmar) {
        await _buscarCep(cepEncontrado, numeroResidencia: numeroEncontrado);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível detectar o CEP.')),
      );
    }
  }

  Future<bool> _mostrarDialogConfirmacao(String cep, String? numero) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirmação'),
            content: Text('Detectei o CEP: $cep\nNúmero: ${numero ?? "não detectado"}\nDeseja adicionar?'),
            actions: [
              TextButton(
                child: const Text('Cancelar'),
                onPressed: () => Navigator.pop(context, false),
              ),
              TextButton(
                child: const Text('Confirmar'),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ) ??
        false;
  }

  double _calcularDistancia(double lat1, double lon1, double lat2, double lon2) {
    const double raioTerra = 6371;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return raioTerra * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180);

  List<Map<String, dynamic>> _otimizarParadas(
    List<Map<String, dynamic>> paradas,
    double startLat,
    double startLng,
  ) {
    final List<Map<String, dynamic>> restantes = List.from(paradas);
    final List<Map<String, dynamic>> ordenadas = [];

    double latAtual = startLat;
    double lngAtual = startLng;

    while (restantes.isNotEmpty) {
      double menorDistancia = double.infinity;
      int indiceMaisProximo = 0;

      for (int i = 0; i < restantes.length; i++) {
        final parada = restantes[i];
        final distancia = _calcularDistancia(
          latAtual,
          lngAtual,
          parada['latitude'],
          parada['longitude'],
        );

        if (distancia < menorDistancia) {
          menorDistancia = distancia;
          indiceMaisProximo = i;
        }
      }

      final proximaParada = restantes.removeAt(indiceMaisProximo);
      ordenadas.add(proximaParada);

      latAtual = proximaParada['latitude'];
      lngAtual = proximaParada['longitude'];
    }

    return ordenadas;
  }

  Future<void> _salvarEOtimizar() async {
    if (_stops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione pelo menos um CEP.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuário não logado!')),
        );
        return;
      }

      final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);

      for (var stop in _stops) {
        await userDoc.collection('addresses').add({
          'cep': stop['cep'],
          'endereco': stop['endereco'],
          'latitude': stop['latitude'],
          'longitude': stop['longitude'],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final rotaOtimizada = _otimizarParadas(_stops, position.latitude, position.longitude);

      Navigator.pop(context, rotaOtimizada);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar ou otimizar: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adicionar Paradas'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cepController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Digite o CEP (sem traço)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator())
                    : Row(
                        children: [
                          ElevatedButton(
                            onPressed: () => _buscarCep(_cepController.text.trim()),
                            child: const Text('Adicionar'),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: _tirarFotoEOCR,
                            icon: const Icon(Icons.camera_alt),
                          ),
                        ],
                      ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _stops.length,
                itemBuilder: (context, index) {
                  final stop = _stops[index];
                  return Dismissible(
                    key: Key(stop['cep'] + index.toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.redAccent,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) {
                      setState(() {
                        _stops.removeAt(index);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Parada removida!')),
                      );
                    },
                    child: ListTile(
                      leading: const Icon(Icons.location_on),
                      title: Text(stop['endereco']),
                      subtitle: Text('Lat: ${stop['latitude']}, Lng: ${stop['longitude']}'),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _salvarEOtimizar,
              icon: const Icon(Icons.map),
              label: const Text('Salvar e Otimizar Rota'),
            ),
          ],
        ),
      ),
    );
  }
}
