import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../models/racha_lectura.dart';

/// Widget de Racha de Lectura Diaria y Meta Personal con diseño Glassmorphic.
class RachaBannerWidget extends StatefulWidget {
  final VoidCallback? onTap;

  const RachaBannerWidget({super.key, this.onTap});

  @override
  State<RachaBannerWidget> createState() => _RachaBannerWidgetState();
}

class _RachaBannerWidgetState extends State<RachaBannerWidget> {
  RachaLectura _racha = RachaLectura();
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarRacha();
  }

  Future<void> _cargarRacha() async {
    final datos = await RachaLectura.cargar();
    if (mounted) {
      setState(() {
        _racha = datos;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const SizedBox.shrink();

    final double progreso = (_racha.minutosHoy / _racha.metaMinutos).clamp(0.0, 1.0);
    final bool metaAlcanzada = _racha.minutosHoy >= _racha.metaMinutos;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: ColoresApp.fondoTarjeta.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: metaAlcanzada
                ? Colors.amber.withValues(alpha: 0.5)
                : ColoresApp.acento.withValues(alpha: 0.25),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Ícono de Fuego animado / Racha
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: metaAlcanzada
                    ? Colors.amber.withValues(alpha: 0.2)
                    : ColoresApp.acentoOscuro.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Text(
                metaAlcanzada ? '🏆' : '🔥',
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(width: 12),
            // Detalles de la racha y minutos hoy
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '🔥 Racha de ${_racha.rachaDias} ${_racha.rachaDias == 1 ? "día" : "días"}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${_racha.minutosHoy}/${_racha.metaMinutos} min hoy',
                        style: TextStyle(
                          color: metaAlcanzada ? Colors.amberAccent : ColoresApp.acento,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Barra de progreso de lectura diaria
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progreso,
                      minHeight: 6,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        metaAlcanzada ? Colors.amberAccent : ColoresApp.acento,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
