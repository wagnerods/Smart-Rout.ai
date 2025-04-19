import 'package:flutter/material.dart';
import 'package:smart_routes_app/src/pages/login_page.dart';
import 'package:smart_routes_app/src/pages/home_page.dart';
import 'package:smart_routes_app/src/pages/add_address_page.dart'; // (ainda deixamos se quiser)
import 'package:smart_routes_app/src/pages/add_stops_page.dart';
import 'package:smart_routes_app/src/pages/profile_page.dart'; // << NOVA importação!

class AppWidget extends StatelessWidget {
  const AppWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Routes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
      '/': (context) => const LoginPage(),
      '/home': (context) => const HomePage(),
      '/addAddress': (context) => const AddAddressPage(),
      '/addStops': (context) => const AddStopsPage(),
      '/profile': (context) => const ProfilePage(), // <- REGISTRADO AQUI
      },
      onGenerateRoute: (settings) {
        // Aqui você pode adicionar lógica para rotas dinâmicas, se necessário
        return MaterialPageRoute(
          builder: (context) => const LoginPage(), // Rota padrão
        );
      },
    );
  }
}
