import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const AkustikDinleyiciApp());
}

class AkustikDinleyiciApp extends StatelessWidget {
  const AkustikDinleyiciApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Akustik Dinleyici',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF020802),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF88),
          surface: Color(0xFF080F08),
        ),
        fontFamily: 'monospace',
      ),
      home: const HomeScreen(),
    );
  }
}
