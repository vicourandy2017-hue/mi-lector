import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioGlobal extends ChangeNotifier {
  static final AudioGlobal _instance = AudioGlobal._internal();
  factory AudioGlobal() => _instance;
  AudioGlobal._internal();

  final AudioPlayer player = AudioPlayer();
  bool sonando = false;
  String? tituloActual;
  double volumen = 0.5;
  bool _inicializado = false;

  void init() {
    if (_inicializado) return;
    _inicializado = true;
    player.setReleaseMode(ReleaseMode.loop);
    player.onPlayerStateChanged.listen((state) {
      sonando = state == PlayerState.playing;
      notifyListeners();
    });
  }

  Future<void> reproducirLocal(String ruta, String titulo) async {
    try {
      tituloActual = titulo;
      await player.stop();
      await player.setVolume(volumen);
      await player.play(DeviceFileSource(ruta));
      sonando = true;
      notifyListeners();
    } catch (e) {
      debugPrint('AudioGlobal.reproducirLocal error: $e');
    }
  }

  Future<void> reproducirUrl(String url, String titulo) async {
    try {
      tituloActual = titulo;
      await player.stop();
      await player.setVolume(volumen);
      await player.play(UrlSource(url));
      sonando = true;
      notifyListeners();
    } catch (e) {
      debugPrint('AudioGlobal.reproducirUrl error: $e');
    }
  }

  Future<void> pausarOReanudar() async {
    if (sonando) {
      await player.pause();
      sonando = false;
    } else if (tituloActual != null) {
      await player.resume();
      sonando = true;
    }
    notifyListeners();
  }

  Future<void> detener() async {
    await player.stop();
    sonando = false;
    tituloActual = null;
    notifyListeners();
  }

  Future<void> cambiarVolumen(double v) async {
    volumen = v.clamp(0.0, 1.0);
    await player.setVolume(volumen);
    notifyListeners();
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }
}
