import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/colors.dart';
import '../../models/libro.dart';
import '../../models/ajustes_app.dart';
import '../../models/pista_musica.dart';
import '../../widgets/mini_reproductor_widget.dart';

class PantallaLectorPDF extends StatefulWidget {
  final Libro libro;
  final AjustesApp ajustes;
  final VoidCallback onCambio;
  final List<PistaMusica> pistasMusica;

  const PantallaLectorPDF({
    super.key,
    required this.libro,
    required this.ajustes,
    required this.onCambio,
    this.pistasMusica = const [],
  });

  @override
  State<PantallaLectorPDF> createState() => _PantallaLectorPDFState();
}

class _PantallaLectorPDFState extends State<PantallaLectorPDF> {
  int _paginaActual = 1;
  int _totalPaginas = 1;
  bool _cargandoDoc = true;
  bool _mostrarControles = true;
  bool _estaLeyendoVoz = false;
  PDFViewController? _pdfViewController;

  late AudioPlayer _playerEfectoPagina;
  late FlutterTts _tts;

  @override
  void initState() {
    super.initState();
    _paginaActual = widget.libro.ultimaPagina > 0 ? widget.libro.ultimaPagina : 1;
    _playerEfectoPagina = AudioPlayer();
    _initTts();
  }

  void _initTts() {
    _tts = FlutterTts();
    _tts.setLanguage('es-ES');
    _tts.setSpeechRate(widget.ajustes.velocidadVoz);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _estaLeyendoVoz = false);
    });
  }

  Future<void> _reproducirSonidoPagina() async {
    if (!widget.ajustes.sonidoActivado) return;
    try {
      await _playerEfectoPagina.stop();
      await _playerEfectoPagina.setVolume(widget.ajustes.volumenEfecto);
      await _playerEfectoPagina.play(AssetSource('sounds/effect_1.mp3'));
    } catch (_) {}
  }

  void _paginaAnterior() {
    if (_paginaActual > 1 && _pdfViewController != null) {
      _pdfViewController!.setPage(_paginaActual - 2);
    }
  }

  void _paginaSiguiente() {
    if (_paginaActual < _totalPaginas && _pdfViewController != null) {
      _pdfViewController!.setPage(_paginaActual);
    }
  }

  void _guardarProgreso() {
    widget.libro.ultimaPagina = _paginaActual;
    widget.onCambio();
  }

  void _agregarMarcador() {
    showDialog(
      context: context,
      builder: (_) {
        final ctrl = TextEditingController(text: 'Página $_paginaActual');
        return AlertDialog(
          backgroundColor: ColoresApp.fondoTarjeta,
          title: const Text('Nuevo marcador', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: ctrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: ColoresApp.acento)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: ColoresApp.acento),
              onPressed: () {
                widget.libro.marcadores.add(Marcador(
                  pagina: _paginaActual,
                  etiqueta: ctrl.text.trim(),
                ));
                widget.onCambio();
                Navigator.pop(context);
              },
              child: const Text('Guardar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _playerEfectoPagina.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colFondo = widget.ajustes.modoSepia
        ? const Color(0xFFF4ECD8)
        : widget.ajustes.modoOscuro
            ? ColoresApp.fondoPrincipal
            : const Color(0xFFF0F0F0);

    return Opacity(
      opacity: widget.ajustes.nivelBrillo.clamp(0.3, 1.0),
      child: Scaffold(
        backgroundColor: colFondo,
        appBar: _mostrarControles
            ? AppBar(
                backgroundColor: ColoresApp.fondoDrawer,
                elevation: 0,
                iconTheme: const IconThemeData(color: Colors.white),
                title: Text(
                  widget.libro.titulo,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  IconButton(
                    tooltip: 'Agregar marcador',
                    icon: const Icon(Icons.bookmark_add_rounded, color: Colors.white70),
                    onPressed: _agregarMarcador,
                  ),
                  IconButton(
                    tooltip: _estaLeyendoVoz ? 'Detener voz' : 'Leer en voz alta',
                    icon: Icon(
                      _estaLeyendoVoz ? Icons.stop_circle_rounded : Icons.record_voice_over_rounded,
                      color: _estaLeyendoVoz ? Colors.redAccent : Colors.white70,
                    ),
                    onPressed: () {
                      if (_estaLeyendoVoz) {
                        _tts.stop();
                        setState(() => _estaLeyendoVoz = false);
                      } else {
                        setState(() => _estaLeyendoVoz = true);
                        _tts.speak('Página $_paginaActual de $_totalPaginas');
                      }
                    },
                  ),
                  MiniReproductorMusicaFondo(pistas: widget.pistasMusica),
                  const SizedBox(width: 6),
                ],
              )
            : null,
        body: GestureDetector(
          onTap: () => setState(() => _mostrarControles = !_mostrarControles),
          child: Stack(
            children: [
              PDFView(
                filePath: widget.libro.rutaLocal,
                defaultPage: widget.libro.ultimaPagina > 0 ? widget.libro.ultimaPagina - 1 : 0,
                enableSwipe: true,
                swipeHorizontal: true,
                autoSpacing: true,
                pageFling: true,
                onViewCreated: (PDFViewController controller) {
                  _pdfViewController = controller;
                },
                onRender: (pages) {
                  if (mounted) {
                    setState(() {
                      _totalPaginas = pages ?? 1;
                      _cargandoDoc = false;
                    });
                  }
                },
                onPageChanged: (page, total) {
                  if (page != null && mounted) {
                    setState(() {
                      _paginaActual = page + 1;
                      _totalPaginas = total ?? _totalPaginas;
                    });
                    _reproducirSonidoPagina();
                    _guardarProgreso();
                  }
                },
                onError: (error) {
                  if (mounted) setState(() => _cargandoDoc = false);
                },
              ),
              if (_cargandoDoc)
                const Center(
                  child: CircularProgressIndicator(color: ColoresApp.acento),
                ),
              if (_mostrarControles)
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: ColoresApp.fondoTarjeta.withAlpha(220),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: ColoresApp.acento.withAlpha(80)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 18),
                              onPressed: _paginaAnterior,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                '$_paginaActual / $_totalPaginas',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
                              onPressed: _paginaSiguiente,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
