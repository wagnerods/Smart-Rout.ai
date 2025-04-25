import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:smart_routes_app/sevices/geocoding_service.dart';
import 'package:smart_routes_app/sevices/viacep_service.dart';

class AddStopsPage extends StatefulWidget {
  final List<Map<String, dynamic>> existingStops;

  const AddStopsPage({super.key, this.existingStops = const []});

  @override
  State<AddStopsPage> createState() => _AddStopsPageState();
}

class _AddStopsPageState extends State<AddStopsPage> {
  final TextEditingController _cepController = TextEditingController();
  final Color mainButtonColor = const Color(0xFF64B5F6);
  late List<Map<String, dynamic>> _stops;
  bool _isLoading = false;
  late stt.SpeechToText _speech;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _stops = widget.existingStops.map((stop) {
      return {
        'cep': stop['cep'] ?? '',
        'endereco': stop['endereco'] ?? 'Sem endereço disponível',
        'latitude': stop['latitude'],
        'longitude': stop['longitude'],
      };
    }).toList();
    _speech = stt.SpeechToText();
  }

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
          '${endereco['logradouro']}${numeroResidencia != null ? ", \$numeroResidencia" : ''}, ${endereco['bairro']}, ${endereco['localidade']} - ${endereco['uf']}';

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
    final recognizedText = await textRecognizer.processImage(inputImage);

    String? cepEncontrado;
    String? numeroEncontrado;

    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        final textoLimpo = line.text.replaceAll(RegExp(r'[^0-9]'), '');
        if (textoLimpo.length == 8 && cepEncontrado == null) {
          cepEncontrado = textoLimpo;
        } else if (textoLimpo.isNotEmpty && textoLimpo.length <= 5 && numeroEncontrado == null) {
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

  Future<void> _startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(onResult: (result) {
        final text = result.recognizedWords.replaceAll(RegExp(r'[^0-9]'), '');
        if (text.length == 8) {
          _cepController.text = text;
          _speech.stop();
          setState(() => _isListening = false);
        }
      });
    }
  }

  Future<bool> _mostrarDialogConfirmacao(String cep, String? numero) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirmação'),
            content: Text('Detectei o CEP: \$cep\nNúmero: \${numero ?? "não detectado"}\nDeseja adicionar?'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adicionar Paradas')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _cepController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Type to add a stop',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (value) => _buscarCep(value.trim()),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: _tirarFotoEOCR,
                  ),
                  IconButton(
                    icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
                    onPressed: _startListening,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _isLoading ? const LinearProgressIndicator() : Container(),
            const SizedBox(height: 12),
            _stops.isEmpty
                ? const Column(
                    children: [
                      Icon(Icons.add_location_alt, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('Add new stops, or find stops in this route'),
                    ],
                  )
                : Expanded(
                    child: ListView.builder(
                      itemCount: _stops.length,
                      itemBuilder: (context, index) {
                        final stop = _stops[index];
                        return ListTile(
                          leading: const Icon(Icons.location_on),
                          title: Text(stop['endereco'] ?? 'Sem endereço disponível'),
                          subtitle: Text('Lat: ${stop['latitude']}, Lng: ${stop['longitude']}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editarParada(index),
                          ),
                        );
                      },
                    ),
                  ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _stops.isEmpty
                  ? null
                  : () {
                      setState(() => _stops.clear());
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Todas as paradas foram removidas!')),
                      );
                    },
              icon: const Icon(Icons.delete_forever),
              label: const Text('Limpar Paradas'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 6,
                shadowColor: Colors.black45,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _salvarEOtimizar,
              icon: const Icon(Icons.map),
              label: const Text('Salvar e Otimizar Rota'),
              style: ElevatedButton.styleFrom(
                backgroundColor: mainButtonColor,
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
    );
  }

  Future<void> _editarParada(int index) async {
    TextEditingController enderecoController = TextEditingController(text: _stops[index]['endereco']);

    bool? confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Endereço'),
        content: TextField(
          controller: enderecoController,
          decoration: const InputDecoration(labelText: 'Novo Endereço'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (confirmado == true && enderecoController.text.trim().isNotEmpty) {
      setState(() {
        _stops[index]['endereco'] = enderecoController.text.trim();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Endereço atualizado com sucesso!')),
      );
    }
  }

  double _deg2rad(double deg) => deg * (pi / 180);

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

  List<Map<String, dynamic>> _otimizarParadas(List<Map<String, dynamic>> paradas, double startLat, double startLng) {
    final List<Map<String, dynamic>> restantes = List.from(paradas);
    final List<Map<String, dynamic>> ordenadas = [];

    double latAtual = startLat;
    double lngAtual = startLng;

    while (restantes.isNotEmpty) {
      double menorDistancia = double.infinity;
      int indiceMaisProximo = 0;

      for (int i = 0; i < restantes.length; i++) {
        final parada = restantes[i];
        final distancia = _calcularDistancia(latAtual, lngAtual, parada['latitude'], parada['longitude']);

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
        const SnackBar(content: Text('Adicione pelo menos uma parada.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final rotaOtimizada = _otimizarParadas(_stops, position.latitude, position.longitude);
      Navigator.pop(context, {'rota': rotaOtimizada, 'expandir': true});

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar ou otimizar: \$e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}