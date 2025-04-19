import 'package:geocoding/geocoding.dart';

class GeocodingService {
  static Future<Location?> buscarCoordenadas(String enderecoCompleto) async {
    try {
      final locations = await locationFromAddress(enderecoCompleto);

      if (locations.isNotEmpty) {
        return locations.first;
      }
    } catch (e) {
      print('Erro ao buscar coordenadas: $e');
    }

    return null;
  }
}
