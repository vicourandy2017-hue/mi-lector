import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Modelo de seguimiento de racha de lectura diaria y metas personales.
class RachaLectura {
  static const String _kRachaData = 'racha_lectura_data_v1';

  final int rachaDias;
  final int minutosHoy;
  final int metaMinutos;
  final String ultimaFechaLectura;

  RachaLectura({
    this.rachaDias = 0,
    this.minutosHoy = 0,
    this.metaMinutos = 20,
    String? ultimaFechaLectura,
  }) : ultimaFechaLectura =
            ultimaFechaLectura ?? DateTime.now().toIso8601String().split('T')[0];

  Map<String, dynamic> toMap() => {
        'rachaDias': rachaDias,
        'minutosHoy': minutosHoy,
        'metaMinutos': metaMinutos,
        'ultimaFechaLectura': ultimaFechaLectura,
      };

  factory RachaLectura.fromMap(Map<String, dynamic> map) => RachaLectura(
        rachaDias: map['rachaDias'] ?? 0,
        minutosHoy: map['minutosHoy'] ?? 0,
        metaMinutos: map['metaMinutos'] ?? 20,
        ultimaFechaLectura: map['ultimaFechaLectura'],
      );

  static Future<RachaLectura> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_kRachaData);
    if (jsonStr == null) {
      final nueva = RachaLectura(rachaDias: 1, minutosHoy: 5, metaMinutos: 20);
      await guardar(nueva);
      return nueva;
    }

    try {
      final map = jsonDecode(jsonStr);
      final racha = RachaLectura.fromMap(map);

      final hoy = DateTime.now().toIso8601String().split('T')[0];
      final ayer = DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String()
          .split('T')[0];

      if (racha.ultimaFechaLectura == hoy) {
        return racha;
      } else if (racha.ultimaFechaLectura == ayer) {
        // Se mantiene la racha pero los minutos de hoy inician en 0
        final actualizada = RachaLectura(
          rachaDias: racha.rachaDias,
          minutosHoy: 0,
          metaMinutos: racha.metaMinutos,
          ultimaFechaLectura: hoy,
        );
        await guardar(actualizada);
        return actualizada;
      } else {
        // La racha se reinicia a 1 día
        final reiniciada = RachaLectura(
          rachaDias: 1,
          minutosHoy: 0,
          metaMinutos: racha.metaMinutos,
          ultimaFechaLectura: hoy,
        );
        await guardar(reiniciada);
        return reiniciada;
      }
    } catch (_) {
      return RachaLectura();
    }
  }

  static Future<void> guardar(RachaLectura racha) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRachaData, jsonEncode(racha.toMap()));
  }

  static Future<RachaLectura> registrarMinutosLectura(int minutosAgregados) async {
    final actual = await cargar();
    final hoy = DateTime.now().toIso8601String().split('T')[0];

    final nuevaRacha = RachaLectura(
      rachaDias: actual.rachaDias == 0 ? 1 : actual.rachaDias,
      minutosHoy: actual.minutosHoy + minutosAgregados,
      metaMinutos: actual.metaMinutos,
      ultimaFechaLectura: hoy,
    );

    await guardar(nuevaRacha);
    return nuevaRacha;
  }
}
