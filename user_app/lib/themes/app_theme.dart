import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

final _seed = const Color(0xFF5B7BFE);

final lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.light),
  textTheme: GoogleFonts.manropeTextTheme(),
  scaffoldBackgroundColor: const Color(0xFFF5F7FB),
  cardColor: Colors.white.withOpacity(.9),
  appBarTheme: const AppBarTheme(elevation: 0, backgroundColor: Colors.transparent, foregroundColor: Colors.black),
);

final darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark),
  textTheme: GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme),
  scaffoldBackgroundColor: const Color(0xFF0F172A),
  cardColor: const Color(0xFF111A2E),
  appBarTheme: const AppBarTheme(elevation: 0, backgroundColor: Colors.transparent, foregroundColor: Colors.white),
);
