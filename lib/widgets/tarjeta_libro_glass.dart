import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../models/libro.dart';
import 'portada_pdf_widget.dart';

/// Tarjeta de libro deslumbrante con estilo Glassmorphic, portadas flotantes, 
/// degradados armoniosos y badges de formato (PDF, EPUB, AUDIO, VIDEO, DOCX).
class TarjetaLibroGlass extends StatelessWidget {
  final Libro libro;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final void Function(String rutaCache)? onPortadaGenerada;

  const TarjetaLibroGlass({
    super.key,
    required this.libro,
    required this.onTap,
    required this.onLongPress,
    this.onPortadaGenerada,
  });

  Color _colorBadgeFormat() {
    if (libro.esAudiolibro) return Colors.purpleAccent;
    if (libro.esVideo) return Colors.pinkAccent;
    if (libro.esEpub) return Colors.blueAccent;
    if (libro.esDocx) return Colors.lightBlue;
    return Colors.orangeAccent;
  }

  String _textoBadgeFormat() {
    if (libro.esAudiolibro) return '🎧 AUDIO';
    if (libro.esVideo) return '🎬 VIDEO';
    if (libro.esEpub) return '📖 EPUB';
    if (libro.esDocx) return '📝 WORD';
    return '📄 PDF';
  }

  IconData _iconoFormato() {
    if (libro.esAudiolibro) return Icons.headphones_rounded;
    if (libro.esVideo) return Icons.video_library_rounded;
    if (libro.esEpub) return Icons.auto_stories_rounded;
    if (libro.esDocx) return Icons.description_rounded;
    return Icons.picture_as_pdf_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: ColoresApp.fondoTarjeta.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: ColoresApp.acento.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Área de portada con efecto flotante
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              ColoresApp.fondoTarjeta,
                              ColoresApp.fondoPrincipal.withValues(alpha: 0.9),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: (!libro.esAudiolibro &&
                                !libro.esEpub &&
                                !libro.esVideo &&
                                !libro.esDocx)
                            ? PortadaPdfWidget(
                                libro: libro,
                                onPortadaGenerada: onPortadaGenerada,
                              )
                            : Center(
                                child: Icon(
                                  _iconoFormato(),
                                  size: 48,
                                  color: _colorBadgeFormat().withValues(alpha: 0.85),
                                ),
                              ),
                      ),
                    ),

                    // Soft Gradient Overlay inferior
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),

                    // Badge de formato superior (PDF, EPUB, etc.)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: _colorBadgeFormat().withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(color: Colors.black38, blurRadius: 4),
                          ],
                        ),
                        child: Text(
                          _textoBadgeFormat(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // Ícono de Favorito
                    if (libro.esFavorito)
                      const Positioned(
                        top: 8,
                        right: 8,
                        child: Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),

              // Información del libro inferior
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      libro.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          libro.categoria,
                          style: TextStyle(
                            color: ColoresApp.acento.withValues(alpha: 0.9),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (libro.ultimaPagina > 1 && !libro.leido)
                          Text(
                            'Pág. ${libro.ultimaPagina}',
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        else if (libro.leido)
                          const Text(
                            '✓ Leído',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
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
