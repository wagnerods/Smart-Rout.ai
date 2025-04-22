import 'package:flutter/material.dart';
import 'package:smart_routes_app/src/pages/login_page.dart';
import 'package:smart_routes_app/src/pages/home_page.dart';
import 'package:smart_routes_app/src/pages/add_stops_page.dart';
import 'package:smart_routes_app/src/pages/profile_page.dart';
import 'package:smart_routes_app/src/pages/splash_screen.dart';

class AppWidget extends StatelessWidget {
  const AppWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NextStop',
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
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/': (context) => const LoginPage(),
        '/home': (context) => const HomePage(),
        '/profile': (context) => const ProfilePage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/addStops') {
          final args = settings.arguments;
          List<Map<String, dynamic>> stopsList = [];

          if (args != null) {
            if (args is List) {
              for (var item in args) {
                if (item is Map<String, dynamic>) {
                  stopsList.add({
                    'cep': item['cep'] ?? '',
                    'endereco': item['endereco'] ?? '',
                    'latitude': item['latitude'],
                    'longitude': item['longitude'],
                  });
                }
              }
            }
          }

          return MaterialPageRoute(
            builder: (context) => AddStopsPage(existingStops: stopsList),
          );
        }

        return MaterialPageRoute(
          builder: (context) => const LoginPage(),
        );
      },
    );
  }
}
