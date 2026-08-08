import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import '../../core/colors.dart';
import '../../models/libro.dart';

/// Muestra la portada (primera página) de un PDF en miniatura.
/// Usa [AutomaticKeepAliveClientMixin] para no regenerar al hacer scroll.
class PortadaPdfWidget extends StatefulWidget {
  final Libro libro;
  final void Function(String ruta)? onPortadaGenerada;

  const PortadaPdfWidget({
    super.key,
    required this.libro,
    this.onPortadaGenerada,
  });

  @override
  State<PortadaPdfWidget> createState() => _PortadaPdfWidgetState();
}

class _PortadaPdfWidgetState extends State<PortadaPdfWidget>
    with AutomaticKeepAliveClientMixin {
  bool   _cargando = true;
  String? _rutaImagen;
  bool   _error = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _cargarPortada();
  }

  Future<void> _cargarPortada() async {
    // Si ya hay una portada en caché, usarla directamente
    if (widget.libro.rutaPortadaCache != null) {
      final cacheFile = File(widget.libro.rutaPortadaCache!);
      if (cacheFile.existsSync()) {
        if (mounted) setState(() { _rutaImagen = widget.libro.rutaPortadaCache; _cargando = false; });
        return;
      }
    }

    try {
      final doc  = await PdfDocument.openFile(widget.libro.rutaLocal);
      final page = await doc.getPage(1);
      final img  = await page.render(
        width : page.width  * 2,
        height: page.height * 2,
      );
      final bytes = img?.bytes;
      await page.close();
      await doc.close();

      if (bytes == null || bytes.isEmpty) {
        if (mounted) setState(() { _cargando = false; _error = true; });
        return;
      }

      // Guardar en caché
      final cacheDir   = Directory(
        '${File(widget.libro.rutaLocal).parent.path}/.portadas_cache',
      );
      if (!cacheDir.existsSync()) await cacheDir.create(recursive: true);
      final cacheFile = File('${cacheDir.path}/${widget.libro.id}.png');
      await cacheFile.writeAsBytes(bytes);

      widget.onPortadaGenerada?.call(cacheFile.path);

      if (mounted) {
        setState(() { _rutaImagen = cacheFile.path; _cargando = false; });
      }
    } catch (e) {
      debugPrint('PortadaPdfWidget error: $e');
      if (mounted) setState(() { _cargando = false; _error = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_cargando) {
      return Container(
        color : ColoresApp.fondoTarjeta,
        child : const Center(
          child: SizedBox(
            width: 22, height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color      : ColoresApp.acento,
            ),
          ),
        ),
      );
    }

    if (_error || _rutaImagen == null) {
      return Container(
        color: ColoresApp.fondoTarjeta,
        child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 40),
      );
    }

    return Image.file(
      File(_rutaImagen!),
      fit         : BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: ColoresApp.fondoTarjeta,
        child: const Icon(Icons.broken_image_rounded, color: Colors.white38, size: 40),
      ),
    );
  }
}
