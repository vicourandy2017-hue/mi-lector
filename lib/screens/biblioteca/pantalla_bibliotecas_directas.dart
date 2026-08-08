import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../web/pantalla_visor_web.dart';

class PantallaBibliotecasDirectas extends StatelessWidget {
  const PantallaBibliotecasDirectas({super.key});

  static const List<Map<String, dynamic>> _bibliotecas = [
    {
      'nombre': 'Alejandría',
      'descripcion': 'Miles de libros en español, acceso gratuito',
      'url': 'https://www.bibliotecaalejandria.com',
      'icono': Icons.auto_stories_rounded,
      'color': 0xFF0284C7,
    },
    {
      'nombre': 'Proyecto Gutenberg',
      'descripcion': 'Más de 70,000 libros en dominio público',
      'url': 'https://www.gutenberg.org',
      'icono': Icons.menu_book_rounded,
      'color': 0xFF059669,
    },
    {
      'nombre': 'Wikisource',
      'descripcion': 'Biblioteca de textos fuente libre',
      'url': 'https://es.wikisource.org',
      'icono': Icons.public_rounded,
      'color': 0xFF7C3AED,
    },
    {
      'nombre': 'Standard Ebooks',
      'descripcion': 'EPUBs de alta calidad y formatos libres',
      'url': 'https://standardebooks.org',
      'icono': Icons.star_rounded,
      'color': 0xFFD97706,
    },
    {
      'nombre': 'Open Library',
      'descripcion': 'Millones de libros digitalizados del Internet Archive',
      'url': 'https://openlibrary.org',
      'icono': Icons.library_books_rounded,
      'color': 0xFFDC2626,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🌐 Biblioteca Pública',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Fuentes gratuitas para descargar libros',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ..._bibliotecas.map((b) => _tarjetaBiblioteca(context, b)),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaBiblioteca(BuildContext context, Map<String, dynamic> b) {
    final color = Color(b['color'] as int);
    return Container(
      margin     : const EdgeInsets.only(bottom: 12),
      decoration : BoxDecoration(
        color        : ColoresApp.fondoTarjeta,
        borderRadius : BorderRadius.circular(16),
        border       : Border.all(color: color.withAlpha(80)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding    : const EdgeInsets.all(10),
          decoration : BoxDecoration(
            color        : color.withAlpha(30),
            shape        : BoxShape.circle,
          ),
          child: Icon(b['icono'] as IconData, color: color, size: 24),
        ),
        title: Text(
          b['nombre'] as String,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          b['descripcion'] as String,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: Icon(Icons.open_in_browser_rounded, color: color, size: 20),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PantallaVisorWebCompleto(
              url   : b['url'] as String,
              titulo: b['nombre'] as String,
            ),
          ),
        ),
      ),
    );
  }
}
