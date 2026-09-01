import 'package:flutter/material.dart';

import 'screens/youtube_web_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GareebYoutubeApp());
}

class GareebYoutubeApp extends StatelessWidget {
  const GareebYoutubeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gareeb YouTube',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0C0B09),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE2B15A),
          surface: Color(0xFF0C0B09),
        ),
        useMaterial3: true,
      ),
      home: const YoutubeWebApp(),
    );
  }
}
