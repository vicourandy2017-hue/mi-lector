import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:xml/xml.dart' as xml;
import '../../core/colors.dart';
import '../../models/libro.dart';
import '../../models/pista_musica.dart';
import '../../widgets/mini_reproductor_widget.dart';

// ─── Función top-level para compute() ─────────────────────────────────────
/// Extrae el texto plano de los bytes de un archivo DOCX.
/// Ejecutada en un isolate separado para no bloquear la UI en tablets.
String analizarDocxBytes(List<int> bytes) {
  try {
    final archive  = ZipDecoder().decodeBytes(bytes);
    final docEntry = archive.findFile('word/document.xml');
    if (docEntry == null) return '';

    final docXml = utf8.decode(docEntry.content as List<int>);
    final document = xml.XmlDocument.parse(docXml);

    // Extraer texto respetando párrafos
    final buffer = StringBuffer();
    for (final parrafo in document.findAllElements('w:p')) {
      final textoParrafo = parrafo
          .findAllElements('w:t')
          .map((e) => e.innerText)
          .join();
      if (textoParrafo.isNotEmpty) {
        buffer.writeln(textoParrafo);
        buffer.writeln(); // Doble salto entre párrafos para legibilidad
      }
    }
    return buffer.toString().trim();
  } catch (e) {
    debugPrint('analizarDocxBytes error: $e');
    return '';
  }
}

// ─── Pantalla ──────────────────────────────────────────────────────────────
class PantallaLectorDocx extends StatefulWidget {
  final Libro libro;
  final bool modoOscuro;
  final bool modoSepia;
  final double brillo;
  final double velocidadVoz;
  final List<PistaMusica> pistasMusica;
  final VoidCallback? onCambio;

