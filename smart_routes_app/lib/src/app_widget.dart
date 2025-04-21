import 'package:flutter/material.dart';
import 'package:smart_routes_app/src/pages/login_page.dart';
import 'package:smart_routes_app/src/pages/home_page.dart';
import 'package:smart_routes_app/src/pages/add_stops_page.dart';
import 'package:smart_routes_app/src/pages/profile_page.dart';
import 'package:smart_routes_app/src/pages/splash_screen.dart'; // <<< Importa a SplashScreen aqui

class AppWidget extends StatelessWidget {
  const AppWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NextStop', // <<< Já atualizei para o novo nome!
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF8F8F8),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey,
          ),
        ),
      ),
      initialRoute: '/splash', // <<< Agora inicia na Splash
      routes: {
        '/splash': (context) => const SplashScreen(), // <<< Nova rota para Splash
        '/': (context) => const LoginPage(),
        '/home': (context) => const HomePage(),
        '/addStops': (context) => const AddStopsPage(),
        '/profile': (context) => const ProfilePage(),
      },
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const LoginPage(),
        );
      },
    );
  }
}
