import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/colors.dart';
import '../../models/libro.dart';
import '../../models/pista_musica.dart';

class PantallaReproductorVideo extends StatefulWidget {
  final Libro libro;
  final VoidCallback onCambio;
  final List<PistaMusica> pistasMusica;

  const PantallaReproductorVideo({
    super.key,
    required this.libro,
    required this.onCambio,
    this.pistasMusica = const [],
  });

  @override
  State<PantallaReproductorVideo> createState() =>
      _PantallaReproductorVideoState();
}

class _PantallaReproductorVideoState extends State<PantallaReproductorVideo> {
  late VideoPlayerController _ctrl;
  bool   _inicializado    = false;
  bool   _mostrarControles = true;
  double _velocidad       = 1.0;
  Duration _posicion      = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.file(File(widget.libro.rutaLocal))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _inicializado = true);
          _ctrl.seekTo(Duration(milliseconds: widget.libro.posicionMs));
          _ctrl.play();
        }
      });
    _ctrl.addListener(_onPlayerTick);
  }

  void _onPlayerTick() {
    if (!mounted) return;
    setState(() => _posicion = _ctrl.value.position);
    widget.libro.posicionMs = _ctrl.value.position.inMilliseconds;
    if (_ctrl.value.position.inSeconds % 5 == 0) widget.onCambio();

    final durMs = _ctrl.value.duration.inMilliseconds;
    if (durMs > 0 &&
        _ctrl.value.position.inMilliseconds / durMs >= 0.95 &&
        !widget.libro.leido) {
      widget.libro.leido  = true;
      widget.libro.porLeer = false;
      widget.onCambio();
    }
  }

  void _togglePlay() {
    _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play();
  }

  void _saltar(int segundos) {
    Duration nueva = _posicion + Duration(seconds: segundos);
    final total = _ctrl.value.duration;
    if (nueva < Duration.zero) nueva = Duration.zero;
    if (total > Duration.zero && nueva > total) nueva = total;
    _ctrl.seekTo(nueva);
  }

  void _cambiarVelocidad(double v) {
    setState(() => _velocidad = v);
    _ctrl.setPlaybackSpeed(v);
  }

  String _formatDur(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onPlayerTick);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _inicializado ? _buildPlayer() : _buildLoading(),
    );
  }

  Widget _buildLoading() => const Center(
        child: CircularProgressIndicator(color: ColoresApp.acento),
      );

  Widget _buildPlayer() {
    final isPlaying = _ctrl.value.isPlaying;

    return GestureDetector(
      onTap: () => setState(() => _mostrarControles = !_mostrarControles),
      child: Stack(
        children: [
          // Video centrado
          Center(
            child: AspectRatio(
              aspectRatio: _ctrl.value.aspectRatio,
              child       : VideoPlayer(_ctrl),
            ),
          ),

          // Overlay de controles
          if (_mostrarControles)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin  : Alignment.topCenter,
                  end    : Alignment.bottomCenter,
                  colors : [Colors.black87, Colors.transparent, Colors.black87],
                  stops  : [0.0, 0.5, 1.0],
                ),
              ),
            ),

          if (_mostrarControles) ...[
            // AppBar custom
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon : const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          widget.libro.titulo,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Controles centrales
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize : 40,
                    icon     : const Icon(Icons.replay_10_rounded, color: Colors.white),
                    onPressed: () => _saltar(-10),
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: _togglePlay,
                    child: Container(
                      padding    : const EdgeInsets.all(16),
                      decoration : const BoxDecoration(
                        color: ColoresApp.acentoOscuro,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size : 44,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    iconSize : 40,
                    icon     : const Icon(Icons.forward_10_rounded, color: Colors.white),
                    onPressed: () => _saltar(10),
                  ),
                ],
              ),
            ),

            // Barra inferior
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      // Velocidad
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 6,
                        children: [1.0, 1.25, 1.5, 2.0].map((v) {
                          final sel = _velocidad == v;
                          return ChoiceChip(
                            label: Text('${v}x',
                              style: TextStyle(
                                color  : sel ? Colors.white : Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            selected        : sel,
                            selectedColor   : ColoresApp.acentoOscuro,
                            backgroundColor : Colors.black38,
                            onSelected      : (_) => _cambiarVelocidad(v),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      // Progreso
                      VideoProgressIndicator(
                        _ctrl,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor  : ColoresApp.acento,
                          bufferedColor: Colors.white24,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDur(_posicion),  style: const TextStyle(color: Colors.white54, fontSize: 11)),
                          Text(_formatDur(_ctrl.value.duration),   style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
