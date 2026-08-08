import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../models/libro.dart';
import '../../models/pista_musica.dart';
import '../../widgets/mini_reproductor_widget.dart';

class PantallaReproductorAudiolibro extends StatefulWidget {
  final Libro libro;
  final VoidCallback onCambio;
  final List<PistaMusica> pistasMusica;

  const PantallaReproductorAudiolibro({
    super.key,
    required this.libro,
    required this.onCambio,
    this.pistasMusica = const [],
  });

  @override
  State<PantallaReproductorAudiolibro> createState() =>
      _PantallaReproductorAudiolibroState();
}

class _PantallaReproductorAudiolibroState
    extends State<PantallaReproductorAudiolibro> {
  final AudioPlayer _player = AudioPlayer();
  bool   _reproduciendo = false;
  double _velocidad     = 1.0;
  Duration _posicion    = Duration.zero;
  Duration _duracion    = Duration.zero;
  int?   _timerMinutos;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    await _player.setSourceDeviceFile(widget.libro.rutaLocal);
    await _player.seek(Duration(milliseconds: widget.libro.posicionMs));
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _reproduciendo = s == PlayerState.playing);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duracion = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) {
        setState(() => _posicion = p);
        widget.libro.posicionMs = p.inMilliseconds;
        // Guardar cada 5 segundos aprox
        if (p.inSeconds % 5 == 0) widget.onCambio();
        // Marcar leído al 95%
        if (_duracion.inMilliseconds > 0 &&
            p.inMilliseconds / _duracion.inMilliseconds >= 0.95 &&
            !widget.libro.leido) {
          widget.libro.leido  = true;
          widget.libro.porLeer = false;
          widget.onCambio();
        }
      }
    });
  }

  Future<void> _togglePlay() async {
    if (_reproduciendo) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  Future<void> _saltar(int segundos) async {
    Duration nueva = _posicion + Duration(seconds: segundos);
    if (nueva < Duration.zero) nueva = Duration.zero;
    if (_duracion > Duration.zero && nueva > _duracion) nueva = _duracion;
    await _player.seek(nueva);
  }

  Future<void> _cambiarVelocidad(double v) async {
    setState(() => _velocidad = v);
    await _player.setPlaybackRate(v);
  }

  void _activarSleepTimer(int minutos) {
    setState(() => _timerMinutos = minutos);
    Future.delayed(Duration(minutes: minutos), () async {
      if (mounted) await _player.pause();
    });
  }

  String _formatDur(Duration d) {
    final h  = d.inHours;
    final m  = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s  = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      appBar: AppBar(
        backgroundColor: ColoresApp.fondoPrincipal,
        elevation      : 0,
        iconTheme      : const IconThemeData(color: Colors.white),
        title: Text(
          widget.libro.titulo,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          MiniReproductorMusicaFondo(pistas: widget.pistasMusica),
          // Sleep timer
          PopupMenuButton<int>(
            icon: Icon(
              Icons.bedtime_rounded,
              color: _timerMinutos != null ? ColoresApp.acento : Colors.white54,
            ),
            tooltip   : 'Temporizador',
            color     : ColoresApp.fondoTarjeta,
            onSelected: _activarSleepTimer,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 15, child: Text('15 min', style: TextStyle(color: Colors.white))),
              PopupMenuItem(value: 30, child: Text('30 min', style: TextStyle(color: Colors.white))),
              PopupMenuItem(value: 60, child: Text('60 min', style: TextStyle(color: Colors.white))),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icono de portada
            Container(
              width      : 200,
              height     : 200,
              decoration : BoxDecoration(
                color        : ColoresApp.fondoTarjeta,
                borderRadius : BorderRadius.circular(20),
                boxShadow    : [
                  BoxShadow(
                    color     : ColoresApp.acento.withAlpha(60),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.headphones_rounded,
                color: ColoresApp.acento,
                size : 100,
              ),
            ),
            const SizedBox(height: 28),

            // Título
            Text(
              widget.libro.titulo,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 28),

            // Barra de progreso
            Slider(
              value       : _duracion.inMilliseconds > 0
                  ? _posicion.inMilliseconds / _duracion.inMilliseconds
                  : 0.0,
              min         : 0.0,
              max         : 1.0,
              activeColor : ColoresApp.acento,
              inactiveColor: Colors.white24,
              onChanged   : (v) => _player.seek(
                Duration(milliseconds: (v * _duracion.inMilliseconds).toInt()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDur(_posicion),   style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  Text(_formatDur(_duracion),   style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Controles principales
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize : 36,
                  icon     : const Icon(Icons.replay_10_rounded, color: Colors.white70),
                  onPressed: () => _saltar(-10),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    width : 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color      : ColoresApp.acento,
                      shape      : BoxShape.circle,
                      boxShadow  : [
                        BoxShadow(
                          color     : ColoresApp.acento.withAlpha(100),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      _reproduciendo ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size : 40,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  iconSize : 36,
                  icon     : const Icon(Icons.forward_10_rounded, color: Colors.white70),
                  onPressed: () => _saltar(10),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Velocidad
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [0.5, 1.0, 1.5, 2.0].map((v) {
                final seleccionada = _velocidad == v;
                return ChoiceChip(
                  label: Text('${v}x'),
                  selected: seleccionada,
                  selectedColor: ColoresApp.acentoOscuro,
                  labelStyle: TextStyle(
                    color: seleccionada ? Colors.white : Colors.white54,
                  ),
                  backgroundColor: ColoresApp.fondoTarjeta,
                  onSelected: (_) => _cambiarVelocidad(v),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
