import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../core/audio_global.dart';
import '../../models/pista_musica.dart';

/// Mini-reproductor de música de fondo que aparece en el AppBar de los lectores.
class MiniReproductorMusicaFondo extends StatelessWidget {
  final List<PistaMusica> pistas;

  const MiniReproductorMusicaFondo({super.key, required this.pistas});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AudioGlobal(),
      builder: (context, _) {
        final audio    = AudioGlobal();
        final sonando  = audio.sonando;
        final titulo   = audio.tituloActual;

        return IconButton(
          tooltip: sonando
              ? '♪ $titulo (toca para controlar)'
              : 'Música de fondo',
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Icon(
              sonando ? Icons.music_note_rounded : Icons.music_off_rounded,
              key   : ValueKey(sonando),
              color : sonando ? ColoresApp.acento : Colors.white38,
              size  : 20,
            ),
          ),
          onPressed: () => _mostrarPanel(context, audio),
        );
      },
    );
  }

  void _mostrarPanel(BuildContext context, AudioGlobal audio) {
    showModalBottomSheet(
      context         : context,
      backgroundColor: ColoresApp.fondoTarjeta,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PanelMusicaFondo(pistas: pistas),
    );
  }
}

// ─── Panel de control de música ─────────────────────────────────────────────
class _PanelMusicaFondo extends StatelessWidget {
  final List<PistaMusica> pistas;
  const _PanelMusicaFondo({required this.pistas});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AudioGlobal(),
      builder: (context, _) {
        final audio   = AudioGlobal();
        final sonando = audio.sonando;
        final titulo  = audio.tituloActual;

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Indicador
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Título actual
              Row(
                children: [
                  Icon(
                    sonando ? Icons.music_note_rounded : Icons.music_off_rounded,
                    color: ColoresApp.acento,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      titulo ?? 'Sin música reproduciéndose',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Volumen
              Row(
                children: [
                  const Icon(Icons.volume_down_rounded, color: Colors.white54, size: 18),
                  Expanded(
                    child: Slider(
                      value          : audio.volumen,
                      min            : 0.0,
                      max            : 1.0,
                      activeColor    : ColoresApp.acento,
                      inactiveColor  : Colors.white24,
                      onChanged      : (v) => audio.cambiarVolumen(v),
                    ),
                  ),
                  const Icon(Icons.volume_up_rounded, color: Colors.white54, size: 18),
                ],
              ),
              const SizedBox(height: 12),

              // Botones
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Play / Pause
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColoresApp.acentoOscuro,
                      foregroundColor: Colors.white,
                    ),
                    icon : Icon(sonando ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    label: Text(sonando ? 'Pausar' : 'Reanudar'),
                    onPressed: audio.tituloActual != null
                        ? () => audio.pausarOReanudar()
                        : null,
                  ),
                  // Detener
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor : Colors.white70,
                      side            : const BorderSide(color: Colors.white24),
                    ),
                    icon     : const Icon(Icons.stop_rounded),
                    label    : const Text('Detener'),
                    onPressed: audio.tituloActual != null
                        ? () async {
                            await audio.detener();
                            if (context.mounted) Navigator.pop(context);
                          }
                        : null,
                  ),
                ],
              ),

              // Lista de pistas disponibles
              if (pistas.isNotEmpty) ...[
                const Divider(color: Colors.white12, height: 28),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Mis pistas de música',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    itemCount: pistas.length,
                    itemBuilder: (_, i) {
                      final pista = pistas[i];
                      final esActiva = titulo == pista.titulo;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                        leading: Icon(
                          esActiva && sonando
                              ? Icons.equalizer_rounded
                              : Icons.music_note_rounded,
                          color: esActiva ? ColoresApp.acento : Colors.white38,
                          size: 18,
                        ),
                        title: Text(
                          pista.titulo,
                          style: TextStyle(
                            color     : esActiva ? ColoresApp.acento : Colors.white70,
                            fontSize  : 13,
                            fontWeight: esActiva ? FontWeight.w600 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => audio.reproducirLocal(pista.rutaLocal, pista.titulo),
                      );
                    },
                  ),
                ),
              ],
              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        );
      },
    );
  }
}
