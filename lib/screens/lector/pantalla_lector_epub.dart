import 'dart:io';
import 'package:epub_parser/epub_parser.dart' as epub;
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/colors.dart';
import '../../models/libro.dart';
import '../../models/pista_musica.dart';
import '../../widgets/mini_reproductor_widget.dart';

class PantallaLectorEpub extends StatefulWidget {
  final Libro libro;
  final bool modoOscuro;
  final bool modoSepia;
  final double brillo;
  final double velocidadVoz;
  final List<PistaMusica> pistasMusica;
  final VoidCallback? onCambio;

  const PantallaLectorEpub({
    super.key,
    required this.libro,
    required this.modoOscuro,
    required this.modoSepia,
    required this.brillo,
    required this.velocidadVoz,
    this.pistasMusica = const [],
    this.onCambio,
  });

  @override
  State<PantallaLectorEpub> createState() => _PantallaLectorEpubState();
}

class _PantallaLectorEpubState extends State<PantallaLectorEpub> {
  epub.EpubBook?  _epubBook;
  List<String>    _capitulos    = [];
  int             _capActual    = 0;
  bool            _cargando     = true;
  bool            _error        = false;
  bool            _mostrarCtrl  = true;
  bool            _estaLeyendo  = false;
  double          _tamanoFuente = 16.0;
  late FlutterTts _tts;
  final ScrollController _scroll = ScrollController();

  Color get _colFondo {
    if (widget.modoSepia)  return const Color(0xFFF4ECD8);
    if (widget.modoOscuro) return const Color(0xFF121212);
    return const Color(0xFFF5F5F5);
  }

  Color get _colTexto {
    if (widget.modoSepia)  return Colors.black87;
    if (widget.modoOscuro) return Colors.white70;
    return Colors.black87;
  }

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _tts.setLanguage('es-ES');
    _tts.setSpeechRate(widget.velocidadVoz);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _estaLeyendo = false);
    });
    _cargarEpub();
  }

  Future<void> _cargarEpub() async {
    try {
      final bytes = await File(widget.libro.rutaLocal).readAsBytes();
      final book  = await epub.EpubReader.readBook(bytes);
      final caps  = book.Chapters ?? [];
      setState(() {
        _epubBook  = book;
        _capitulos = caps.map((c) => c.HtmlContent ?? '').toList();
        _capActual = widget.libro.ultimaPagina.clamp(0, _capitulos.length - 1);
        _cargando  = false;
      });
    } catch (e) {
      if (mounted) setState(() { _cargando = false; _error = true; });
    }
  }

  void _ttsToggle() async {
    if (_estaLeyendo) {
      await _tts.stop();
      setState(() => _estaLeyendo = false);
    } else {
      // Extraer texto plano del HTML del capítulo
      final html = _capitulos[_capActual];
      final texto = html.replaceAll(RegExp(r'<[^>]+>'), ' ').trim();
      setState(() => _estaLeyendo = true);
      await _tts.speak(texto);
    }
  }

  void _irCapitulo(int idx) {
    setState(() { _capActual = idx; _estaLeyendo = false; });
    _tts.stop();
    widget.libro.ultimaPagina = idx;
    widget.onCambio?.call();
    _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _tts.stop();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.brillo.clamp(0.3, 1.0),
      child: Scaffold(
        backgroundColor: _colFondo,
        appBar: _mostrarCtrl ? _buildBar() : null,
        body: _buildBody(),
        floatingActionButton: _mostrarCtrl ? _buildFab() : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  PreferredSizeWidget _buildBar() {
    return AppBar(
      backgroundColor: ColoresApp.fondoDrawer,
      iconTheme      : const IconThemeData(color: Colors.white),
      title: Text(widget.libro.titulo,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        // Índice de capítulos
        IconButton(
          tooltip  : 'Capítulos',
          icon     : const Icon(Icons.list_rounded, color: Colors.white70),
          onPressed: _mostrarIndice,
        ),
        // Tamaño fuente
        IconButton(
          icon: const Icon(Icons.text_decrease_rounded, size: 20, color: Colors.white70),
          onPressed: () => setState(() => _tamanoFuente = (_tamanoFuente - 2).clamp(12, 32)),
        ),
        IconButton(
          icon: const Icon(Icons.text_increase_rounded, size: 20, color: Colors.white70),
          onPressed: () => setState(() => _tamanoFuente = (_tamanoFuente + 2).clamp(12, 32)),
        ),
        // TTS
        IconButton(
          icon: Icon(_estaLeyendo
            ? Icons.stop_circle_rounded : Icons.record_voice_over_rounded,
            color: _estaLeyendo ? Colors.redAccent : Colors.white70, size: 22),
          onPressed: _capitulos.isEmpty ? null : _ttsToggle,
        ),
        MiniReproductorMusicaFondo(pistas: widget.pistasMusica),
        const SizedBox(width: 6),
      ],
    );
  }

  Widget _buildBody() {
    if (_cargando) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: ColoresApp.acento),
          const SizedBox(height: 16),
          Text('Cargando EPUB…', style: TextStyle(color: _colTexto.withAlpha(180))),
        ],
      ));
    }
    if (_error || _capitulos.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 56),
          const SizedBox(height: 16),
          const Text('No se pudo cargar el EPUB.', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ColoresApp.acento),
            onPressed: _cargarEpub,
            child: const Text('Reintentar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ));
    }

    return GestureDetector(
      onTap: () => setState(() => _mostrarCtrl = !_mostrarCtrl),
      child: SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Html(
          data: _capitulos[_capActual],
          style: {
            'body': Style(
              color     : _colTexto,
              fontSize  : FontSize(_tamanoFuente),
              lineHeight: const LineHeight(1.7),
              backgroundColor: _colFondo,
            ),
            'p': Style(margin: Margins.only(bottom: 12)),
          },
        ),
      ),
    );
  }

  Widget _buildFab() {
    return Container(
      decoration: BoxDecoration(
        color        : ColoresApp.fondoTarjeta.withAlpha(210),
        borderRadius : BorderRadius.circular(30),
        border       : Border.all(color: ColoresApp.acento.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Anterior
          IconButton(
            icon     : const Icon(Icons.arrow_back_ios_rounded, size: 18),
            color    : _capActual > 0 ? ColoresApp.acento : Colors.white24,
            onPressed: _capActual > 0 ? () => _irCapitulo(_capActual - 1) : null,
          ),
          Text('${_capActual + 1}/${_capitulos.length}',
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
          IconButton(
            icon     : const Icon(Icons.arrow_forward_ios_rounded, size: 18),
            color    : _capActual < _capitulos.length - 1 ? ColoresApp.acento : Colors.white24,
            onPressed: _capActual < _capitulos.length - 1
                ? () => _irCapitulo(_capActual + 1) : null,
          ),
        ],
      ),
    );
  }

  void _mostrarIndice() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ColoresApp.fondoTarjeta,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        final caps = _epubBook?.Chapters ?? [];
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Capítulos',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: caps.length,
                itemBuilder: (_, i) => ListTile(
                  leading: Icon(Icons.article_rounded,
                    color: i == _capActual ? ColoresApp.acento : Colors.white38, size: 18),
                  title: Text(caps[i].Title ?? 'Capítulo ${i + 1}',
                    style: TextStyle(
                      color: i == _capActual ? ColoresApp.acento : Colors.white70,
                      fontWeight: i == _capActual ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 13,
                    )),
                  onTap: () { Navigator.pop(context); _irCapitulo(i); },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
