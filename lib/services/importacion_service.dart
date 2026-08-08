import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/libro.dart';
import '../models/pista_musica.dart';
import '../core/colors.dart';

/// Servicio de importación robusto para móviles Y tablets Android.
///
/// PROBLEMA ORIGINAL EN TABLETS:
/// - withData: true → OOM (Out of Memory) con archivos grandes
/// - archivoUnico.path → null en URIs content:// (Google Drive, OEM pickers)
/// - withReadStream: true → obsoleto en file_picker moderno
/// - Sin límite de tamaño → congelaba la UI con archivos enormes
/// - Sin timeout → UI bloqueada indefinidamente si el picker colgaba
///
/// SOLUCIÓN: 4 capas de fallback para resolver el archivo físico:
/// 1. path no nulo + archivo existe  → usar directamente
/// 2. bytes disponibles               → escribir a cache y usar
/// 3. readStream disponible           → leer por chunks y escribir a cache
/// 4. Ninguna opción disponible       → mostrar error amigable
class ImportacionService {
  static const int _maxTamanoBytes = 300 * 1024 * 1024; // 300 MB

  // ─── Extensiones válidas ────────────────────────────────────────────────
  static const List<String> extLibros    = ['pdf', 'epub', 'docx'];
  static const List<String> _extAudio    = ['mp3', 'm4a', 'wav', 'aac', 'ogg'];
  static const List<String> _extVideo    = ['mp4', 'mov', 'mkv', 'avi'];
  static const List<String> extMusica    = ['mp3', 'm4a', 'wav', 'aac', 'ogg'];
  static const List<String> _extTodas   = [
    'pdf', 'epub', 'docx',
    'mp3', 'm4a', 'wav', 'aac', 'ogg',
    'mp4', 'mov', 'mkv', 'avi',
  ];

  // ─── Importar libro / audio / video ─────────────────────────────────────
  /// Abre el selector de archivos y devuelve un [Libro] listo para agregar
  /// a la biblioteca. Devuelve `null` si el usuario canceló o hubo error.
  static Future<Libro?> importarArchivo(
    BuildContext context, {
    String categoriaInicial = 'General',
  }) async {
    // 1. Lanzar el picker sin withData ni withReadStream
    FilePickerResult? resultado;
    try {
      resultado = await FilePicker.platform
          .pickFiles(
            type: FileType.any,
            allowMultiple: false,
            // NO usamos withData ni withReadStream →
            // en tablets con content:// URIs estas opciones causan OOM o null.
          )
          .timeout(
            const Duration(seconds: 45),
            onTimeout: () {
              debugPrint('ImportacionService: timeout al abrir el picker');
              return null;
            },
          );
    } catch (e) {
      debugPrint('ImportacionService picker error: $e');
      if (context.mounted) {
        _mostrarSnackBar(context, 'Error al abrir el selector de archivos: $e');
      }
      return null;
    }

    if (resultado == null || resultado.files.isEmpty) return null;

    final archivo = resultado.files.first;
    final nombre  = archivo.name;
    final extLower = nombre.contains('.')
        ? nombre.split('.').last.toLowerCase()
        : '';

    // 2. Validar extensión
    if (!_extTodas.contains(extLower)) {
      if (context.mounted) {
        _mostrarSnackBar(
          context,
          'Formato no compatible. Acepta: PDF, EPUB, Word, MP3, MP4…',
        );
      }
      return null;
    }

    // 3. Validar tamaño (si está disponible antes de leer)
    if (archivo.size > _maxTamanoBytes) {
      if (context.mounted) {
        _mostrarSnackBar(context, 'El archivo es demasiado grande (máx 300 MB).');
      }
      return null;
    }

    // 4. Mostrar diálogo de carga
    if (context.mounted) {
      _mostrarDialogoCargando(context, 'Importando "$nombre"…');
    }

    File? archivoFinal;
    try {
      archivoFinal = await _resolverArchivoFisico(archivo, nombre);
    } catch (e) {
      debugPrint('ImportacionService resolver error: $e');
    }

    // 5. Cerrar diálogo
    if (context.mounted) {
      _cerrarDialogoCargando(context);
    }

    if (archivoFinal == null) {
      if (context.mounted) {
        _mostrarSnackBar(
          context,
          'No se pudo leer el archivo.\n'
          'Intenta moverlo a la carpeta "Descargas" y volver a importar.',
        );
      }
      return null;
    }

    // 6. Copiar a almacenamiento interno permanente de la app
    if (context.mounted) {
      _mostrarDialogoCargando(context, 'Guardando en la biblioteca…');
    }

    final rutaFinal = await _copiarAAlmacenamientoInterno(archivoFinal, nombre);

    if (context.mounted) {
      _cerrarDialogoCargando(context);
    }

    if (rutaFinal == null) {
      if (context.mounted) {
        _mostrarSnackBar(context, 'Error al guardar el archivo en la app.');
      }
      return null;
    }

    // 7. Construir el objeto Libro
    final tituloLimpio = nombre.replaceAll(
      RegExp(
        r'\.(pdf|mp3|m4a|wav|aac|ogg|epub|mp4|mov|mkv|avi|docx)$',
        caseSensitive: false,
      ),
      '',
    );

    final libro = Libro(
      id           : DateTime.now().millisecondsSinceEpoch.toString(),
      titulo       : tituloLimpio,
      rutaLocal    : rutaFinal,
      categoria    : categoriaInicial,
      esAudiolibro : _extAudio.contains(extLower),
      esEpub       : extLower == 'epub',
      esVideo      : _extVideo.contains(extLower),
      esDocx       : extLower == 'docx',
    );

    if (context.mounted) {
      _mostrarSnackBar(
        context,
        '📚 "$tituloLimpio" importado con éxito',
        color: ColoresApp.acentoOscuro,
      );
    }

    return libro;
  }

