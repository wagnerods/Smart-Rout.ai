import 'package:flutter/services.dart';

class NavigationChannel {
  static const MethodChannel _channel = MethodChannel('com.smartroutes.navigation');

  static Future<void> iniciarNavegacaoInterna() async {
    try {
      await _channel.invokeMethod('startNavigationActivity');
    } on PlatformException catch (e) {
      print("Erro ao iniciar navegação interna: ${e.message}");
    }
  }
}
