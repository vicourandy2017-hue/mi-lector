import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../principal/pantalla_principal.dart';

class PantallaBienvenidaAnimada extends StatefulWidget {
  const PantallaBienvenidaAnimada({super.key});

  @override
  State<PantallaBienvenidaAnimada> createState() =>
      _PantallaBienvenidaAnimadaState();
}

class _PantallaBienvenidaAnimadaState extends State<PantallaBienvenidaAnimada>
    with TickerProviderStateMixin {
  static const String _textoCompleto = 'Mi Lector Pro';
  String   _textoMostrado = '';
  int      _charIndex     = 0;
  bool     _mostrarCursor = true;
  bool     _animacionLista = false;

  Timer?  _timerLetras;
  Timer?  _timerCursor;
  Timer?  _timerNavegar;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync   : this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();

    _iniciarAnimacionTexto();
    _iniciarCursorParpadeo();
  }

  void _iniciarAnimacionTexto() {
    _timerLetras = Timer.periodic(const Duration(milliseconds: 120), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_charIndex < _textoCompleto.length) {
        setState(() {
          _textoMostrado = _textoCompleto.substring(0, ++_charIndex);
        });
      } else {
        t.cancel();
        setState(() => _animacionLista = true);
        // Navegar 1.2 segundos después de completar el texto
        _timerNavegar = Timer(const Duration(milliseconds: 1200), _navegar);
      }
    });
  }

  void _iniciarCursorParpadeo() {
    _timerCursor = Timer.periodic(const Duration(milliseconds: 530), (_) {
      if (mounted) setState(() => _mostrarCursor = !_mostrarCursor);
    });
  }

  void _navegar() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 900),
        pageBuilder: (_, anim, __) => FadeTransition(
          opacity: anim,
          child: const PantallaPrincipalMiLector(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timerLetras?.cancel();
    _timerCursor?.cancel();
    _timerNavegar?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ícono
              Container(
                padding    : const EdgeInsets.all(24),
                decoration : BoxDecoration(
                  color        : ColoresApp.fondoTarjeta,
                  shape        : BoxShape.circle,
                  boxShadow    : [
                    BoxShadow(
                      color     : ColoresApp.acento.withAlpha(80),
                      blurRadius: 40,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: ColoresApp.acento,
                  size : 64,
                ),
              ),
              const SizedBox(height: 40),

              // Texto animado
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _textoMostrado,
                    style: const TextStyle(
                      color      : Colors.white,
                      fontSize   : 32,
                      fontWeight : FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  AnimatedOpacity(
                    opacity : _mostrarCursor && !_animacionLista ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 100),
                    child: const Text(
                      '|',
                      style: TextStyle(
                        color    : ColoresApp.acento,
                        fontSize : 34,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Subtítulo
              AnimatedOpacity(
                opacity : _animacionLista ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 600),
                child: const Text(
                  'Tu biblioteca personal de lectura',
                  style: TextStyle(
                    color    : Colors.white54,
                    fontSize : 15,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