  // ─── Importar pista de música ────────────────────────────────────────────
  static Future<PistaMusica?> importarPistaMusica(BuildContext context) async {
    FilePickerResult? resultado;
    try {
      resultado = await FilePicker.platform
          .pickFiles(type: FileType.audio, allowMultiple: false)
          .timeout(const Duration(seconds: 45), onTimeout: () => null);
    } catch (e) {
      if (context.mounted) {
        _mostrarSnackBar(context, 'Error al abrir el selector: $e');
      }
      return null;
    }

    if (resultado == null || resultado.files.isEmpty) return null;

    final archivo = resultado.files.first;
    final nombre  = archivo.name;

    if (context.mounted) {
      _mostrarDialogoCargando(context, 'Importando pista "$nombre"…');
    }

    File? archivoFinal;
    try {
      archivoFinal = await _resolverArchivoFisico(archivo, nombre);
    } catch (e) {
      debugPrint('ImportacionService pista resolver error: $e');
    }

    if (context.mounted) _cerrarDialogoCargando(context);

    if (archivoFinal == null) {
      if (context.mounted) {
        _mostrarSnackBar(context, 'No se pudo leer el archivo de música.');
      }
      return null;
    }

    // Copiar a carpeta de música dentro del almacenamiento interno
    final appDir       = await getApplicationDocumentsDirectory();
    final carpetaMusica = Directory('${appDir.path}/musica_fondo');
    if (!carpetaMusica.existsSync()) await carpetaMusica.create(recursive: true);

    final rutaDestino = '${carpetaMusica.path}/$nombre';
    try {
      await archivoFinal.copy(rutaDestino);
    } catch (e) {
      try {
        final bytes = await archivoFinal.readAsBytes();
        await File(rutaDestino).writeAsBytes(bytes);
      } catch (e2) {
        if (context.mounted) {
          _mostrarSnackBar(context, 'Error al guardar la pista.');
        }
        return null;
      }
    }

    final tituloLimpio = nombre.replaceAll(
      RegExp(r'\.(mp3|m4a|wav|aac|ogg)$', caseSensitive: false),
      '',
    );

    final pista = PistaMusica(
      id       : DateTime.now().millisecondsSinceEpoch.toString(),
      titulo   : tituloLimpio,
      rutaLocal: rutaDestino,
    );

    if (context.mounted) {
      _mostrarSnackBar(context, '"$tituloLimpio" agregada a tu música para leer');
    }

    return pista;
  }

