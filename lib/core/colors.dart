import 'package:flutter/material.dart';

class ColoresApp {
  static const Color fondoPrincipal = Color(0xFF0E2229);
  static const Color fondoTarjeta   = Color(0xFF16333D);
  static const Color fondoDrawer    = Color(0xFF0C1D23);
  static const Color acento         = Color(0xFF38BDF8);
  static const Color acentoOscuro   = Color(0xFF0284C7);

  static const List<String> fondosPorDefecto = [
    'assets/images/fondo1.jpg',
    'assets/images/fondo2.jpg',
    'assets/images/fondo3.jpg',
    'assets/images/fondo4.jpg',
  ];

  static const Map<String, Color> fondosSolidos = {
    'medianoche_pro'  : Color(0xFF0E2229),
    'azul_cosmico'    : Color(0xFF1E1B4B),
    'negro_obsidiana' : Color(0xFF18181B),
    'purpura_mistico' : Color(0xFF3B0764),
    'esmeralda_zen'   : Color(0xFF064E3B),
    'terracota_calida': Color(0xFF7C2D12),
  };
}
