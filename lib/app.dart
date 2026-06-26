import 'package:flutter/material.dart';
import 'package:genui_template/home_page.dart';
import 'package:genui_template/transit/bayhop_tokens.dart';
import 'package:google_fonts/google_fonts.dart';

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: BayHopColors.aiBlue,
        surface: BayHopColors.surface,
      ),
      scaffoldBackgroundColor: BayHopColors.bgTop,
    );

    return MaterialApp(
      title: 'BayHop',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        textTheme: GoogleFonts.hankenGroteskTextTheme(base.textTheme),
      ),
      home: const HomePage(),
    );
  }
}