  const PantallaLectorDocx({
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
  State<PantallaLectorDocx> createState() => _PantallaLectorDocxState();
}

class _PantallaLectorDocxState extends State<PantallaLectorDocx> {
  // ── Estado ──────────────────────────────────────────────────────────────
  String  _textoDocumento  = '';
  bool    _cargando        = true;
  bool    _errorCarga      = false;
  bool    _mostrarControles = true;
  bool    _estaLeyendoVoz  = false;
  double  _tamanoFuente    = 16.0;
  late    FlutterTts _tts;
  final   ScrollController _scrollCtrl = ScrollController();

  // ── Colores dinámicos según modo ─────────────────────────────────────────
  Color get _colorFondo {
    if (widget.modoSepia)   return const Color(0xFFF4ECD8);
    if (widget.modoOscuro)  return const Color(0xFF121212);
    return const Color(0xFFF5F5F5);
  }

  Color get _colorTexto {
    if (widget.modoSepia)   return Colors.black87;
    if (widget.modoOscuro)  return Colors.white70;
    return Colors.black87;
  }

  Color get _colorAppBar {
    if (widget.modoSepia)   return const Color(0xFFD4B896);
    if (widget.modoOscuro)  return const Color(0xFF1C1C1E);
    return const Color(0xFF2C6E8A);
  }

  // ── Ciclo de vida ────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initTts();
    _cargarDocumento();
  }

  void _initTts() {
    _tts = FlutterTts();
    _tts.setLanguage('es-ES');
    _tts.setSpeechRate(widget.velocidadVoz);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _estaLeyendoVoz = false);
    });
  }

  Future<void> _cargarDocumento() async {
    setState(() { _cargando = true; _errorCarga = false; });
    try {
      final archivo = File(widget.libro.rutaLocal);
      if (!archivo.existsSync()) {
        setState(() { _cargando = false; _errorCarga = true; });
        return;
      }
      final bytes    = await archivo.readAsBytes();
      // Procesamos en un isolate para no congelar la UI
      final texto    = await compute(analizarDocxBytes, bytes.toList());
      if (mounted) {
        setState(() {
          _textoDocumento = texto.isEmpty
              ? '[El documento parece estar vacío o cifrado]'
              : texto;
          _cargando = false;
        });
      }
    } catch (e) {
      debugPrint('PantallaLectorDocx cargar error: $e');
      if (mounted) setState(() { _cargando = false; _errorCarga = true; });
    }
  }

  void _toggleTts() async {
    if (_estaLeyendoVoz) {
      await _tts.stop();
      setState(() => _estaLeyendoVoz = false);
    } else {
      setState(() => _estaLeyendoVoz = true);
      await _tts.setSpeechRate(widget.velocidadVoz);
      await _tts.speak(_textoDocumento);
    }
  }

  void _ajustarFuente(double delta) {
    setState(() {
      _tamanoFuente = (_tamanoFuente + delta).clamp(12.0, 32.0);
    });
  }

  void _buscarEnWeb(String query) {
    Navigator.pushNamed(
      context,
      '/visor_web',
      arguments: 'https://es.wikipedia.org/wiki/${Uri.encodeComponent(query)}',
    );
  }

  @override
  void dispose() {
    _tts.stop();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.brillo.clamp(0.3, 1.0),
      child: Scaffold(
        backgroundColor: _colorFondo,
        appBar: _mostrarControles ? _buildAppBar() : null,
        body: _buildBody(),
        floatingActionButton: _mostrarControles ? _buildFab() : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _colorAppBar,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      title: Text(
        widget.libro.titulo,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        // Control de tamaño de fuente
        IconButton(
          tooltip : 'Letra más pequeña',
          icon    : const Icon(Icons.text_decrease_rounded, size: 20),
          onPressed: () => _ajustarFuente(-2),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Center(
            child: Text(
              '${_tamanoFuente.toInt()}px',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
        ),
        IconButton(
          tooltip : 'Letra más grande',
          icon    : const Icon(Icons.text_increase_rounded, size: 20),
          onPressed: () => _ajustarFuente(2),
        ),
        const SizedBox(width: 4),
        // TTS
        IconButton(
          tooltip: _estaLeyendoVoz ? 'Detener lectura' : 'Leer en voz alta',
          icon: Icon(
            _estaLeyendoVoz ? Icons.stop_circle_outlined : Icons.record_voice_over_rounded,
            color: _estaLeyendoVoz ? Colors.redAccent : Colors.white,
          ),
          onPressed: _cargando || _errorCarga ? null : _toggleTts,
        ),
        // Mini-player música
        MiniReproductorMusicaFondo(pistas: widget.pistasMusica),
        const SizedBox(width: 6),
      ],
    );
  }

  Widget _buildBody() {
    if (_cargando) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: ColoresApp.acento),
            const SizedBox(height: 16),
            Text(
              'Procesando documento…',
              style: TextStyle(color: _colorTexto.withAlpha(180)),
            ),
          ],
        ),
      );
    }

    if (_errorCarga) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 56),
            const SizedBox(height: 16),
            Text(
              'No se pudo abrir el documento.\nEl archivo puede estar dañado o cifrado.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _colorTexto),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: ColoresApp.acento),
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text('Reintentar', style: TextStyle(color: Colors.white)),
              onPressed: _cargarDocumento,
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _mostrarControles = !_mostrarControles),
      child: SelectionArea(
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          child: Text(
            _textoDocumento,
            style: TextStyle(
              color      : _colorTexto,
              fontSize   : _tamanoFuente,
              height     : 1.7,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFab() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color       : ColoresApp.fondoTarjeta.withAlpha(210),
        borderRadius: BorderRadius.circular(30),
        border      : Border.all(color: ColoresApp.acento.withAlpha(80)),
        boxShadow   : [
          BoxShadow(
            color: Colors.black.withAlpha(100),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _fabBoton(
            icono  : Icons.public_rounded,
            tooltip: 'Buscar en Wikipedia',
            onTap  : () {
              // Muestra un dialog para escribir la búsqueda
              _mostrarBusquedaWebDialog();
            },
          ),
          Container(width: 1, height: 36, color: ColoresApp.acento.withAlpha(60)),
          _fabBoton(
            icono  : Icons.translate_rounded,
            tooltip: 'Google Traductor',
            onTap  : () {
              final uri = 'https://translate.google.com/?sl=auto&tl=es&text='
                  '${Uri.encodeComponent(_textoDocumento.substring(0, _textoDocumento.length.clamp(0, 500)))}';
              Navigator.pushNamed(context, '/visor_web', arguments: uri);
            },
          ),
        ],
      ),
    );
  }

  Widget _fabBoton({
    required IconData icono,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Icon(icono, color: ColoresApp.acento, size: 20),
        ),
      ),
    );
  }

  void _mostrarBusquedaWebDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ColoresApp.fondoTarjeta,
        title: const Text('Buscar en Wikipedia', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Escribe un término...',
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: ColoresApp.acento),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: ColoresApp.acento, width: 2),
            ),
          ),
          onSubmitted: (v) {
            Navigator.pop(ctx);
            _buscarEnWeb(v.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ColoresApp.acento),
            onPressed: () {
              Navigator.pop(ctx);
              _buscarEnWeb(ctrl.text.trim());
            },
            child: const Text('Buscar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
