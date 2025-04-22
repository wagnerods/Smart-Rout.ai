import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class RotaFatiadaService {
  static Future<void> iniciarNavegacaoFatiada({
    required BuildContext context,
    required Map<String, double> origem,
    required List<Map<String, double>> paradas,
  }) async {
    if (paradas.isEmpty) return;

    final etapas = _dividirParadasEmEtapas(paradas, origem);

    await _navegarEtapa(context, etapas, 0);
  }

  static List<List<Map<String, double>>> _dividirParadasEmEtapas(
    List<Map<String, double>> paradas,
    Map<String, double> origem,
  ) {
    final List<List<Map<String, double>>> etapas = [];
    int i = 0;
    List<Map<String, double>> etapaAtual = [origem];

    while (i < paradas.length) {
      etapaAtual.add(paradas[i]);
      i++;

      if (etapaAtual.length == 10 || i == paradas.length) {
        etapas.add(List<Map<String, double>>.from(etapaAtual));
        if (i < paradas.length) {
          etapaAtual = [paradas[i - 1]];
        }
      }
    }

    return etapas;
  }

  static Future<void> _navegarEtapa(
    BuildContext context,
    List<List<Map<String, double>>> etapas,
    int indiceAtual,
  ) async {
    if (indiceAtual >= etapas.length) return;

    final etapa = etapas[indiceAtual];
    final origem = etapa.first;
    final destinos = etapa.sublist(1);

    final String origin = '${origem['latitude']},${origem['longitude']}';
    final String destination = '${destinos.last['latitude']},${destinos.last['longitude']}';

    String waypoints = '';
    if (destinos.length > 1) {
      waypoints = destinos
          .sublist(0, destinos.length - 1)
          .map((d) => '${d['latitude']},${d['longitude']}')
          .join('|');
    }

    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination&waypoints=$waypoints&travelmode=driving',
    );

    await _mostrarTelaNavegacao(
      context: context,
      totalEtapas: etapas.length,
      etapaAtual: indiceAtual,
      url: url,
      onProximo: () => _navegarEtapa(context, etapas, indiceAtual + 1),
    );
  }

  static Future<void> _mostrarTelaNavegacao({
    required BuildContext context,
    required int totalEtapas,
    required int etapaAtual,
    required Uri url,
    required VoidCallback onProximo,
  }) async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: Scaffold(
              backgroundColor: Colors.black.withOpacity(0.85),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Entrega ${etapaAtual + 1} de $totalEtapas',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 40),
                      ElevatedButton.icon(
                        onPressed: () async {
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          }
                        },
                        icon: const Icon(Icons.navigation, size: 26),
                        label: const Text('Abrir no Google Maps'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 55),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 8,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          if (etapaAtual < totalEtapas - 1) {
                            onProximo();
                          }
                        },
                        icon: Icon(
                          etapaAtual == totalEtapas - 1 ? Icons.check_circle_outline : Icons.arrow_forward,
                          size: 26,
                        ),
                        label: Text(
                          etapaAtual == totalEtapas - 1 ? 'Concluir' : 'Próxima Entrega',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: etapaAtual == totalEtapas - 1 ? Colors.green : Colors.orangeAccent,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 55),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
