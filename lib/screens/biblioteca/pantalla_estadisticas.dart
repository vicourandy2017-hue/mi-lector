import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../models/libro.dart';
import '../../models/pista_musica.dart';

class PantallaEstadisticas extends StatelessWidget {
  final List<Libro> libros;
  final List<PistaMusica> pistasMusica;

  const PantallaEstadisticas({
    super.key,
    required this.libros,
    this.pistasMusica = const [],
  });

  @override
  Widget build(BuildContext context) {
    final leidos      = libros.where((l) => l.leido).length;
    final enLectura   = libros.where((l) => l.ultimaPagina > 1 && !l.leido).length;
    final pdfs        = libros.where((l) => !l.esAudiolibro && !l.esVideo && !l.esEpub && !l.esDocx).length;
    final epubs       = libros.where((l) => l.esEpub).length;
    final docs        = libros.where((l) => l.esDocx).length;
    final audiolibros = libros.where((l) => l.esAudiolibro).length;
    final videos      = libros.where((l) => l.esVideo).length;
    final total       = libros.length;
    final favoritos   = libros.where((l) => l.esFavorito).length;
    final porLeer     = libros.where((l) => l.porLeer && !l.leido).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 Mis Estadísticas',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              physics   : const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing : 12,
              childAspectRatio: 1.4,
              children: [
                _cardStat('Total de archivos', total.toString(),        Icons.library_books_rounded,  ColoresApp.acento),
                _cardStat('Leídos',            leidos.toString(),        Icons.check_circle_rounded,   Colors.green),
                _cardStat('En lectura',        enLectura.toString(),     Icons.menu_book_rounded,      Colors.orange),
                _cardStat('Por leer',          porLeer.toString(),       Icons.bookmark_rounded,        Colors.purple),
                _cardStat('Favoritos',         favoritos.toString(),     Icons.star_rounded,            Colors.amber),
                _cardStat('PDFs',              pdfs.toString(),          Icons.picture_as_pdf_rounded,  Colors.redAccent),
                _cardStat('EPUBs',             epubs.toString(),         Icons.auto_stories_rounded,    Colors.lightBlue),
                _cardStat('Word (DOCX)',       docs.toString(),          Icons.description_rounded,     Colors.blue),
                _cardStat('Audiolibros',       audiolibros.toString(),   Icons.headphones_rounded,      Colors.teal),
                _cardStat('Videos',            videos.toString(),        Icons.videocam_rounded,        Colors.pink),
                _cardStat('Pistas música',     pistasMusica.length.toString(), Icons.music_note_rounded, Colors.deepPurple),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardStat(String label, String valor, IconData icono, Color color) {
    return Container(
      padding    : const EdgeInsets.all(14),
      decoration : BoxDecoration(
        color        : ColoresApp.fondoTarjeta,
        borderRadius : BorderRadius.circular(16),
        border       : Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment : MainAxisAlignment.spaceBetween,
        children: [
          Icon(icono, color: color, size: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(valor,
                style: TextStyle(
                  color      : color,
                  fontSize   : 24,
                  fontWeight : FontWeight.w800,
                ),
              ),
              Text(label,
                style: const TextStyle(
                  color   : Colors.white54,
                  fontSize: 11,
                ),
                maxLines : 1,
                overflow : TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