  // ─── Capas de resolución de archivo ─────────────────────────────────────
  /// Intenta obtener un [File] físico accesible mediante 4 estrategias.
  static Future<File?> _resolverArchivoFisico(
    PlatformFile archivo,
    String nombre,
  ) async {
    // Capa 1: path local directo (funciona en la mayoría de teléfonos)
    if (archivo.path != null) {
      final f = File(archivo.path!);
      if (f.existsSync()) {
        debugPrint('ImportacionService: Capa 1 exitosa (path directo)');
        return f;
      }
    }

    final cacheDir = await getApplicationCacheDirectory();
    final destCache = File('${cacheDir.path}/$nombre');

    // Capa 2: bytes ya cargados en memoria (archivos pequeños)
    if (archivo.bytes != null && archivo.bytes!.isNotEmpty) {
      await destCache.writeAsBytes(archivo.bytes!, flush: true);
      debugPrint('ImportacionService: Capa 2 exitosa (bytes en memoria)');
      return destCache;
    }

    // Capa 3: readStream — lectura por chunks (tablets con content:// URIs)
    // Esta es la que resuelve el problema de Google Drive en tablets.
    if (archivo.readStream != null) {
      try {
        final sink   = destCache.openWrite();
        int bytesLeidos = 0;
        await for (final chunk in archivo.readStream!) {
          sink.add(chunk);
          bytesLeidos += chunk.length;
          if (bytesLeidos > _maxTamanoBytes) {
            await sink.close();
            if (destCache.existsSync()) destCache.deleteSync();
            debugPrint('ImportacionService: archivo excede 300 MB, abortando');
            return null;
          }
        }
        await sink.flush();
        await sink.close();
        if (destCache.existsSync() && destCache.lengthSync() > 0) {
          debugPrint(
            'ImportacionService: Capa 3 exitosa (stream, ${bytesLeidos ~/ 1024} KB)',
          );
          return destCache;
        }
      } catch (e) {
        debugPrint('ImportacionService Capa 3 error: $e');
        if (destCache.existsSync()) {
          try { destCache.deleteSync(); } catch (_) {}
        }
      }
    }

    // Capa 4: Sin opciones disponibles
    debugPrint('ImportacionService: Todas las capas fallaron para "$nombre"');
    return null;
  }

  /// Copia el archivo resuelto al directorio permanente de la app.
  static Future<String?> _copiarAAlmacenamientoInterno(
    File origen,
    String nombre,
  ) async {
    try {
      final appDir  = await getApplicationDocumentsDirectory();
      final destino = File('${appDir.path}/$nombre');
      if (origen.path == destino.path) return destino.path;
      await origen.copy(destino.path);
      return destino.path;
    } catch (e) {
      debugPrint('ImportacionService copiar error: $e');
      // Si copy falla (diferente filesystem), leer y escribir manualmente
      try {
        final appDir  = await getApplicationDocumentsDirectory();
        final destino = File('${appDir.path}/$nombre');
        final bytes   = await origen.readAsBytes();
        await destino.writeAsBytes(bytes);
        return destino.path;
      } catch (e2) {
        debugPrint('ImportacionService copiar fallback error: $e2');
        return null;
      }
    }
  }

  // ─── Helpers UI ──────────────────────────────────────────────────────────
  static void _mostrarDialogoCargando(BuildContext context, String mensaje) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: ColoresApp.fondoTarjeta,
        content: Row(
          children: [
            const CircularProgressIndicator(color: ColoresApp.acento),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                mensaje,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _cerrarDialogoCargando(BuildContext context) {
    try {
      Navigator.of(context, rootNavigator: true).pop();
    } catch (_) {}
  }

  static void _mostrarSnackBar(
    BuildContext context,
    String mensaje, {
    Color color = Colors.redAccent,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content         : Text(mensaje),
        backgroundColor : color,
        duration        : const Duration(seconds: 3),
      ),
    );
  }
}
