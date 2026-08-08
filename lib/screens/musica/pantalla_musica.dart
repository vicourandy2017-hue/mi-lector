import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../core/audio_global.dart';
import '../../models/pista_musica.dart';
import '../web/pantalla_visor_web.dart';

class PantallaMusicaGratis extends StatefulWidget {
  final List<PistaMusica> pistas;
  final Future<void> Function() onAgregarPista;
  final void Function(PistaMusica) onEliminarPista;

  const PantallaMusicaGratis({
    super.key,
    required this.pistas,
    required this.onAgregarPista,
    required this.onEliminarPista,
  });

  @override
  State<PantallaMusicaGratis> createState() => _PantallaMusicaGratisState();
}

class _PantallaMusicaGratisState extends State<PantallaMusicaGratis> {
  static const List<Map<String, dynamic>> _fuentesStreaming = [
    {
      'nombre'     : 'WWFM Classical',
      'descripcion': 'Radio clásica en vivo — ideal para leer',
      'url'        : 'https://wwfm.streamguys1.com/wwfm-mp3',
      'tipo'       : 'stream',
      'icono'      : Icons.radio_rounded,
      'color'      : 0xFF0284C7,
    },
    {
      'nombre'     : 'Musopen',
      'descripcion': 'Música clásica libre de derechos',
      'url'        : 'https://musopen.org',
      'tipo'       : 'web',
      'icono'      : Icons.music_note_rounded,
      'color'      : 0xFF059669,
    },
    {
      'nombre'     : 'Radio Paradise (Mellow Mix)',
      'descripcion': 'Música ambiental tranquila sin interrupciones',
      'url'        : 'https://stream.radioparadise.com/mellow-128',
      'tipo'       : 'stream',
      'icono'      : Icons.waves_rounded,
      'color'      : 0xFF7C3AED,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🎼 Música para leer',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Música de fondo sin interrumpir tu lectura',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 20),

            // Fuentes de streaming
            const Text('Fuentes gratuitas en línea',
              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ..._fuentesStreaming.map((f) => _tarjetaFuente(context, f)),

            // Pistas del usuario
            if (widget.pistas.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text('Mis pistas guardadas',
                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ...widget.pistas.map((p) => _tarjetaPista(context, p)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tarjetaFuente(BuildContext context, Map<String, dynamic> f) {
    final color = Color(f['color'] as int);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: ColoresApp.fondoTarjeta,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withAlpha(25), shape: BoxShape.circle),
          child: Icon(f['icono'] as IconData, color: color, size: 22),
        ),
        title: Text(f['nombre'] as String,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(f['descripcion'] as String,
          style: const TextStyle(color: Colors.white54, fontSize: 11)),
        trailing: Icon(Icons.play_circle_rounded, color: color, size: 28),
        onTap: () {
          if (f['tipo'] == 'stream') {
            AudioGlobal().reproducirUrl(f['url'] as String, f['nombre'] as String);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('♪ Reproduciendo ${f['nombre']}'),
                backgroundColor: ColoresApp.acentoOscuro,
              ),
            );
          } else {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => PantallaVisorWebCompleto(
                url: f['url'] as String, titulo: f['nombre'] as String),
            ));
          }
        },
      ),
    );
  }

  Widget _tarjetaPista(BuildContext context, PistaMusica pista) {
    return AnimatedBuilder(
      animation: AudioGlobal(),
      builder: (ctx, _) {
        final esActiva  = AudioGlobal().tituloActual == pista.titulo;
        final sonando   = AudioGlobal().sonando && esActiva;
        return Container(
          margin     : const EdgeInsets.only(bottom: 8),
          decoration : BoxDecoration(
            color        : esActiva
                ? ColoresApp.acento.withAlpha(30)
                : ColoresApp.fondoTarjeta,
            borderRadius : BorderRadius.circular(12),
            border       : Border.all(
              color: esActiva ? ColoresApp.acento.withAlpha(120) : Colors.white12,
            ),
          ),
          child: ListTile(
            leading: Icon(
              sonando ? Icons.equalizer_rounded : Icons.audio_file_rounded,
              color: esActiva ? ColoresApp.acento : Colors.white54,
            ),
            title: Text(
              pista.titulo,
              style: TextStyle(
                color      : esActiva ? ColoresApp.acento : Colors.white,
                fontWeight : esActiva ? FontWeight.w700 : FontWeight.normal,
                fontSize   : 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Play/Pause
                IconButton(
                  icon: Icon(
                    sonando ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: ColoresApp.acento,
                  ),
                  onPressed: () {
                    if (sonando) {
                      AudioGlobal().pausarOReanudar();
                    } else {
                      AudioGlobal().reproducirLocal(pista.rutaLocal, pista.titulo);
                    }
                  },
                ),
                // Eliminar
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                  onPressed: () => _confirmarEliminar(ctx, pista),
                ),
              ],
            ),
            onTap: () => AudioGlobal().reproducirLocal(pista.rutaLocal, pista.titulo),
          ),
        );
      },
    );
  }

  void _confirmarEliminar(BuildContext context, PistaMusica pista) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: ColoresApp.fondoTarjeta,
        title: const Text('Eliminar pista', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Eliminar "${pista.titulo}" de tu lista?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              widget.onEliminarPista(pista);
              setState(() {});
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
