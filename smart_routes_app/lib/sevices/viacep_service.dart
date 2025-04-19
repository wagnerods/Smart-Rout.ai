import 'dart:convert';
import 'package:http/http.dart' as http;

class ViaCepService {
  static Future<Map<String, dynamic>?> buscarEnderecoPorCep(String cep) async {
    final url = Uri.parse('https://viacep.com.br/ws/$cep/json/');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data.containsKey('erro') && data['erro'] == true) {
        return null; // CEP inválido
      }

      return data;
    } else {
      return null;
    }
  }
}
