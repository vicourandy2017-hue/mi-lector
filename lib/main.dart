import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:epub_parser/epub_parser.dart' as epubx;
import 'package:flutter_html/flutter_html.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart' as xml;
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncpdf;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  runApp(const MiLectorApp());
}

// ---------------------------------------------------------
// UTILIDAD: DEBOUNCER PARA BÚSQUEDA OPTIMIZADA
// ---------------------------------------------------------
class Debouncer {
  final int milliseconds;
  Timer? _timer;
  Debouncer({required this.milliseconds});
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
  void dispose() {
    _timer?.cancel();
  }
}

// ---------------------------------------------------------
// CATÁLOGO DE EFECTOS DE PÁGINA (12 TONOS INTEGRADOS)
// ---------------------------------------------------------
class TonosEfectos {
  static const Map<String, String> lista = {
    'Effect 1': 'sounds/effect_1.mp3',
    'Effect 2': 'sounds/effect_2.mp3',
    'Effect 3': 'sounds/effect_3.mp3',
    'Effect 4': 'sounds/effect_4.mp3',
    'Effect 5': 'sounds/effect_5.mp3',
    'Effect 6': 'sounds/effect_6.mp3',
    'Effect 7': 'sounds/effect_7.mp3',
    'Effect 8': 'sounds/effect_8.mp3',
    'Effect 9': 'sounds/effect_9.mp3',
    'Effect 10': 'sounds/effect_10.mp3',
    'Effect 11': 'sounds/effect_11.mp3',
    'Effect 12': 'sounds/effect_12.mp3',
  };
}

// ---------------------------------------------------------
// FUNCIÓN EN SEGUNDO PLANO PARA PROCESAR WORD SIN CONGELAR
// ---------------------------------------------------------
String analizarDocxBytes(List<int> bytes) {
  try {
    final archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? xmlFile = archive.findFile('word/document.xml');
    if (xmlFile == null) {
      for (var file in archive) {
        if (file.name.toLowerCase().endsWith('document.xml')) {
          xmlFile = file;
          break;
        }
      }
    }
    if (xmlFile == null) {
      return 'No se encontró el contenido de texto en este archivo Word.';
    }
    final xmlContent = String.fromCharCodes(xmlFile.content);
    final document = xml.XmlDocument.parse(xmlContent);
    final paragraphs = document.descendants.where(
      (node) => node is xml.XmlElement && node.name.local == 'p',
    );
    final bufferParrafos = StringBuffer();
    for (var p in paragraphs) {
      final texts = p.descendants.where(
        (node) => node is xml.XmlElement && node.name.local == 't',
      );
      for (var t in texts) {
        bufferParrafos.write(t.text);
      }
      bufferParrafos.writeln('\n');
    }
    final textoFinal = bufferParrafos.toString().trim();
    return textoFinal.isNotEmpty ? textoFinal : 'El documento Word está vacío o no contiene texto reconocible.';
  } catch (e) {
    return 'Error al procesar el archivo Word: $e';
  }
}

class MiLectorApp extends StatelessWidget {
  const MiLectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mi Lector Pro',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0E2229),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0E2229),
          elevation: 0,
        ),
      ),
      home: const PantallaBienvenidaAnimada(),
    );
  }
}

class ColoresApp {
  static const Color fondoPrincipal = Color(0xFF0E2229);
  static const Color fondoTarjeta = Color(0xFF16333D);
  static const Color fondoDrawer = Color(0xFF0C1D23);
  static const Color acento = Color(0xFF38BDF8);
  static const Color acentoOscuro = Color(0xFF0284C7);

  static const List<String> fondosPorDefecto = [
    'assets/images/fondo1.jpg',
    'assets/images/fondo2.jpg',
    'assets/images/fondo3.jpg',
    'assets/images/fondo4.jpg',
  ];

  static const Map<String, Color> fondosSolidos = {
    'medianoche_pro': Color(0xFF0E2229),
    'azul_cosmico': Color(0xFF1E1B4B),
    'negro_obsidiana': Color(0xFF18181B),
    'purpura_mistico': Color(0xFF3B0764),
    'esmeralda_zen': Color(0xFF064E3B),
    'terracota_calida': Color(0xFF7C2D12),
  };
}

class TextProcessorTTS {
  static String prepararTextoParaTTS(String rawText) {
    if (rawText.trim().isEmpty) return '';

    // 1. Limpiar cualquier etiqueta HTML residual
    String texto = rawText.replaceAll(RegExp(r'<[^>]*>'), ' ');

    // 2. Corregir palabras divididas por guiones al final de línea (ej: "desarro-\nllador" -> "desarrollador")
    texto = texto.replaceAllMapped(
      RegExp(r'([a-zA-ZáéíóúÁÉÍÓÚñÑ]+)-\s*[\r\n]+\s*([a-zA-ZáéíóúÁÉÍÓÚñÑ]+)'),
      (m) => '${m[1]}${m[2]}',
    );

    // 3. Convertir saltos de línea dobles o múltiples (párrafos) en pausas de punto final
    texto = texto.replaceAll(RegExp(r'(\r?\n){2,}'), '. ');

    // 4. Convertir saltos de línea simples (renglones del mismo párrafo) en UN ESPACIO SIMPLE.
    //    Elimina las pausas artificiales o comas al saltar de renglón dentro de un párrafo.
    texto = texto.replaceAll(RegExp(r'\r?\n'), ' ');

    // 5. Normalizar palabras en MAYÚSCULAS para evitar que el motor TTS las deletree letra por letra.
    //    Transforma títulos como "CAPÍTULO", "INTRODUCCIÓN", "BIBLIOTECA" en "Capítulo", "Introducción", "Biblioteca".
    texto = texto.replaceAllMapped(
      RegExp(r'\b([A-ZÁÉÍÓÚÑ]{2,})\b'),
      (m) {
        final word = m[1]!;
        // Preservar números romanos comunes (I, II, III, IV, V, X, etc.)
        if (RegExp(r'^(I|II|III|IV|V|VI|VII|VIII|IX|X|XI|XII|XIII|XIV|XV|XVI|XVII|XVIII|XIX|XX)$').hasMatch(word)) {
          return word;
        }
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      },
    );

    // 6. Normalizar guiones de diálogo (— o –) a pausas limpias sin alterar palabras normales
    texto = texto.replaceAll(RegExp(r'\s+[—–-]\s+'), '. ');

    // 7. Garantizar espacio único tras signos de puntuación (. , ; : ? !) para pausas humanas naturales
    texto = texto.replaceAllMapped(
      RegExp(r'([.,;:?!])([a-zA-ZáéíóúÁÉÍÓÚñÑ])'),
      (m) => '${m[1]} ${m[2]}',
    );

    // 8. Colapsar espacios múltiples y limpiar bordes
    return texto.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

class NarradoresConfig {
  static Future<void> aplicarNarrador(FlutterTts tts, String voiceName, {double rate = 0.45}) async {
    try {
      if (Platform.isAndroid) {
        try {
          await tts.setEngine("com.google.android.tts");
        } catch (_) {}
      }

      await tts.setPitch(1.0);
      await tts.setSpeechRate(rate);

      if (voiceName.isNotEmpty && voiceName != 'Latino Natural' && voiceName != 'Sistema') {
        final List<dynamic>? voces = await tts.getVoices;
        if (voces != null && voces.isNotEmpty) {
          for (var v in voces) {
            if (v is Map) {
              final String name = (v['name'] ?? '').toString();
              if (name == voiceName) {
                final String locale = (v['locale'] ?? 'es-MX').toString();
                await tts.setVoice({"name": name, "locale": locale});
                return;
              }
            }
          }
        }
      }

      await tts.setLanguage("es-MX");
    } catch (e) {
      await tts.setLanguage("es-MX");
      await tts.setPitch(1.0);
    }
  }
}

class AjustesApp {
  String tipoFondo;
  String rutaFondoSeleccionado;
  String? colorSolidoId;
  bool modoOscuro;
  double nivelBrillo;
  bool filtroLuzAzul;
  bool modoSepia;
  double volumenEfecto;
  double intensidadFiltro;
  double velocidadVoz;
  bool sonidoActivado;
  String nombreSonidoActual;
  String? rutaSonidoPersonalizado;
  String ordenBiblioteca;
  String idioma;
  String? _narradorSeleccionado;

  String get narradorSeleccionado => _narradorSeleccionado ?? 'Latino Natural';
  set narradorSeleccionado(String v) => _narradorSeleccionado = v;

  AjustesApp({
    this.tipoFondo = 'defecto',
    this.rutaFondoSeleccionado = 'assets/images/fondo1.jpg',
    this.colorSolidoId,
    this.modoOscuro = true,
    this.nivelBrillo = 1.0,
    this.filtroLuzAzul = false,
    this.modoSepia = false,
    this.volumenEfecto = 0.8,
    this.intensidadFiltro = 0.2,
    this.velocidadVoz = 1.0,
    this.sonidoActivado = true,
    this.nombreSonidoActual = 'Effect 1',
    this.rutaSonidoPersonalizado,
    this.ordenBiblioteca = 'Recientes',
    this.idioma = 'Español',
    String narradorSeleccionado = 'Latino Natural',
  }) : _narradorSeleccionado = narradorSeleccionado;
}

class TextosIdioma extends ChangeNotifier {
  TextosIdioma._internal();
  static final TextosIdioma instancia = TextosIdioma._internal();

  static const Map<String, Map<String, String>> _diccionarios = {
    'Español': {
      'biblioteca': 'Libros',
      'audiolibros': 'Audiolibros 🎧',
      'videos': 'Videos 🎬',
      'documentos': 'Documentos Word 📝',
      'estadisticas': 'Estadísticas 📊',
      'config': 'Configuración',
      'descargar': 'Biblioteca Publica',
      'musica': 'Música de fondo para leer 🎼',
      'leyendo': 'Leyendo ahora',
      'favoritos': 'Favoritos',
      'porLeer': 'Por leer',
      'leidos': 'Leídos',
      'agregar': 'Agregar',
      'buscarHint': 'Buscar libro o presiona web...',
      'miBibliotecaTitle': 'Mi Biblioteca',
      'multimediaTitle': 'Multimedia',
      'herramientasTitle': 'Herramientas',
    },
    'English': {
      'biblioteca': 'Books',
      'audiolibros': 'Audiobooks 🎧',
      'videos': 'Videos 🎬',
      'documentos': 'Word Documents 📝',
      'estadisticas': 'Statistics 📊',
      'config': 'Settings',
      'descargar': 'Public Library',
      'musica': 'Music for Reading 🎼',
      'leyendo': 'Reading Now',
      'favoritos': 'Favorites',
      'porLeer': 'To Read',
      'leidos': 'Read',
      'agregar': 'Add',
      'buscarHint': 'Search book or tap web...',
      'miBibliotecaTitle': 'My Library',
      'multimediaTitle': 'Multimedia',
      'herramientasTitle': 'Tools',
    },
    'Português': {
      'biblioteca': 'Livros',
      'audiolibros': 'Audiolivros 🎧',
      'videos': 'Vídeos 🎬',
      'documentos': 'Documentos Word 📝',
      'estadisticas': 'Estatísticas 📊',
      'config': 'Configurações',
      'descargar': 'Biblioteca Pública',
      'musica': 'Música para Leitura 🎼',
      'leyendo': 'Lendo Agora',
      'favoritos': 'Favoritos',
      'porLeer': 'Para Ler',
      'leidos': 'Lidos',
      'agregar': 'Adicionar',
      'buscarHint': 'Buscar livro...',
      'miBibliotecaTitle': 'Minha Biblioteca',
      'multimediaTitle': 'Multimídia',
      'herramientasTitle': 'Ferramentas',
    },
    'Français': {
      'biblioteca': 'Livres',
      'audiolibros': 'Livres audio 🎧',
      'videos': 'Vidéos 🎬',
      'documentos': 'Documents Word 📝',
      'estadisticas': 'Statistiques 📊',
      'config': 'Paramètres',
      'descargar': 'Bibliothèque publique',
      'musica': 'Musique de lecture 🎼',
      'leyendo': 'Lecture en cours',
      'favoritos': 'Favoris',
      'porLeer': 'À lire',
      'leidos': 'Lus',
      'agregar': 'Ajouter',
      'buscarHint': 'Rechercher un livre...',
      'miBibliotecaTitle': 'Ma Bibliothèque',
      'multimediaTitle': 'Multimédia',
      'herramientasTitle': 'Outils',
    },
    'Deutsch': {
      'biblioteca': 'Bücher',
      'audiolibros': 'Hörbücher 🎧',
      'videos': 'Videos 🎬',
      'documentos': 'Word-Dokumente 📝',
      'estadisticas': 'Statistiken 📊',
      'config': 'Einstellungen',
      'descargar': 'Öffentliche Bibliothek',
      'musica': 'Lesemusik 🎼',
      'leyendo': 'Liest gerade',
      'favoritos': 'Favoriten',
      'porLeer': 'Zu lesen',
      'leidos': 'Gelesen',
      'agregar': 'Hinzufügen',
      'buscarHint': 'Buch suchen...',
      'miBibliotecaTitle': 'Meine Bibliothek',
      'multimediaTitle': 'Multimedia',
      'herramientasTitle': 'Werkzeuge',
    },
    'Italiano': {
      'biblioteca': 'Libri',
      'audiolibros': 'Audiolibri 🎧',
      'videos': 'Video 🎬',
      'documentos': 'Documenti Word 📝',
      'estadisticas': 'Statistiche 📊',
      'config': 'Impostazioni',
      'descargar': 'Biblioteca pubblica',
      'musica': 'Musica per leggere 🎼',
      'leyendo': 'In lettura',
      'favoritos': 'Preferiti',
      'porLeer': 'Da leggere',
      'leidos': 'Letti',
      'agregar': 'Aggiungi',
      'buscarHint': 'Cerca libro...',
      'miBibliotecaTitle': 'La mia biblioteca',
      'multimediaTitle': 'Multimedia',
      'herramientasTitle': 'Strumenti',
    },
  };

  String _idiomaActual = 'Español';
  String get idiomaActual => _idiomaActual;

  void establecerIdioma(String idioma) {
    if (_idiomaActual == idioma) return;
    _idiomaActual = idioma;
    notifyListeners();
  }

  void inicializarSinNotificar(String idioma) {
    _idiomaActual = idioma;
  }

  String get(String clave) {
    return _diccionarios[_idiomaActual]?[clave] ?? clave;
  }

  static List<String> get idiomasDisponibles => _diccionarios.keys.toList();
}

class PantallaBienvenidaAnimada extends StatefulWidget {
  const PantallaBienvenidaAnimada({super.key});

  @override
  State<PantallaBienvenidaAnimada> createState() => _PantallaBienvenidaAnimadaState();
}

class _PantallaBienvenidaAnimadaState extends State<PantallaBienvenidaAnimada> with TickerProviderStateMixin {
  final String _textoCompleto = "Mi Lector Pro";
  String _textoMostrado = "";
  Timer? _timerEscritura;
  late AnimationController _controladorPrincipal;
  late Animation<double> _animacionOpacidad;
  late Animation<double> _animacionEscala;

  @override
  void initState() {
    super.initState();
    _controladorPrincipal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );
    _animacionOpacidad = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controladorPrincipal,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );
    _animacionEscala = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controladorPrincipal,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _controladorPrincipal.forward();

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _iniciarEfectoEscritura();
    });
  }

  void _iniciarEfectoEscritura() {
    int index = 0;
    _timerEscritura = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (index < _textoCompleto.length) {
        setState(() {
          _textoMostrado += _textoCompleto[index];
        });
        index++;
      } else {
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 1600), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const PantallaPrincipalMiLector(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
                transitionDuration: const Duration(milliseconds: 900),
              ),
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timerEscritura?.cancel();
    _controladorPrincipal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: FadeTransition(
          opacity: _animacionOpacidad,
          child: ScaleTransition(
            scale: _animacionEscala,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFF16333D),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: ColoresApp.acento.withValues(alpha: 0.4)),
                    boxShadow: [
                      BoxShadow(
                        color: ColoresApp.acento.withValues(alpha: 0.25),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.asset('assets/icono.png', fit: BoxFit.contain),
                    ),
                  ),
                ),
                const SizedBox(height: 35),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _textoMostrado,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const BlinkingCursor(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BlinkingCursor extends StatefulWidget {
  const BlinkingCursor({super.key});

  @override
  State<BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<BlinkingCursor> with SingleTickerProviderStateMixin {
  late AnimationController _cursorController;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _cursorController,
      child: Container(
        margin: const EdgeInsets.only(left: 6),
        width: 3.5,
        height: 26,
        color: ColoresApp.acento,
      ),
    );
  }
}

class AudioGlobal extends ChangeNotifier {
  static final AudioGlobal _instance = AudioGlobal._internal();
  factory AudioGlobal() => _instance;
  AudioGlobal._internal();

  final AudioPlayer player = AudioPlayer();
  bool sonando = false;
  String? tituloActual;
  double volumen = 0.5;
  bool _inicializado = false;

  Future<void> init() async {
    if (_inicializado) return;
    _inicializado = true;
    // CONFIGURACIÓN GLOBAL: Permite la mezcla de audio sin interrumpir la música de fondo
    await AudioPlayer.global.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: false,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.none,
        ),
      ),
    );
    player.setReleaseMode(ReleaseMode.loop);
    player.onPlayerStateChanged.listen((state) {
      sonando = state == PlayerState.playing;
      notifyListeners();
    });
  }

  void registrarListener(VoidCallback callback) => addListener(callback);
  void removerListener(VoidCallback callback) => removeListener(callback);

  Future<void> reproducirLocal(String ruta, String titulo) async {
    try {
      tituloActual = titulo;
      await player.stop();
      await player.setVolume(volumen);
      await player.play(DeviceFileSource(ruta));
      sonando = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error reproduciendo pista local: $e');
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
      debugPrint('Error reproduciendo streaming online: $e');
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
    volumen = v;
    await player.setVolume(v);
    notifyListeners();
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }
}

class Marcador {
  final int pagina;
  final String etiqueta;
  final DateTime creadoEn;

  Marcador({
    required this.pagina,
    required this.etiqueta,
    DateTime? creadoEn,
  }) : creadoEn = creadoEn ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'pagina': pagina,
        'etiqueta': etiqueta,
        'creadoEn': creadoEn.toIso8601String(),
      };

  factory Marcador.fromMap(Map<String, dynamic> map) => Marcador(
        pagina: map['pagina'] ?? 1,
        etiqueta: map['etiqueta'] ?? 'Marcador',
        creadoEn: map['creadoEn'] != null
            ? DateTime.tryParse(map['creadoEn']) ?? DateTime.now()
            : DateTime.now(),
      );
}

class AreaResaltada {
  final int pagina;
  final double x;
  final double y;
  final double ancho;
  final double alto;
  final Color color;
  final double opacidad;

  AreaResaltada({
    required this.pagina,
    required this.x,
    required this.y,
    required this.ancho,
    required this.alto,
    required this.color,
    required this.opacidad,
  });

  Map<String, dynamic> toMap() => {
        'pagina': pagina,
        'x': x,
        'y': y,
        'ancho': ancho,
        'alto': alto,
        'color': color.toARGB32(),
        'opacidad': opacidad,
      };

  factory AreaResaltada.fromMap(Map<String, dynamic> map) => AreaResaltada(
        pagina: map['pagina'] ?? 1,
        x: (map['x'] ?? 0.0).toDouble(),
        y: (map['y'] ?? 0.0).toDouble(),
        ancho: (map['ancho'] ?? 0.0).toDouble(),
        alto: (map['alto'] ?? 0.0).toDouble(),
        color: Color(map['color'] ?? Colors.yellow.toARGB32()),
        opacidad: (map['opacidad'] ?? 0.3).toDouble(),
      );
}

class Libro {
  final String id;
  final String titulo;
  final String rutaLocal;
  int ultimaPagina;
  bool esFavorito;
  bool porLeer;
  bool leido;
  String categoria;
  bool esAudiolibro;
  bool esEpub;
  bool esVideo;
  bool esDocx;
  String notasPersonales;
  List<Marcador> marcadores;
  List<AreaResaltada> resaltados;
  int posicionMs;
  String? rutaPortadaCache;

  Libro({
    required this.id,
    required this.titulo,
    required this.rutaLocal,
    this.ultimaPagina = 1,
    this.esFavorito = false,
    this.porLeer = true,
    this.leido = false,
    this.categoria = 'General',
    this.esAudiolibro = false,
    this.esEpub = false,
    this.esVideo = false,
    this.esDocx = false,
    this.notasPersonales = '',
    List<Marcador>? marcadores,
    List<AreaResaltada>? resaltados,
    this.posicionMs = 0,
    this.rutaPortadaCache,
  })  : marcadores = marcadores ?? [],
        resaltados = resaltados ?? [];

  List<AreaResaltada> resaltadosDePagina(int pagina) =>
      resaltados.where((r) => r.pagina == pagina).toList();

  Map<String, dynamic> toMap() => {
        'id': id,
        'titulo': titulo,
        'rutaLocal': rutaLocal,
        'ultimaPagina': ultimaPagina,
        'esFavorito': esFavorito,
        'porLeer': porLeer,
        'leido': leido,
        'categoria': categoria,
        'esAudiolibro': esAudiolibro,
        'esEpub': esEpub,
        'esVideo': esVideo,
        'esDocx': esDocx,
        'notasPersonales': notasPersonales,
        'marcadores': marcadores.map((m) => m.toMap()).toList(),
        'resaltados': resaltados.map((r) => r.toMap()).toList(),
        'posicionMs': posicionMs,
        'rutaPortadaCache': rutaPortadaCache,
      };

  factory Libro.fromMap(Map<String, dynamic> map) => Libro(
        id: map['id'],
        titulo: map['titulo'],
        rutaLocal: map['rutaLocal'],
        ultimaPagina: map['ultimaPagina'] ?? 1,
        esFavorito: map['esFavorito'] ?? false,
        porLeer: map['porLeer'] ?? true,
        leido: map['leido'] ?? false,
        categoria: map['categoria'] ?? 'General',
        esAudiolibro: map['esAudiolibro'] ?? false,
        esEpub: map['esEpub'] ?? false,
        esVideo: map['esVideo'] ?? false,
        esDocx: map['esDocx'] ?? false,
        notasPersonales: map['notasPersonales'] ?? '',
        marcadores: (map['marcadores'] as List<dynamic>?)
                ?.map((m) => Marcador.fromMap(m))
                .toList() ??
            [],
        resaltados: (map['resaltados'] as List<dynamic>?)
                ?.map((r) => AreaResaltada.fromMap(r))
                .toList() ??
            [],
        posicionMs: map['posicionMs'] ?? 0,
        rutaPortadaCache: map['rutaPortadaCache'],
      );
}

class PistaMusica {
  final String id;
  final String titulo;
  final String rutaLocal;

  PistaMusica({required this.id, required this.titulo, required this.rutaLocal});

  Map<String, dynamic> toMap() => {
        'id': id,
        'titulo': titulo,
        'rutaLocal': rutaLocal,
      };

  factory PistaMusica.fromMap(Map<String, dynamic> map) => PistaMusica(
        id: map['id'],
        titulo: map['titulo'],
        rutaLocal: map['rutaLocal'],
      );
}

class PermisosService {
  static Future<bool> solicitarPermisosAlmacenamiento() async {
    try {
      if (Platform.isAndroid) {
        await [
          Permission.audio,
          Permission.videos,
          Permission.photos,
        ].request();
      }
      return true;
    } catch (e) {
      debugPrint('Error en permisos: $e');
      return true;
    }
  }

  static Future<bool> hayPermisosBloqueadosPermanentemente() async {
    return false;
  }
}

Future<bool> solicitarPermisosAlmacenamiento() async {
  return await PermisosService.solicitarPermisosAlmacenamiento();
}

class BibliotecaRepository {
  static const _kLibros = 'mis_libros_app';
  static const _kCategorias = 'mis_categorias_app';
  static const _kPistas = 'mis_pistas_musica_app';

  static const _kTipoFondo = 'tipo_fondo_app';
  static const _kRutaFondo = 'ruta_fondo_app';
  static const _kColorSolidoId = 'color_solido_id_app';
  static const _kModoOscuro = 'modo_oscuro_global';
  static const _kNivelBrillo = 'nivel_brillo_global';
  static const _kFiltroLuzAzul = 'filtro_luz_azul_global';
  static const _kModoSepia = 'modo_sepia_global';
  static const _kVolumenEfecto = 'volumen_efecto_global';
  static const _kIntensidadFiltro = 'intensidad_filtro_global';
  static const _kVelocidadVoz = 'velocidad_voz_global';
  static const _kSonidoActivado = 'sonido_activado_global';
  static const _kNombreSonido = 'nombre_sonido_global';
  static const _kRutaSonidoCustom = 'ruta_sonido_custom_global';
  static const _kOrdenBiblioteca = 'orden_biblioteca_global';
  static const _kIdioma = 'idioma_app';
  static const _kNarrador = 'narrador_seleccionado_global';

  Future<List<Libro>> cargarLibros() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_kLibros);
    if (jsonString == null) return [];
    try {
      final List<dynamic> lista = jsonDecode(jsonString);
      return lista.map((i) => Libro.fromMap(i)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> guardarLibros(List<Libro> libros) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLibros, jsonEncode(libros.map((l) => l.toMap()).toList()));
  }

  Future<List<String>> cargarCategorias() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kCategorias) ?? ['Todas', 'General'];
  }

  Future<void> guardarCategorias(List<String> categorias) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kCategorias, categorias);
  }

  Future<List<PistaMusica>> cargarPistasMusica() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_kPistas);
    if (jsonString == null) return [];
    try {
      final List<dynamic> lista = jsonDecode(jsonString);
      return lista.map((i) => PistaMusica.fromMap(i)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> guardarPistasMusica(List<PistaMusica> pistas) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPistas, jsonEncode(pistas.map((p) => p.toMap()).toList()));
  }

  Future<AjustesApp> cargarAjustes({required bool esOscuroSistemaPorDefecto}) async {
    final prefs = await SharedPreferences.getInstance();
    return AjustesApp(
      tipoFondo: prefs.getString(_kTipoFondo) ?? 'defecto',
      rutaFondoSeleccionado: prefs.getString(_kRutaFondo) ?? 'assets/images/fondo1.jpg',
      colorSolidoId: prefs.getString(_kColorSolidoId),
      modoOscuro: prefs.getBool(_kModoOscuro) ?? esOscuroSistemaPorDefecto,
      nivelBrillo: prefs.getDouble(_kNivelBrillo) ?? 1.0,
      filtroLuzAzul: prefs.getBool(_kFiltroLuzAzul) ?? false,
      modoSepia: prefs.getBool(_kModoSepia) ?? false,
      volumenEfecto: prefs.getDouble(_kVolumenEfecto) ?? 0.8,
      intensidadFiltro: prefs.getDouble(_kIntensidadFiltro) ?? 0.2,
      velocidadVoz: prefs.getDouble(_kVelocidadVoz) ?? 1.0,
      sonidoActivado: prefs.getBool(_kSonidoActivado) ?? true,
      nombreSonidoActual: prefs.getString(_kNombreSonido) ?? 'Effect 1',
      rutaSonidoPersonalizado: prefs.getString(_kRutaSonidoCustom),
      ordenBiblioteca: prefs.getString(_kOrdenBiblioteca) ?? 'Recientes',
      idioma: prefs.getString(_kIdioma) ?? 'Español',
      narradorSeleccionado: prefs.getString(_kNarrador) ?? 'Latino Natural',
    );
  }

  Future<void> guardarAjustes(AjustesApp ajustes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTipoFondo, ajustes.tipoFondo);
    await prefs.setString(_kRutaFondo, ajustes.rutaFondoSeleccionado);
    if (ajustes.colorSolidoId != null) {
      await prefs.setString(_kColorSolidoId, ajustes.colorSolidoId!);
    } else {
      await prefs.remove(_kColorSolidoId);
    }
    await prefs.setBool(_kModoOscuro, ajustes.modoOscuro);
    await prefs.setDouble(_kNivelBrillo, ajustes.nivelBrillo);
    await prefs.setBool(_kFiltroLuzAzul, ajustes.filtroLuzAzul);
    await prefs.setBool(_kModoSepia, ajustes.modoSepia);
    await prefs.setDouble(_kVolumenEfecto, ajustes.volumenEfecto);
    await prefs.setDouble(_kIntensidadFiltro, ajustes.intensidadFiltro);
    await prefs.setDouble(_kVelocidadVoz, ajustes.velocidadVoz);
    await prefs.setBool(_kSonidoActivado, ajustes.sonidoActivado);
    await prefs.setString(_kNombreSonido, ajustes.nombreSonidoActual);
    await prefs.setString(_kOrdenBiblioteca, ajustes.ordenBiblioteca);
    await prefs.setString(_kIdioma, ajustes.idioma);
    await prefs.setString(_kNarrador, ajustes.narradorSeleccionado);
    if (ajustes.rutaSonidoPersonalizado != null) {
      await prefs.setString(_kRutaSonidoCustom, ajustes.rutaSonidoPersonalizado!);
    } else {
      await prefs.remove(_kRutaSonidoCustom);
    }
  }
}

class PortadaPdfWidget extends StatefulWidget {
  final String rutaPdf;
  final String titulo;
  final String? rutaPortadaCache;
  final void Function(String rutaCache)? onPortadaGenerada;

  const PortadaPdfWidget({
    super.key,
    required this.rutaPdf,
    required this.titulo,
    this.rutaPortadaCache,
    this.onPortadaGenerada,
  });

  @override
  State<PortadaPdfWidget> createState() => _PortadaPdfWidgetState();
}

class _PortadaPdfWidgetState extends State<PortadaPdfWidget> with AutomaticKeepAliveClientMixin {
  File? _archivoPortada;
  bool _cargando = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _cargarOGenerarPortada();
  }

  Future<void> _cargarOGenerarPortada() async {
    if (widget.rutaPortadaCache != null) {
      final archivoExistente = File(widget.rutaPortadaCache!);
      if (await archivoExistente.exists()) {
        if (mounted) {
          setState(() {
            _archivoPortada = archivoExistente;
            _cargando = false;
          });
        }
        return;
      }
    }

    try {
      final doc = await pdfx.PdfDocument.openFile(widget.rutaPdf);
      final page = await doc.getPage(1);
      final pageImage = await page.render(
        width: page.width * 1.0,
        height: page.height * 1.0,
        format: pdfx.PdfPageImageFormat.jpeg,
      );
      await page.close();
      await doc.close();

      if (!mounted) return;

      if (pageImage == null) {
        setState(() => _cargando = false);
        return;
      }

      final cacheDir = await getApplicationCacheDirectory();
      final nombreArchivo = 'portada_${widget.titulo.hashCode}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final archivoDestino = File('${cacheDir.path}/$nombreArchivo');
      await archivoDestino.writeAsBytes(pageImage.bytes);

      widget.onPortadaGenerada?.call(archivoDestino.path);

      if (mounted) {
        setState(() {
          _archivoPortada = archivoDestino;
          _cargando = false;
        });
      }
    } catch (e) {
      debugPrint('Error generando portada de "${widget.titulo}": $e');
      if (mounted) setState(() => _cargando = false);
    }
  }

  Widget _buildPortadaFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF16333D), Color(0xFF0E2229)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.menu_book_rounded, color: ColoresApp.acento, size: 36),
          const SizedBox(height: 6),
          Text(
            widget.titulo,
            maxLines: 3,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_cargando) {
      return Container(
        color: const Color(0xFF16333D),
        child: const Center(child: CircularProgressIndicator(color: ColoresApp.acento, strokeWidth: 2)),
      );
    }
    if (_archivoPortada != null && _archivoPortada!.existsSync()) {
      return Image.file(
        _archivoPortada!,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) => _buildPortadaFallback(),
      );
    }
    return _buildPortadaFallback();
  }
}

class MiniReproductorMusicaFondo extends StatelessWidget {
  final List<PistaMusica> pistas;

  const MiniReproductorMusicaFondo({super.key, required this.pistas});

  void _mostrarSelectorPistas(BuildContext context) {
    if (pistas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aún no tienes música guardada. Ve a "Música para Leer"')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: ColoresApp.fondoTarjeta,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Elige música de fondo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              ...pistas.map((p) => ListTile(
                    leading: const Icon(Icons.music_note, color: ColoresApp.acento),
                    title: Text(p.titulo, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    onTap: () {
                      Navigator.pop(context);
                      AudioGlobal().reproducirLocal(p.rutaLocal, p.titulo);
                    },
                  )),
            ],
          ),
        );
      },
    );
  }

  void _mostrarPanelControl(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ColoresApp.fondoTarjeta,
      builder: (context) {
        return AnimatedBuilder(
          animation: AudioGlobal(),
          builder: (context, _) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AudioGlobal().tituloActual != null
                          ? 'Sonando: ${AudioGlobal().tituloActual}'
                          : 'Sin música',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.volume_down, color: Colors.grey, size: 18),
                        Expanded(
                          child: Slider(
                            value: AudioGlobal().volumen,
                            min: 0.0,
                            max: 1.0,
                            activeColor: ColoresApp.acento,
                            onChanged: (v) => AudioGlobal().cambiarVolumen(v),
                          ),
                        ),
                        const Icon(Icons.volume_up, color: Colors.white, size: 18),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton.icon(
                          icon: Icon(
                            AudioGlobal().sonando ? Icons.pause : Icons.play_arrow,
                            color: ColoresApp.acento,
                          ),
                          label: Text(
                            AudioGlobal().sonando ? 'Pausar' : 'Reproducir',
                            style: const TextStyle(color: ColoresApp.acento),
                          ),
                          onPressed: () => AudioGlobal().pausarOReanudar(),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.playlist_play, color: Colors.white70),
                          label: const Text('Cambiar pista', style: TextStyle(color: Colors.white70)),
                          onPressed: () {
                            Navigator.pop(context);
                            _mostrarSelectorPistas(context);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AudioGlobal(),
      builder: (context, _) {
        final bool sonando = AudioGlobal().sonando;
        return IconButton(
          icon: Icon(
            sonando ? Icons.music_note : Icons.music_off,
            color: sonando ? ColoresApp.acento : Colors.grey,
            size: 20,
          ),
          tooltip: 'Música de fondo para leer',
          onPressed: () {
            if (!AudioGlobal().sonando && AudioGlobal().tituloActual == null) {
              _mostrarSelectorPistas(context);
            } else {
              _mostrarPanelControl(context);
            }
          },
        );
      },
    );
  }
}

class PantallaEstadisticas extends StatelessWidget {
  final List<Libro> libros;
  final List<PistaMusica> pistasMusica;

  const PantallaEstadisticas({super.key, required this.libros, this.pistasMusica = const []});

  @override
  Widget build(BuildContext context) {
    final int totalPdfs = libros.where((l) => !l.esAudiolibro && !l.esEpub && !l.esVideo && !l.esDocx).length;
    final int totalEpub = libros.where((l) => l.esEpub).length;
    final int totalDocx = libros.where((l) => l.esDocx).length;
    final int totalAudio = libros.where((l) => l.esAudiolibro).length;
    final int totalVideo = libros.where((l) => l.esVideo).length;
    final int leidos = libros.where((l) => l.leido).length;
    final int enProgreso = libros.where((l) => l.ultimaPagina > 1 && !l.leido).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Estadísticas y Hábitos de Lectura',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 15),
        Row(
          children: [
            _cardStat('Libros Leídos', '$leidos', Icons.check_circle_outline, Colors.greenAccent),
            const SizedBox(width: 10),
            _cardStat('En Lectura', '$enProgreso', Icons.menu_book, ColoresApp.acento),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _cardStat('PDFs', '$totalPdfs', Icons.picture_as_pdf, Colors.orangeAccent),
            const SizedBox(width: 10),
            _cardStat('EPUBs', '$totalEpub', Icons.menu_book_rounded, Colors.blueAccent),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _cardStat('Word (Docx)', '$totalDocx', Icons.description, Colors.lightBlue),
            const SizedBox(width: 10),
            _cardStat('Audiolibros', '$totalAudio', Icons.headphones, Colors.purpleAccent),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _cardStat('Videos', '$totalVideo', Icons.video_library, Colors.pinkAccent),
            const SizedBox(width: 10),
            _cardStat('Total', '${libros.length}', Icons.library_books, Colors.amberAccent),
          ],
        ),
      ],
    );
  }

  Widget _cardStat(String titulo, String valor, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: ColoresApp.fondoTarjeta, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(valor, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(titulo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class PantallaBibliotecasDirectas extends StatelessWidget {
  const PantallaBibliotecasDirectas({super.key});

  static const List<Map<String, String>> _bibliotecas = [
    {
      'nombre': 'Elejandría (Buscador y Descargas)',
      'desc': 'Libros clásicos gratis en PDF y EPUB. Enlace directo al catálogo limpio sin rodeos.',
      'url': 'https://www.elejandria.com/buscar',
      'icon': '📚',
    },
    {
      'nombre': 'Proyecto Gutenberg (Español)',
      'desc': 'Más de 70.000 obras universales y clásicos de dominio público en español.',
      'url': 'https://www.gutenberg.org/browse/languages/es',
      'icon': '🏛️',
    },
    {
      'nombre': 'Wikisource en Español',
      'desc': 'Biblioteca digital libre de novelas, ensayos y documentos históricos en español.',
      'url': 'https://es.wikisource.org/wiki/Portal:Literatura',
      'icon': '📝',
    },
    {
      'nombre': 'Internet Archive (Biblioteca Abierta)',
      'desc': 'Millones de libros y documentos de dominio público disponibles en español.',
      'url': 'https://archive.org/details/texts?and[]=languageSorter%3A"Spanish"',
      'icon': '🌐',
    },
  ];

  void _abrirSitioEnApp(BuildContext context, String titulo, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PantallaVisorWebCompleto(titulo: titulo, url: url)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Biblioteca Pública de Obras Clásicas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 6),
        const Text(
          'Explora colecciones digitales libres de derechos de autor con navegación limpia.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        ..._bibliotecas.map((b) => Card(
              color: ColoresApp.fondoTarjeta,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Text(b['icon']!, style: const TextStyle(fontSize: 32)),
                title: Text(b['nombre']!, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                subtitle: Text(b['desc']!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: ColoresApp.acento),
                onTap: () => _abrirSitioEnApp(context, b['nombre']!, b['url']!),
              ),
            )),
      ],
    );
  }
}

class PantallaVisorWebCompleto extends StatefulWidget {
  final String titulo;
  final String url;
  const PantallaVisorWebCompleto({super.key, required this.titulo, required this.url});

  @override
  State<PantallaVisorWebCompleto> createState() => _PantallaVisorWebCompletoState();
}

class _PantallaVisorWebCompletoState extends State<PantallaVisorWebCompleto> {
  late final WebViewController controller;
  bool cargando = true;
  late final String _hostInicial;

  @override
  void initState() {
    super.initState();
    _hostInicial = Uri.tryParse(widget.url)?.host ?? '';

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) async {
            if (mounted) setState(() => cargando = false);
            try {
              await controller.runJavaScript('''
                (function() {
                  var selectors = [
                    'ins.adsbygoogle',
                    'div[id*="google_ads"]',
                    'iframe[src*="google"]',
                    'iframe[src*="doubleclick"]',
                    'iframe[src*="amazon"]',
                    'iframe[src*="ad"]',
                    '.ad-container',
                    '.ad-wrapper',
                    '.adsbygoogle',
                    '#pop-up',
                    '.pop-up',
                    '.banner-ad',
                    '#ezoic-pub-ad-placeholder',
                    '.elejandria-ad',
                    '.advertisement'
                  ];
                  selectors.forEach(function(sel) {
                    var elements = document.querySelectorAll(sel);
                    elements.forEach(function(el) {
                      el.style.display = 'none';
                      el.remove();
                    });
                  });
                })();
              ''');
            } catch (_) {}
          },
          onNavigationRequest: (NavigationRequest request) {
            final String urlLower = request.url.toLowerCase();
            final Uri? destino = Uri.tryParse(request.url);
            final bool esMismoDominio =
                destino != null && destino.host.isNotEmpty && (destino.host == _hostInicial || destino.host.contains('elejandria') || destino.host.contains('gutenberg') || destino.host.contains('wikisource') || destino.host.contains('archive'));
            final bool esEsquemaEspecial = urlLower.startsWith('intent://') ||
                urlLower.startsWith('market://') ||
                urlLower.startsWith('whatsapp://') ||
                urlLower.endsWith('.pdf') ||
                urlLower.endsWith('.epub') ||
                urlLower.endsWith('.docx') ||
                urlLower.contains('download') ||
                urlLower.contains('descargar');

            if (esEsquemaEspecial || !esMismoDominio) {
              launchUrl(Uri.parse(request.url), mode: LaunchMode.externalApplication);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: ColoresApp.fondoPrincipal,
          title: Text(widget.titulo, style: const TextStyle(fontSize: 16)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (await controller.canGoBack()) {
                controller.goBack();
              } else {
                if (!context.mounted) return;
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: () => controller.reload()),
            IconButton(
              icon: const Icon(Icons.open_in_browser),
              tooltip: 'Abrir en el navegador',
              onPressed: () => launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication),
            ),
          ],
        ),
        body: Stack(
          children: [
            Container(color: Colors.white, child: WebViewWidget(controller: controller)),
            if (cargando)
              Container(
                color: ColoresApp.fondoPrincipal,
                child: const Center(child: CircularProgressIndicator(color: ColoresApp.acento)),
              ),
          ],
        ),
      ),
    );
  }
}

class PantallaMusicaGratis extends StatefulWidget {
  final List<PistaMusica> pistas;
  final Future<void> Function() onAgregarPista;
  final void Function(PistaMusica) onEliminarPista;

  const PantallaMusicaGratis({
    super.key,
    required this.pistas,
    required this.onAgregarPista,
    required this.onEliminarPista,
  });

  @override
  State<PantallaMusicaGratis> createState() => _PantallaMusicaGratisState();
}

class _PantallaMusicaGratisState extends State<PantallaMusicaGratis> {
  final AudioPlayer _previa = AudioPlayer();
  String? _idSonando;

  static const List<Map<String, String>> _fuentes = [
    {
      'nombre': 'WWFM Classical Network',
      'desc': 'Emisora pública universitaria en alta fidelidad. Sonido continuo garantizado.',
      'url': 'https://wwfm.streamguys1.com/live-mp3',
      'icon': '📻',
    },
    {
      'nombre': 'Musopen - Repositorio Oficial',
      'desc': 'Plataforma legal de partituras y grabaciones de música clásica de dominio público.',
      'url': 'https://musopen.org/',
      'icon': '🏛️',
    },
  ];

  @override
  void dispose() {
    _previa.dispose();
    super.dispose();
  }

  void _abrirSitio(String titulo, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PantallaVisorWebCompleto(titulo: titulo, url: url)),
    );
  }

  Future<void> _probarPista(PistaMusica pista) async {
    try {
      if (_idSonando == pista.id) {
        await _previa.stop();
        if (!mounted) return;
        setState(() => _idSonando = null);
      } else {
        await _previa.stop();
        await _previa.play(DeviceFileSource(pista.rutaLocal));
        if (!mounted) return;
        setState(() => _idSonando = pista.id);
      }
    } catch (e) {
      debugPrint('Error probando pista: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Música para Leer 🎼')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ColoresApp.acentoOscuro,
        icon: const Icon(Icons.library_add, color: Colors.white),
        label: const Text('Agregar pista', style: TextStyle(color: Colors.white)),
        onPressed: () async {
          await widget.onAgregarPista();
          if (mounted) setState(() {});
        },
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AnimatedBuilder(
            animation: AudioGlobal(),
            builder: (context, _) {
              final audio = AudioGlobal();
              final String? titulo = audio.tituloActual;
              final bool sonando = audio.sonando;

              return Card(
                color: ColoresApp.fondoTarjeta,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: ColoresApp.acento.withValues(alpha: 0.4), width: 1.5),
                ),
                margin: const EdgeInsets.only(bottom: 20),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: ColoresApp.acento.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(sonando ? Icons.graphic_eq : Icons.music_note, color: ColoresApp.acento, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sonando ? 'Reproduciendo música de fondo' : (titulo != null ? 'Música en pausa' : 'Música de fondo'),
                                  style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  titulo ?? 'Sin música reproduciéndose',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: sonando ? Colors.amber.shade800 : ColoresApp.acentoOscuro,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            icon: Icon(sonando ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 20),
                            label: Text(
                              sonando ? 'Pausar' : 'Reproducir',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            onPressed: () {
                              if (titulo != null) {
                                audio.pausarOReanudar();
                              } else if (widget.pistas.isNotEmpty) {
                                audio.reproducirLocal(widget.pistas.first.rutaLocal, widget.pistas.first.titulo);
                              } else {
                                audio.reproducirUrl('https://wwfm.streamguys1.com/live-mp3', 'WWFM Classical Network');
                              }
                            },
                          ),
                          if (titulo != null)
                            IconButton(
                              icon: const Icon(Icons.stop_circle_rounded, color: Colors.redAccent, size: 24),
                              tooltip: 'Detener música',
                              onPressed: () => audio.detener(),
                            ),
                        ],
                      ),
                      if (titulo != null) ...[
                        const SizedBox(height: 10),
                        const Divider(color: Colors.white12, height: 1),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.volume_down_rounded, color: Colors.grey, size: 16),
                            Expanded(
                              child: Slider(
                                value: audio.volumen,
                                min: 0.0,
                                max: 1.0,
                                activeColor: ColoresApp.acento,
                                inactiveColor: Colors.white24,
                                onChanged: (v) => audio.cambiarVolumen(v),
                              ),
                            ),
                            const Icon(Icons.volume_up_rounded, color: Colors.white, size: 16),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const Text('Emisora Pública y Fuentes Clásicas',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 6),
          const Text(
            'Toca la emisora online para iniciar la música en segundo plano. Puedes navegar por la app sin que se corte.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          ..._fuentes.map((f) => Card(
                color: ColoresApp.fondoTarjeta,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Text(f['icon']!, style: const TextStyle(fontSize: 32)),
                  title: Text(f['nombre']!, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  subtitle: Text(f['desc']!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  trailing: Icon(
                    f['url']!.contains('streamguys1') ? Icons.play_circle_fill : Icons.open_in_browser,
                    size: 24,
                    color: ColoresApp.acento,
                  ),
                  onTap: () async {
                    if (f['url']!.contains('streamguys1')) {
                      await AudioGlobal().reproducirUrl(f['url']!, f['nombre']!);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Reproduciendo en segundo plano: ${f['nombre']}'),
                            backgroundColor: ColoresApp.acentoOscuro,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    } else {
                      _abrirSitio(f['nombre']!, f['url']!);
                    }
                  },
                ),
              )),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24),
          const SizedBox(height: 8),
          Text('Tus pistas guardadas (${widget.pistas.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          if (widget.pistas.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Aún no tienes música guardada en la app. Descarga una pieza clásica y agrégala con el botón flotante.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            )
          else
            ...widget.pistas.map((p) {
              final bool sonando = _idSonando == p.id;
              return Card(
                color: ColoresApp.fondoTarjeta,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(sonando ? Icons.stop_circle : Icons.music_note, color: ColoresApp.acento),
                  title: Text(p.titulo,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  onTap: () => _probarPista(p),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    onPressed: () {
                      if (_idSonando == p.id) {
                        _previa.stop();
                        setState(() => _idSonando = null);
                      }
                      widget.onEliminarPista(p);
                      setState(() {});
                    },
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class PantallaReproductorAudiolibro extends StatefulWidget {
  final Libro libro;
  const PantallaReproductorAudiolibro({super.key, required this.libro});

  @override
  State<PantallaReproductorAudiolibro> createState() => _PantallaReproductorAudiolibroState();
}

class _PantallaReproductorAudiolibroState extends State<PantallaReproductorAudiolibro> {
  final AudioPlayer _player = AudioPlayer();
  bool sonando = false;
  Duration duracionTotal = Duration.zero;
  Duration posicionActual = Duration.zero;
  bool _yaReanudo = false;
  Timer? _timerApagado;
  int minutosRestantesTimer = 0;
  double velocidadAudio = 1.0;

  @override
  void initState() {
    super.initState();
    _prepararAudio();
  }

  Future<void> _prepararAudio() async {
    try {
      _player.onDurationChanged.listen((d) {
        if (mounted) setState(() => duracionTotal = d);
      });
      _player.onPositionChanged.listen((p) {
        if (mounted) setState(() => posicionActual = p);
        widget.libro.posicionMs = p.inMilliseconds;
      });
      _player.onPlayerComplete.listen((_) {
        if (mounted) setState(() => sonando = false);
        widget.libro.posicionMs = 0;
        widget.libro.leido = true;
      });

      await _player.setSource(DeviceFileSource(widget.libro.rutaLocal));

      if (widget.libro.posicionMs > 0 && !_yaReanudo) {
        _yaReanudo = true;
        await _player.seek(Duration(milliseconds: widget.libro.posicionMs));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reanudando desde ${_formatDuration(Duration(milliseconds: widget.libro.posicionMs))}'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error preparando audiolibro: $e');
    }
  }

  @override
  void dispose() {
    _timerApagado?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _playPausa() async {
    try {
      if (sonando) {
        await _player.pause();
        setState(() => sonando = false);
      } else {
        await _player.setPlaybackRate(velocidadAudio);
        if (_player.state == PlayerState.paused) {
          await _player.resume();
        } else {
          await _player.play(DeviceFileSource(widget.libro.rutaLocal));
          if (posicionActual.inMilliseconds > 0) {
            await _player.seek(posicionActual);
          }
        }
        setState(() => sonando = true);
      }
    } catch (e) {
      debugPrint('Error en reproducción de audiolibro: $e');
    }
  }

  Future<void> _cambiarVelocidad(double nuevaVelocidad) async {
    setState(() => velocidadAudio = nuevaVelocidad);
    await _player.setPlaybackRate(nuevaVelocidad);
  }

  void _saltarSegundos(int segundos) {
    int nuevosMs = posicionActual.inMilliseconds + (segundos * 1000);
    int maxMs = duracionTotal.inMilliseconds;
    if (nuevosMs < 0) nuevosMs = 0;
    if (maxMs > 0 && nuevosMs > maxMs) nuevosMs = maxMs;
    _player.seek(Duration(milliseconds: nuevosMs));
  }

  void _configurarSleepTimer(int minutos) {
    _timerApagado?.cancel();
    setState(() => minutosRestantesTimer = minutos);
    if (minutos > 0) {
      _timerApagado = Timer.periodic(const Duration(minutes: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (minutosRestantesTimer > 1) {
          setState(() => minutosRestantesTimer--);
        } else {
          _player.pause();
          timer.cancel();
          setState(() {
            sonando = false;
            minutosRestantesTimer = 0;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Temporizador finalizado: Audiolibro pausado.')),
            );
          }
        }
      });
    }
  }

  String _formatDuration(Duration d) {
    String min = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    String sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "${d.inHours > 0 ? '${d.inHours}:' : ''}$min:$sec";
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reproductor de Audiolibro'),
          backgroundColor: ColoresApp.fondoPrincipal,
          actions: [
            PopupMenuButton<int>(
              icon: Icon(Icons.timer, color: minutosRestantesTimer > 0 ? Colors.amberAccent : Colors.white),
              tooltip: 'Temporizador de apagado',
              onSelected: _configurarSleepTimer,
              itemBuilder: (context) => [
                const PopupMenuItem(value: 0, child: Text('Desactivar temporizador')),
                const PopupMenuItem(value: 15, child: Text('Apagar en 15 minutos')),
                const PopupMenuItem(value: 30, child: Text('Apagar en 30 minutos')),
                const PopupMenuItem(value: 60, child: Text('Apagar en 1 hora')),
              ],
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: ColoresApp.fondoTarjeta,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
                ),
                child: const Icon(Icons.headphones_rounded, size: 100, color: ColoresApp.acento),
              ),
              const SizedBox(height: 20),
              Text(widget.libro.titulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              if (minutosRestantesTimer > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text('Apagado automático en $minutosRestantesTimer min',
                      style: const TextStyle(color: Colors.amberAccent, fontSize: 12)),
                ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Velocidad:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(width: 8),
                  _chipVelocidad(0.5, '0.5x'),
                  _chipVelocidad(1.0, '1.0x'),
                  _chipVelocidad(1.5, '1.5x'),
                  _chipVelocidad(2.0, '2.0x'),
                ],
              ),
              const SizedBox(height: 10),
              Slider(
                value: posicionActual.inSeconds
                    .toDouble()
                    .clamp(0.0, duracionTotal.inSeconds > 0 ? duracionTotal.inSeconds.toDouble() : 1.0),
                max: duracionTotal.inSeconds > 0 ? duracionTotal.inSeconds.toDouble() : 1.0,
                activeColor: ColoresApp.acento,
                onChanged: (val) => _player.seek(Duration(seconds: val.toInt())),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(posicionActual), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(_formatDuration(duracionTotal), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                      iconSize: 40,
                      icon: const Icon(Icons.replay_10, color: Colors.white),
                      onPressed: () => _saltarSegundos(-10)),
                  const SizedBox(width: 20),
                  IconButton(
                    iconSize: 64,
                    icon: Icon(sonando ? Icons.pause_circle_filled : Icons.play_circle_fill, color: ColoresApp.acento),
                    onPressed: _playPausa,
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                      iconSize: 40,
                      icon: const Icon(Icons.forward_10, color: Colors.white),
                      onPressed: () => _saltarSegundos(10)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipVelocidad(double val, String label) {
    bool seleccionado = velocidadAudio == val;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3.0),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 10, color: seleccionado ? Colors.white : Colors.grey)),
        selected: seleccionado,
        selectedColor: ColoresApp.acentoOscuro,
        backgroundColor: ColoresApp.fondoTarjeta,
        onSelected: (bool selected) => _cambiarVelocidad(val),
      ),
    );
  }
}

class PantallaReproductorVideo extends StatefulWidget {
  final Libro libro;
  const PantallaReproductorVideo({super.key, required this.libro});

  @override
  State<PantallaReproductorVideo> createState() => _PantallaReproductorVideoState();
}

class _PantallaReproductorVideoState extends State<PantallaReproductorVideo> {
  VideoPlayerController? _controller;
  bool _inicializando = true;
  bool _yaReanudo = false;
  double _velocidad = 1.0;
  Timer? _timerGuardado;

  @override
  void initState() {
    super.initState();
    _inicializarVideo();
  }

  Future<void> _inicializarVideo() async {
    try {
      final controller = VideoPlayerController.file(File(widget.libro.rutaLocal));
      await controller.initialize();
      controller.addListener(_alCambiarPosicion);
      if (mounted) {
        setState(() {
          _controller = controller;
          _inicializando = false;
        });
      }
      if (widget.libro.posicionMs > 0 && !_yaReanudo) {
        _yaReanudo = true;
        await controller.seekTo(Duration(milliseconds: widget.libro.posicionMs));
      }
      _timerGuardado = Timer.periodic(const Duration(seconds: 5), (_) {
        if (_controller != null && _controller!.value.isInitialized) {
          widget.libro.posicionMs = _controller!.value.position.inMilliseconds;
        }
      });
    } catch (e) {
      debugPrint('Error inicializando video: $e');
      if (mounted) setState(() => _inicializando = false);
    }
  }

  void _alCambiarPosicion() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final valor = _controller!.value;
    widget.libro.posicionMs = valor.position.inMilliseconds;
    if (valor.duration.inMilliseconds > 0 && valor.position >= valor.duration - const Duration(seconds: 1)) {
      widget.libro.leido = true;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timerGuardado?.cancel();
    _controller?.removeListener(_alCambiarPosicion);
    _controller?.dispose();
    super.dispose();
  }

  void _cambiarVelocidad(double v) {
    setState(() => _velocidad = v);
    _controller?.setPlaybackSpeed(v);
  }

  void _saltarSegundos(int segundos) {
    if (_controller == null) return;
    final actual = _controller!.value.position;
    final total = _controller!.value.duration;
    Duration nueva = actual + Duration(seconds: segundos);
    if (nueva < Duration.zero) nueva = Duration.zero;
    if (nueva > total) nueva = total;
    _controller!.seekTo(nueva);
  }

  String _formatDuration(Duration d) {
    String min = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    String sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "${d.inHours > 0 ? '${d.inHours}:' : ''}$min:$sec";
  }

  @override
  Widget build(BuildContext context) {
    final bool listo = _controller != null && _controller!.value.isInitialized;
    final Duration posicion = listo ? _controller!.value.position : Duration.zero;
    final Duration duracion = listo ? _controller!.value.duration : Duration.zero;

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: ColoresApp.fondoPrincipal,
          title: Text(widget.libro.titulo, style: const TextStyle(fontSize: 15)),
        ),
        body: Column(
          children: [
            Expanded(
              child: Center(
                child: _inicializando
                    ? const CircularProgressIndicator(color: ColoresApp.acento)
                    : listo
                        ? AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                VideoPlayer(_controller!),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
                                    });
                                  },
                                  child: Container(
                                    color: Colors.transparent,
                                    child: !_controller!.value.isPlaying
                                        ? const Icon(Icons.play_circle_fill, size: 70, color: ColoresApp.acento)
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const Text('No se pudo cargar el video.', style: TextStyle(color: Colors.white)),
              ),
            ),
            if (listo)
              Container(
                color: ColoresApp.fondoPrincipal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    Slider(
                      value: posicion.inSeconds
                          .toDouble()
                          .clamp(0.0, duracion.inSeconds > 0 ? duracion.inSeconds.toDouble() : 1.0),
                      max: duracion.inSeconds > 0 ? duracion.inSeconds.toDouble() : 1.0,
                      activeColor: ColoresApp.acento,
                      onChanged: (val) => _controller!.seekTo(Duration(seconds: val.toInt())),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(posicion), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        Text(_formatDuration(duracion), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                            icon: const Icon(Icons.replay_10, color: Colors.white),
                            onPressed: () => _saltarSegundos(-10)),
                        IconButton(
                          iconSize: 50,
                          icon: Icon(_controller!.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                              color: ColoresApp.acento),
                          onPressed: () {
                            setState(() {
                              _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
                            });
                          },
                        ),
                        IconButton(
                            icon: const Icon(Icons.forward_10, color: Colors.white),
                            onPressed: () => _saltarSegundos(10)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Velocidad:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(width: 8),
                        _chipVelocidad(1.0, '1.0x'),
                        _chipVelocidad(1.25, '1.25x'),
                        _chipVelocidad(1.5, '1.5x'),
                        _chipVelocidad(2.0, '2.0x'),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chipVelocidad(double val, String label) {
    bool seleccionado = _velocidad == val;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3.0),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 10, color: seleccionado ? Colors.white : Colors.grey)),
        selected: seleccionado,
        selectedColor: ColoresApp.acentoOscuro,
        backgroundColor: ColoresApp.fondoTarjeta,
        onSelected: (bool selected) => _cambiarVelocidad(val),
      ),
    );
  }
}

class PantallaLectorPDF extends StatefulWidget {
  final Libro libro;
  final AjustesApp ajustes;
  final List<PistaMusica> pistasMusica;
  final VoidCallback onCambio;

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
  int totalPaginas = 0;
  int paginaActual = 0;
  bool cargandoDocumento = true;
  bool modoResaltadorActivo = false;
  bool modoBorradorActivo = false;
  bool mostrarControlesLector = true;
  Color colorResaltadorActual = Colors.yellow;
  double opacidadResaltadorActual = 0.3;

  final AudioPlayer _playerEfectoPagina = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  bool estaLeyendoVoz = false;
  PDFViewController? _pdfViewController;

  @override
  void initState() {
    super.initState();
    _initTtsPdf();
    _initPlayerEfecto();
  }

  Future<void> _initPlayerEfecto() async {
    try {
      await _playerEfectoPagina.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          audioFocus: AndroidAudioFocus.none,
          usageType: AndroidUsageType.media,
          contentType: AndroidContentType.music,
          audioMode: AndroidAudioMode.normal,
          stayAwake: false,
          isSpeakerphoneOn: false,
        ),
      ));
      final nombreActual = widget.ajustes.nombreSonidoActual;
      final rutaAsset = TonosEfectos.lista[nombreActual] ?? 'sounds/effect_1.mp3';
      await _playerEfectoPagina.setSource(AssetSource(rutaAsset));
    } catch (e) {
      debugPrint('Error inicializando efecto de página: $e');
    }
  }

  void _initTtsPdf() async {
    try {
      await NarradoresConfig.aplicarNarrador(
        _flutterTts,
        widget.ajustes.narradorSeleccionado,
        rate: widget.ajustes.velocidadVoz * 0.45,
      );
      _flutterTts.setCompletionHandler(() async {
        if (mounted && estaLeyendoVoz) {
          if (paginaActual < totalPaginas - 1) {
            final proximaPagina = paginaActual + 1;
            await _pdfViewController?.setPage(proximaPagina);
            if (!mounted) return;
            setState(() {
              paginaActual = proximaPagina;
            });
            await _leerTextoPaginaPdf(proximaPagina);
          } else {
            setState(() => estaLeyendoVoz = false);
          }
        }
      });
    } catch (e) {
      debugPrint('Error inicializando TTS en PDF: $e');
    }
  }

  Future<void> _toggleLecturaVozPdf() async {
    try {
      if (estaLeyendoVoz) {
        await _flutterTts.stop();
        if (!mounted) return;
        setState(() => estaLeyendoVoz = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⏸️ Lectura en voz alta pausada'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        if (!mounted) return;
        setState(() => estaLeyendoVoz = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🗣️ Leyendo página ${paginaActual + 1} en Español Latino...'),
            duration: const Duration(seconds: 2),
          ),
        );
        await _leerTextoPaginaPdf(paginaActual);
      }
    } catch (e) {
      debugPrint('Error en voz PDF: $e');
      if (!mounted) return;
      setState(() => estaLeyendoVoz = false);
    }
  }

  Future<void> _leerTextoPaginaPdf(int numPagina) async {
    try {
      final file = File(widget.libro.rutaLocal);
      if (!await file.exists()) {
        await _flutterTts.speak("Página ${numPagina + 1}");
        return;
      }
      final bytes = await file.readAsBytes();
      final syncpdf.PdfDocument document = syncpdf.PdfDocument(inputBytes: bytes);
      final String textoPagina = syncpdf.PdfTextExtractor(document).extractText(
        startPageIndex: numPagina,
        endPageIndex: numPagina,
      ).trim();
      document.dispose();

      if (!mounted || !estaLeyendoVoz) return;

      if (textoPagina.isNotEmpty) {
        final textoProcesado = TextProcessorTTS.prepararTextoParaTTS(textoPagina);
        await _flutterTts.speak(textoProcesado);
      } else {
        await _flutterTts.speak("Página ${numPagina + 1}");
      }
    } catch (e) {
      debugPrint('Error leyendo párrafo PDF: $e');
      await _flutterTts.speak("Leyendo página ${numPagina + 1}");
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _flutterTts.stop();
    _playerEfectoPagina.dispose();
    super.dispose();
  }

  Future<void> _reproducirSonidoPagina() async {
    if (!widget.ajustes.sonidoActivado) return;
    try {
      final nombreActual = widget.ajustes.nombreSonidoActual;
      final rutaAsset = TonosEfectos.lista[nombreActual] ?? 'sounds/effect_1.mp3';
      await _playerEfectoPagina.stop();
      await _playerEfectoPagina.setVolume(widget.ajustes.volumenEfecto);
      await _playerEfectoPagina.play(AssetSource(rutaAsset));
    } catch (e) {
      debugPrint('Error reproduciendo sonido de página: $e');
    }
  }

  void _mostrarVisorInterno(String titulo, String urlBusqueda) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PantallaVisorWebCompleto(titulo: titulo, url: urlBusqueda)),
    );
  }

  void _manejarAccionResaltador(DragUpdateDetails details) {
    final double x = details.localPosition.dx;
    final double y = details.localPosition.dy;
    setState(() {
      if (modoResaltadorActivo) {
        widget.libro.resaltados.add(
          AreaResaltada(
            pagina: paginaActual,
            x: x - 20,
            y: y - 10,
            ancho: 40,
            alto: 22,
            color: colorResaltadorActual,
            opacidad: opacidadResaltadorActual,
          ),
        );
      } else if (modoBorradorActivo) {
        widget.libro.resaltados.removeWhere((r) {
          if (r.pagina != paginaActual) return false;
          return (x >= r.x - 15 && x <= r.x + r.ancho + 15) && (y >= r.y - 15 && y <= r.y + r.alto + 15);
        });
      }
    });
    widget.onCambio();
  }

  void _mostrarMenuPersonalizacionResaltador() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ColoresApp.fondoTarjeta,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🎨 Personalizar Resaltador',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    const Text('Selecciona el color del marcador:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _botonColor(Colors.yellow, setModalState),
                        _botonColor(Colors.greenAccent, setModalState),
                        _botonColor(Colors.pinkAccent, setModalState),
                        _botonColor(Colors.lightBlueAccent, setModalState),
                        _botonColor(Colors.orangeAccent, setModalState),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Opacidad del trazo:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        Text('${(opacidadResaltadorActual * 100).toInt()}%',
                            style: const TextStyle(color: ColoresApp.acento, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Slider(
                      value: opacidadResaltadorActual,
                      min: 0.1,
                      max: 0.8,
                      activeColor: ColoresApp.acento,
                      onChanged: (v) {
                        setModalState(() => opacidadResaltadorActual = v);
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _botonColor(Color color, StateSetter setModalState) {
    bool seleccionado = colorResaltadorActual == color;
    return GestureDetector(
      onTap: () {
        setModalState(() => colorResaltadorActual = color);
        setState(() => colorResaltadorActual = color);
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: seleccionado ? Colors.white : Colors.transparent, width: 3),
          boxShadow: [if (seleccionado) const BoxShadow(color: Colors.black45, blurRadius: 6)],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double porcentajeLectura = totalPaginas > 0 ? ((paginaActual + 1) / totalPaginas) * 100 : 0;
    final List<AreaResaltada> resaltadosActuales = widget.libro.resaltadosDePagina(paginaActual);
    final bool modoSepia = widget.ajustes.modoSepia;
    final bool modoOscuro = widget.ajustes.modoOscuro;

    return SafeArea(
      child: Scaffold(
        backgroundColor: modoSepia ? const Color(0xFFF4ECD8) : (modoOscuro ? const Color(0xFF121212) : const Color(0xFFF5F5F5)),
        appBar: mostrarControlesLector
            ? AppBar(
                backgroundColor: ColoresApp.fondoPrincipal,
                title: Text(widget.libro.titulo, style: const TextStyle(fontSize: 14)),
                actions: [
                  MiniReproductorMusicaFondo(pistas: widget.pistasMusica),
                  IconButton(
                    icon: Icon(estaLeyendoVoz ? Icons.stop_circle : Icons.volume_up, color: ColoresApp.acento),
                    tooltip: 'Leer página en voz alta',
                    onPressed: _toggleLecturaVozPdf,
                  ),
                  IconButton(
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    icon: Icon(Icons.highlight, color: modoResaltadorActivo ? colorResaltadorActual : Colors.grey, size: 20),
                    tooltip: 'Activar Resaltador',
                    onPressed: () {
                      setState(() {
                        modoResaltadorActivo = !modoResaltadorActivo;
                        if (modoResaltadorActivo) modoBorradorActivo = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(modoResaltadorActivo ? '✍️ Resaltador ACTIVO' : 'Resaltador desactivado'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    icon: Icon(Icons.cleaning_services_rounded, color: modoBorradorActivo ? Colors.redAccent : Colors.grey, size: 20),
                    tooltip: 'Activar Borrador',
                    onPressed: () {
                      setState(() {
                        modoBorradorActivo = !modoBorradorActivo;
                        if (modoBorradorActivo) modoResaltadorActivo = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(modoBorradorActivo
                              ? '🧹 Borrador ACTIVO: Pasa el dedo sobre lo resaltado para borrar'
                              : 'Borrador desactivado'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                    tooltip: 'Opciones de anotación',
                    onSelected: (val) {
                      if (val == 'config_resaltador') {
                        _mostrarMenuPersonalizacionResaltador();
                      } else if (val == 'limpiar_pagina') {
                        setState(() {
                          widget.libro.resaltados.removeWhere((r) => r.pagina == paginaActual);
                        });
                        widget.onCambio();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('🗑️ Resaltados borrados en esta página')),
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'config_resaltador',
                        child: Row(children: [
                          Icon(Icons.palette, color: ColoresApp.acento, size: 20),
                          SizedBox(width: 10),
                          Text('Ajustar color y opacidad'),
                        ]),
                      ),
                      const PopupMenuItem(
                        value: 'limpiar_pagina',
                        child: Row(children: [
                          Icon(Icons.delete_sweep, color: Colors.redAccent, size: 20),
                          SizedBox(width: 10),
                          Text('Borrar todos los resaltados de esta página'),
                        ]),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${paginaActual + 1} / $totalPaginas', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          Text('${porcentajeLectura.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 9, color: ColoresApp.acento)),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : null,
        body: Stack(
          children: [
            Positioned.fill(
              child: Stack(
                children: [
                  Opacity(
                    opacity: widget.ajustes.nivelBrillo.clamp(0.1, 1.0),
                    child: Stack(
                      children: [
                        PDFView(
                          filePath: widget.libro.rutaLocal,
                          enableSwipe: true,
                          swipeHorizontal: true,
                          pageSnap: true,
                          autoSpacing: false,
                          pageFling: true,
                          defaultPage: widget.libro.ultimaPagina > 0 ? widget.libro.ultimaPagina - 1 : 0,
                          onViewCreated: (controller) => _pdfViewController = controller,
                          onRender: (pages) => setState(() {
                            totalPaginas = pages ?? 0;
                            cargandoDocumento = false;
                          }),
                          onError: (error) {
                            debugPrint('Error al renderizar PDF: $error');
                          },
                          onPageChanged: (int? page, int? total) {
                            if (page != null && page != paginaActual) {
                              _reproducirSonidoPagina();
                              setState(() {
                                paginaActual = page;
                                widget.libro.ultimaPagina = page + 1;
                                if (total != null && total > 0 && page == total - 1) {
                                  widget.libro.leido = true;
                                }
                              });
                              widget.onCambio();
                            }
                          },
                        ),
                        Positioned.fill(
                          child: (modoResaltadorActivo || modoBorradorActivo)
                              ? GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onPanUpdate: _manejarAccionResaltador,
                                  child: _capaResaltados(resaltadosActuales),
                                )
                              : IgnorePointer(child: _capaResaltados(resaltadosActuales)),
                        ),
                      ],
                    ),
                  ),
                  if (widget.ajustes.filtroLuzAzul)
                    IgnorePointer(
                      child: Container(color: Colors.amber.withValues(alpha: 0.2)),
                    ),
                  Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        setState(() {
                          mostrarControlesLector = !mostrarControlesLector;
                          if (mostrarControlesLector) {
                            SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                          } else {
                            SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                          }
                        });
                      },
                      child: Container(width: 150, height: 250, color: Colors.transparent),
                    ),
                  ),
                ],
              ),
            ),
            if (cargandoDocumento)
              Container(
                color: ColoresApp.fondoPrincipal,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: ColoresApp.acento),
                      SizedBox(height: 16),
                      Text('Cargando libro...', style: TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            if (mostrarControlesLector)
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: ColoresApp.fondoTarjeta.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4)),
                      ],
                      border: Border.all(color: ColoresApp.acento.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                          icon: const Icon(Icons.search, color: ColoresApp.acento, size: 20),
                          tooltip: 'Wikipedia / Diccionario',
                          onPressed: () {
                            _mostrarVisorInterno(
                              'Diccionario / Wikipedia',
                              'https://es.wikipedia.org/wiki/Special:Search?search=${Uri.encodeComponent(widget.libro.titulo)}',
                            );
                          },
                        ),
                        Container(
                          height: 20,
                          width: 1,
                          color: Colors.white24,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        IconButton(
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                          icon: const Icon(Icons.translate, color: Colors.amberAccent, size: 20),
                          tooltip: 'Traductor Rápido',
                          onPressed: () {
                            _mostrarVisorInterno('Traductor Web', 'https://translate.google.com');
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          mini: true,
          backgroundColor: ColoresApp.acentoOscuro.withValues(alpha: 0.9),
          tooltip: mostrarControlesLector ? 'Marcar página actual' : 'Mostrar controles',
          onPressed: () {
            if (mostrarControlesLector) {
              setState(() {
                widget.libro.marcadores.add(Marcador(pagina: paginaActual + 1, etiqueta: 'Pág. ${paginaActual + 1}'));
              });
              widget.onCambio();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('📌 ¡Página marcada con éxito!'), duration: Duration(seconds: 1)),
              );
            } else {
              setState(() {
                mostrarControlesLector = true;
                SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
              });
            }
          },
          child: Icon(mostrarControlesLector ? Icons.bookmark_add_rounded : Icons.menu, color: Colors.white),
        ),
      ),
    );
  }

  Widget _capaResaltados(List<AreaResaltada> resaltados) {
    return Stack(
      children: resaltados.map((r) {
        return Positioned(
          left: r.x,
          top: r.y,
          child: Container(
            width: r.ancho,
            height: r.alto,
            decoration: BoxDecoration(color: r.color.withValues(alpha: r.opacidad), borderRadius: BorderRadius.circular(3)),
          ),
        );
      }).toList(),
    );
  }
}

class PantallaLectorEpub extends StatefulWidget {
  final Libro libro;
  final AjustesApp ajustes;
  final List<PistaMusica> pistasMusica;

  const PantallaLectorEpub({
    super.key,
    required this.libro,
    required this.ajustes,
    this.pistasMusica = const [],
  });

  @override
  State<PantallaLectorEpub> createState() => _PantallaLectorEpubState();
}

class _PantallaLectorEpubState extends State<PantallaLectorEpub> {
  epubx.EpubBook? _epubBook;
  bool _cargando = true;
  double _tamanioFuente = 18.0;
  bool mostrarControlesEpub = true;
  final FlutterTts _flutterTts = FlutterTts();
  bool estaLeyendoVoz = false;
  int? capituloLeyendoIndex;

  @override
  void initState() {
    super.initState();
    _cargarEpub();
    _initTts();
  }

  void _initTts() async {
    try {
      await NarradoresConfig.aplicarNarrador(
        _flutterTts,
        widget.ajustes.narradorSeleccionado,
        rate: widget.ajustes.velocidadVoz * 0.45,
      );
      _flutterTts.setCompletionHandler(() {
        if (mounted) {
          setState(() {
            estaLeyendoVoz = false;
            capituloLeyendoIndex = null;
          });
        }
      });
    } catch (e) {
      debugPrint('Error inicializando TTS en EPUB: $e');
    }
  }

  Future<void> _cargarEpub() async {
    try {
      final file = File(widget.libro.rutaLocal);
      final bytes = await file.readAsBytes();
      final book = await epubx.EpubReader.readBook(bytes);
      if (mounted) {
        setState(() {
          _epubBook = book;
          _cargando = false;
        });
      }
    } catch (e) {
      debugPrint('Error al leer EPUB: $e');
      if (mounted) {
        setState(() => _cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al leer EPUB: $e')));
      }
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _toggleLecturaVozCapitulo(int index, String textoCapitulo) async {
    try {
      final bool esElMismoCapitulo = capituloLeyendoIndex == index;
      if (estaLeyendoVoz && esElMismoCapitulo) {
        await _flutterTts.stop();
        if (!mounted) return;
        setState(() {
          estaLeyendoVoz = false;
          capituloLeyendoIndex = null;
        });
        return;
      }
      if (textoCapitulo.trim().isEmpty) return;
      if (estaLeyendoVoz) {
        await _flutterTts.stop();
      }
      final textoProcesado = TextProcessorTTS.prepararTextoParaTTS(textoCapitulo);
      if (!mounted) return;
      setState(() {
        estaLeyendoVoz = true;
        capituloLeyendoIndex = index;
      });
      await _flutterTts.speak(textoProcesado);
    } catch (e) {
      debugPrint('Error en lectura de voz: $e');
    }
  }

  void _mostrarVisorInterno(String titulo, String urlBusqueda) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PantallaVisorWebCompleto(titulo: titulo, url: urlBusqueda)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.ajustes.modoSepia ? const Color(0xFFF4ECD8) : (widget.ajustes.modoOscuro ? const Color(0xFF121212) : const Color(0xFFF5F5F5));
    final textColor = widget.ajustes.modoSepia ? Colors.black87 : (widget.ajustes.modoOscuro ? Colors.white70 : Colors.black87);
    final capitulos = _epubBook?.Chapters ?? <epubx.EpubChapter>[];

    return SafeArea(
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: mostrarControlesEpub
            ? AppBar(
                backgroundColor: ColoresApp.fondoPrincipal,
                title: Text(widget.libro.titulo, style: const TextStyle(fontSize: 14)),
                actions: [
                  MiniReproductorMusicaFondo(pistas: widget.pistasMusica),
                  IconButton(
                    icon: const Icon(Icons.text_decrease),
                    onPressed: () => setState(() => _tamanioFuente = (_tamanioFuente - 2).clamp(12.0, 36.0)),
                  ),
                  Center(child: Text('${_tamanioFuente.toInt()}px', style: const TextStyle(fontSize: 12))),
                  IconButton(
                    icon: const Icon(Icons.text_increase),
                    onPressed: () => setState(() => _tamanioFuente = (_tamanioFuente + 2).clamp(12.0, 36.0)),
                  ),
                ],
              )
            : null,
        body: Stack(
          children: [
            Positioned.fill(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator(color: ColoresApp.acento))
                  : capitulos.isEmpty
                      ? const Center(child: Text('No se pudieron leer los capítulos del EPUB.'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: capitulos.length,
                          itemBuilder: (context, index) {
                            final chapter = capitulos[index];
                            final tituloCapitulo = chapter.Title ?? 'Capítulo ${index + 1}';
                            final contenidoHtml = chapter.HtmlContent ?? '';
                            final leyendoEsteCapitulo = estaLeyendoVoz && capituloLeyendoIndex == index;

                            return ExpansionTile(
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(tituloCapitulo,
                                        style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 16)),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      leyendoEsteCapitulo ? Icons.stop_circle : Icons.volume_up,
                                      color: ColoresApp.acento,
                                      size: 22,
                                    ),
                                    tooltip: 'Leer este capítulo en voz alta',
                                    onPressed: () => _toggleLecturaVozCapitulo(index, contenidoHtml),
                                  ),
                                ],
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                  child: SelectionArea(
                                    child: Html(
                                      data: contenidoHtml,
                                      style: {
                                        "body": Style(
                                          fontSize: FontSize(_tamanioFuente),
                                          color: textColor,
                                          lineHeight: LineHeight.number(1.5),
                                        ),
                                        "p": Style(fontSize: FontSize(_tamanioFuente), color: textColor),
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
            ),
            Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    mostrarControlesEpub = !mostrarControlesEpub;
                    if (mostrarControlesEpub) {
                      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                    } else {
                      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                    }
                  });
                },
                child: Container(width: 150, height: 250, color: Colors.transparent),
              ),
            ),
            if (mostrarControlesEpub)
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: ColoresApp.fondoTarjeta.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4)),
                      ],
                      border: Border.all(color: ColoresApp.acento.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                          icon: const Icon(Icons.search, color: ColoresApp.acento, size: 20),
                          tooltip: 'Wikipedia / Diccionario',
                          onPressed: () {
                            _mostrarVisorInterno(
                              'Diccionario / Wikipedia',
                              'https://es.wikipedia.org/wiki/Special:Search?search=${Uri.encodeComponent(widget.libro.titulo)}',
                            );
                          },
                        ),
                        Container(
                          height: 20,
                          width: 1,
                          color: Colors.white24,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        IconButton(
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                          icon: const Icon(Icons.translate, color: Colors.amberAccent, size: 20),
                          tooltip: 'Traductor Rápido',
                          onPressed: () {
                            _mostrarVisorInterno('Traductor Web', 'https://translate.google.com');
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          mini: true,
          backgroundColor: ColoresApp.acentoOscuro.withValues(alpha: 0.9),
          tooltip: 'Mostrar u ocultar controles',
          onPressed: () {
            setState(() {
              mostrarControlesEpub = !mostrarControlesEpub;
              if (mostrarControlesEpub) {
                SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
              } else {
                SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
              }
            });
          },
          child: Icon(mostrarControlesEpub ? Icons.menu_book : Icons.menu, color: Colors.white),
        ),
      ),
    );
  }
}

class PantallaLectorDocx extends StatefulWidget {
  final Libro libro;
  final AjustesApp ajustes;
  final List<PistaMusica> pistasMusica;

  const PantallaLectorDocx({
    super.key,
    required this.libro,
    required this.ajustes,
    this.pistasMusica = const [],
  });

  @override
  State<PantallaLectorDocx> createState() => _PantallaLectorDocxState();
}

class _PantallaLectorDocxState extends State<PantallaLectorDocx> {
  String _contenidoTexto = '';
  bool _cargando = true;
  double _tamanioFuente = 18.0;
  bool mostrarControlesDocx = true;
  final FlutterTts _flutterTts = FlutterTts();
  bool estaLeyendoVoz = false;

  @override
  void initState() {
    super.initState();
    _cargarDocx();
    _initTtsDocx();
  }

  void _initTtsDocx() async {
    try {
      await NarradoresConfig.aplicarNarrador(
        _flutterTts,
        widget.ajustes.narradorSeleccionado,
        rate: widget.ajustes.velocidadVoz * 0.45,
      );
      _flutterTts.setCompletionHandler(() {
        if (mounted) {
          setState(() {
            estaLeyendoVoz = false;
          });
        }
      });
    } catch (e) {
      debugPrint('Error inicializando TTS en DOCX: $e');
    }
  }

  Future<void> _cargarDocx() async {
    try {
      final file = File(widget.libro.rutaLocal);
      final bytes = await file.readAsBytes();
      final texto = analizarDocxBytes(bytes);
      if (mounted) {
        setState(() {
          _contenidoTexto = texto;
          _cargando = false;
        });
      }
    } catch (e) {
      debugPrint('Error al leer DOCX: $e');
      if (mounted) {
        setState(() {
          _contenidoTexto = 'Error al leer archivo Word: $e';
          _cargando = false;
        });
      }
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _toggleLecturaVozDocx() async {
    try {
      if (estaLeyendoVoz) {
        await _flutterTts.stop();
        if (!mounted) return;
        setState(() => estaLeyendoVoz = false);
      } else {
        if (_contenidoTexto.trim().isEmpty) return;
        if (!mounted) return;
        setState(() => estaLeyendoVoz = true);
        final textoProcesado = TextProcessorTTS.prepararTextoParaTTS(_contenidoTexto);
        await _flutterTts.speak(textoProcesado);
      }
    } catch (e) {
      debugPrint('Error en lectura de voz DOCX: $e');
    }
  }

  void _mostrarVisorInterno(String titulo, String urlBusqueda) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PantallaVisorWebCompleto(titulo: titulo, url: urlBusqueda)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.ajustes.modoSepia ? const Color(0xFFF4ECD8) : (widget.ajustes.modoOscuro ? const Color(0xFF121212) : const Color(0xFFF5F5F5));
    final textColor = widget.ajustes.modoSepia ? Colors.black87 : (widget.ajustes.modoOscuro ? Colors.white70 : Colors.black87);

    return SafeArea(
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: mostrarControlesDocx
            ? AppBar(
                backgroundColor: ColoresApp.fondoPrincipal,
                title: Text(widget.libro.titulo, style: const TextStyle(fontSize: 14)),
                actions: [
                  MiniReproductorMusicaFondo(pistas: widget.pistasMusica),
                  IconButton(
                    icon: Icon(estaLeyendoVoz ? Icons.stop_circle : Icons.volume_up, color: ColoresApp.acento),
                    tooltip: 'Leer documento en voz alta',
                    onPressed: _toggleLecturaVozDocx,
                  ),
                  IconButton(
                    icon: const Icon(Icons.text_decrease),
                    onPressed: () => setState(() => _tamanioFuente = (_tamanioFuente - 2).clamp(12.0, 36.0)),
                  ),
                  Center(child: Text('${_tamanioFuente.toInt()}px', style: const TextStyle(fontSize: 12))),
                  IconButton(
                    icon: const Icon(Icons.text_increase),
                    onPressed: () => setState(() => _tamanioFuente = (_tamanioFuente + 2).clamp(12.0, 36.0)),
                  ),
                ],
              )
            : null,
        body: Stack(
          children: [
            Positioned.fill(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator(color: ColoresApp.acento))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: SelectionArea(
                        child: Text(
                          _contenidoTexto,
                          style: TextStyle(
                            fontSize: _tamanioFuente,
                            color: textColor,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ),
            ),
            Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    mostrarControlesDocx = !mostrarControlesDocx;
                    if (mostrarControlesDocx) {
                      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                    } else {
                      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                    }
                  });
                },
                child: Container(width: 150, height: 250, color: Colors.transparent),
              ),
            ),
            if (mostrarControlesDocx)
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: ColoresApp.fondoTarjeta.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4)),
                      ],
                      border: Border.all(color: ColoresApp.acento.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                          icon: const Icon(Icons.search, color: ColoresApp.acento, size: 20),
                          tooltip: 'Wikipedia / Diccionario',
                          onPressed: () {
                            _mostrarVisorInterno(
                              'Diccionario / Wikipedia',
                              'https://es.wikipedia.org/wiki/Special:Search?search=${Uri.encodeComponent(widget.libro.titulo)}',
                            );
                          },
                        ),
                        Container(
                          height: 20,
                          width: 1,
                          color: Colors.white24,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        IconButton(
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                          icon: const Icon(Icons.translate, color: Colors.amberAccent, size: 20),
                          tooltip: 'Traductor Rápido',
                          onPressed: () {
                            _mostrarVisorInterno('Traductor Web', 'https://translate.google.com');
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          mini: true,
          backgroundColor: ColoresApp.acentoOscuro.withValues(alpha: 0.9),
          tooltip: 'Mostrar u ocultar controles',
          onPressed: () {
            setState(() {
              mostrarControlesDocx = !mostrarControlesDocx;
              if (mostrarControlesDocx) {
                SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
              } else {
                SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
              }
            });
          },
          child: Icon(mostrarControlesDocx ? Icons.description : Icons.menu, color: Colors.white),
        ),
      ),
    );
  }
}

class PantallaPrincipalMiLector extends StatefulWidget {
  const PantallaPrincipalMiLector({super.key});

  @override
  State<PantallaPrincipalMiLector> createState() => _PantallaPrincipalMiLectorState();
}

class _PantallaPrincipalMiLectorState extends State<PantallaPrincipalMiLector> with WidgetsBindingObserver {
  final BibliotecaRepository _repo = BibliotecaRepository();
  final Debouncer _debouncer = Debouncer(milliseconds: 300);
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final AudioPlayer _previewPlayerEfecto = AudioPlayer();
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  bool _tieneAcceso = true;
  bool _cargandoLicencia = true;
  List<ProductDetails> _productos = [];

  List<Libro> libros = [];
  List<Libro> librosMostrados = [];
  List<PistaMusica> pistasMusica = [];
  List<String> misCategorias = ['Todas', 'General'];
  String categoriaSeleccionada = 'Todas';
  String seccionActual = 'biblioteca';
  final TextEditingController _searchController = TextEditingController();
  bool buscando = false;
  bool _cargandoInicial = true;
  int columnasGrid = 3;
  AjustesApp ajustes = AjustesApp();

  void _comprarSuscripcion() {
    if (_productos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La tienda aún está cargando los productos. Intenta de nuevo.')),
      );
      return;
    }
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: _productos.first);
    _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> _inicializarTienda() async {
    final bool disponible = await _inAppPurchase.isAvailable();
    if (!disponible) {
      return;
    }
    const Set<String> kIdsProductos = <String>{'suscripcion_anual_lector'};
    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(kIdsProductos);
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('Los productos no se encontraron en la Google Play Console.');
    }
    setState(() {
      _productos = response.productDetails;
    });
  }

  void _procesarActualizacionesCompra(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('acceso_permanente_comprado', true);
        setState(() {
          _tieneAcceso = true;
        });
      }
      if (purchaseDetails.pendingCompletePurchase) {
        _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AudioGlobal().init();
    _cargarBibliotecaYAjustes();

    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _procesarActualizacionesCompra(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      debugPrint('Error en la pasarela de pagos: $error');
    });
    _inicializarTienda();

    _searchController.addListener(() {
      _debouncer.run(() {
        _aplicarFiltroSeccion();
      });
    });

    _verificarAccesoApp();
  }

  Future<void> _verificarAccesoApp() async {
    final prefs = await SharedPreferences.getInstance();
    bool yaCompro = prefs.getBool('acceso_permanente_comprado') ?? false;
    if (yaCompro) {
      setState(() {
        _tieneAcceso = true;
        _cargandoLicencia = false;
      });
      return;
    }

    String? fechaInstalacionStr = prefs.getString('fecha_instalacion_app');
    DateTime fechaInstalacion;
    if (fechaInstalacionStr == null) {
      fechaInstalacion = DateTime.now();
      await prefs.setString('fecha_instalacion_app', fechaInstalacion.toIso8601String());
    } else {
      fechaInstalacion = DateTime.parse(fechaInstalacionStr);
    }

    final diasTranscurridos = DateTime.now().difference(fechaInstalacion).inDays;

    if (diasTranscurridos <= 12) {
      setState(() {
        _tieneAcceso = true;
        _cargandoLicencia = false;
      });
    } else {
      setState(() {
        _tieneAcceso = false;
        _cargandoLicencia = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _debouncer.dispose();
    _subscription.cancel();
    _previewPlayerEfecto.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (AudioGlobal().sonando && AudioGlobal().tituloActual != null) {
        AudioGlobal().player.resume();
      }
    }
  }

  Future<void> _cargarBibliotecaYAjustes() async {
    try {
      final brilloSistema = PlatformDispatcher.instance.platformBrightness;
      final esOscuroSistema = brilloSistema == Brightness.dark;
      final ajustesCargados = await _repo.cargarAjustes(esOscuroSistemaPorDefecto: esOscuroSistema);
      final categorias = await _repo.cargarCategorias();
      final librosCargados = await _repo.cargarLibros();
      final pistas = await _repo.cargarPistasMusica();

      TextosIdioma.instancia.inicializarSinNotificar(ajustesCargados.idioma);

      if (!mounted) return;
      setState(() {
        ajustes = ajustesCargados;
        misCategorias = categorias;
        libros = librosCargados;
        pistasMusica = pistas;
        _cargandoInicial = false;
      });

      _aplicarFiltroSeccion();
    } catch (e) {
      debugPrint('Error cargando biblioteca y ajustes: $e');
      if (mounted) setState(() => _cargandoInicial = false);
    }
  }

  Future<void> _guardarAjustes() async {
    await _repo.guardarAjustes(ajustes);
  }

  Future<void> _guardarBiblioteca() async {
    await _repo.guardarLibros(libros);
    await _repo.guardarCategorias(misCategorias);
  }

  Future<void> _guardarPistasMusica() async {
    await _repo.guardarPistasMusica(pistasMusica);
  }

  void _aplicarFiltroSeccion() {
    List<Libro> temp = List.from(libros);

    if (seccionActual == 'audiolibros') {
      temp = temp.where((l) => l.esAudiolibro).toList();
    } else if (seccionActual == 'videos') {
      temp = temp.where((l) => l.esVideo).toList();
    } else if (seccionActual == 'documentos') {
      temp = temp.where((l) => l.esDocx).toList();
    } else if (seccionActual == 'favoritos') {
      temp = temp.where((l) => l.esFavorito).toList();
    } else if (seccionActual == 'porLeer') {
      temp = temp.where((l) => l.porLeer && !l.leido).toList();
    } else if (seccionActual == 'leidos') {
      temp = temp.where((l) => l.leido).toList();
    } else if (seccionActual == 'leyendo') {
      temp = temp.where((l) => l.ultimaPagina > 1 && !l.leido && !l.esVideo).toList();
    } else if (seccionActual == 'biblioteca') {
      temp = temp.where((l) => !l.esAudiolibro && !l.esVideo && !l.esDocx).toList();
    }

    if (categoriaSeleccionada != 'Todas' &&
        seccionActual != 'audiolibros' &&
        seccionActual != 'videos' &&
        seccionActual != 'documentos' &&
        seccionActual != 'estadisticas') {
      temp = temp.where((l) => l.categoria == categoriaSeleccionada).toList();
    }

    final q = _searchController.text.toLowerCase();
    if (q.isNotEmpty) {
      temp = temp.where((l) => l.titulo.toLowerCase().contains(q)).toList();
    }

    if (ajustes.ordenBiblioteca == 'A-Z') {
      temp.sort((a, b) => a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase()));
    } else if (ajustes.ordenBiblioteca == 'Categoría') {
      temp.sort((a, b) => a.categoria.toLowerCase().compareTo(b.categoria.toLowerCase()));
    } else {
      temp.sort((a, b) => b.id.compareTo(a.id));
    }

    if (!mounted) return;
    setState(() => librosMostrados = temp);
  }

  bool _archivoExiste(Libro libro) {
    try {
      return File(libro.rutaLocal).existsSync();
    } catch (e) {
      return false;
    }
  }

  void _avisarArchivoFaltante(Libro libro) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${libro.titulo}" ya no está en el dispositivo.'),
        action: SnackBarAction(
          label: 'Quitar de biblioteca',
          onPressed: () {
            setState(() => libros.removeWhere((l) => l.id == libro.id));
            _guardarBiblioteca();
            _aplicarFiltroSeccion();
          },
        ),
      ),
    );
  }

  Future<void> _abrirLibro(Libro libro) async {
    if (!_archivoExiste(libro)) {
      _avisarArchivoFaltante(libro);
      return;
    }

    if (libro.esAudiolibro) {
      await Navigator.push(context, MaterialPageRoute(builder: (context) => PantallaReproductorAudiolibro(libro: libro)));
    } else if (libro.esVideo) {
      await Navigator.push(context, MaterialPageRoute(builder: (context) => PantallaReproductorVideo(libro: libro)));
    } else if (libro.esEpub) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PantallaLectorEpub(
            libro: libro,
            ajustes: ajustes,
            pistasMusica: pistasMusica,
          ),
        ),
      );
    } else if (libro.esDocx) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PantallaLectorDocx(
            libro: libro,
            ajustes: ajustes,
            pistasMusica: pistasMusica,
          ),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PantallaLectorPDF(
            libro: libro,
            ajustes: ajustes,
            pistasMusica: pistasMusica,
            onCambio: _guardarBiblioteca,
          ),
        ),
      );
    }

    await _guardarBiblioteca();
    _aplicarFiltroSeccion();
  }

  Future<void> _buscarEnWeb(String consulta) async {
    if (consulta.trim().isEmpty) return;
    final url = Uri.parse('https://www.google.com/search?q=${Uri.encodeComponent(consulta)}');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('launchUrl devolvió false');
      }
    } catch (e) {
      debugPrint('Error al abrir navegador web: $e');
    }
  }

  void _crearNuevaCategoria() {
    final catController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ColoresApp.fondoTarjeta,
        title: const Text('Crear nueva categoría/carpeta'),
        content: TextField(
          controller: catController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Ej: Universidad, Programación...',
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ColoresApp.acentoOscuro),
            onPressed: () {
              final nombre = catController.text.trim();
              if (nombre.isNotEmpty && !misCategorias.contains(nombre)) {
                setState(() {
                  misCategorias.add(nombre);
                  categoriaSeleccionada = nombre;
                });
                _aplicarFiltroSeccion();
                _guardarBiblioteca();
              }
              Navigator.pop(context);
            },
            child: const Text('Crear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _gestionarCategoria(String categoria) {
    if (categoria == 'Todas' || categoria == 'General') return;

    showModalBottomSheet(
      context: context,
      backgroundColor: ColoresApp.fondoTarjeta,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.edit, color: ColoresApp.acento),
                  title: const Text('Renombrar categoría', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _renombrarCategoria(categoria);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text('Eliminar categoría', style: TextStyle(color: Colors.redAccent)),
                  subtitle: const Text('Los libros pasarán a "General"', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmarEliminarCategoria(categoria);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _renombrarCategoria(String categoriaActual) {
    final catController = TextEditingController(text: categoriaActual);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ColoresApp.fondoTarjeta,
        title: const Text('Renombrar categoría'),
        content: TextField(
          controller: catController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintStyle: TextStyle(color: Colors.grey)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ColoresApp.acentoOscuro),
            onPressed: () {
              final nuevoNombre = catController.text.trim();
              if (nuevoNombre.isEmpty || nuevoNombre == categoriaActual) {
                Navigator.pop(context);
                return;
              }
              if (misCategorias.contains(nuevoNombre)) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ya existe una categoría con ese nombre')));
                return;
              }
              setState(() {
                final idx = misCategorias.indexOf(categoriaActual);
                if (idx != -1) misCategorias[idx] = nuevoNombre;
                for (final libro in libros) {
                  if (libro.categoria == categoriaActual) libro.categoria = nuevoNombre;
                }
                if (categoriaSeleccionada == categoriaActual) categoriaSeleccionada = nuevoNombre;
              });
              _aplicarFiltroSeccion();
              _guardarBiblioteca();
              Navigator.pop(context);
            },
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmarEliminarCategoria(String categoria) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ColoresApp.fondoTarjeta,
        title: const Text('Eliminar categoría'),
        content: Text('¿Eliminar "$categoria"? Los libros de esta categoría pasarán a "General".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              setState(() {
                misCategorias.remove(categoria);
                for (final libro in libros) {
                  if (libro.categoria == categoria) libro.categoria = 'General';
                }
                if (categoriaSeleccionada == categoria) categoriaSeleccionada = 'Todas';
              });
              _aplicarFiltroSeccion();
              _guardarBiblioteca();
              Navigator.pop(context);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _abrirNotasDelLibro(Libro libro) {
    final notasController = TextEditingController(text: libro.notasPersonales);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ColoresApp.fondoTarjeta,
        title: Row(
          children: [
            const Icon(Icons.note_alt, color: ColoresApp.acento),
            const SizedBox(width: 8),
            Expanded(child: Text('Notas: ${libro.titulo}', maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: notasController,
            maxLines: 8,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Escribe tus apuntes, resúmenes o citas importantes aquí...',
              hintStyle: TextStyle(color: Colors.grey),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ColoresApp.acentoOscuro),
            onPressed: () {
              setState(() => libro.notasPersonales = notasController.text);
              _guardarBiblioteca();
              Navigator.pop(context);
            },
            child: const Text('Guardar Notas', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _cambiarCategoriaLibro(Libro libro) {
    showDialog(
      context: context,
      builder: (context) {
        final opciones = misCategorias.where((c) => c != 'Todas').toList();
        return AlertDialog(
          backgroundColor: ColoresApp.fondoTarjeta,
          title: Text('Categoría para: ${libro.titulo}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: opciones.map((cat) {
              final seleccionada = libro.categoria == cat;
              return ListTile(
                title: Text(cat, style: TextStyle(color: seleccionada ? ColoresApp.acento : Colors.white)),
                trailing: seleccionada ? const Icon(Icons.check, color: ColoresApp.acento) : null,
                onTap: () {
                  setState(() => libro.categoria = cat);
                  _aplicarFiltroSeccion();
                  _guardarBiblioteca();
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _confirmarEliminarLibro(Libro libro) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ColoresApp.fondoTarjeta,
        title: const Text('Eliminar libro'),
        content: Text('¿Seguro que quieres eliminar "${libro.titulo}"? Se perderán sus marcadores y notas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              final indiceOriginal = libros.indexWhere((l) => l.id == libro.id);
              setState(() => libros.removeWhere((l) => l.id == libro.id));
              _guardarBiblioteca();
              _aplicarFiltroSeccion();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('"${libro.titulo}" eliminado'),
                  action: SnackBarAction(
                    label: 'Deshacer',
                    onPressed: () {
                      setState(() {
                        final idx = indiceOriginal.clamp(0, libros.length);
                        libros.insert(idx, libro);
                      });
                      _aplicarFiltroSeccion();
                      _guardarBiblioteca();
                    },
                  ),
                  duration: const Duration(seconds: 5),
                ),
              );
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _cambiarPortadaLibro(Libro libro) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        final appDir = await getApplicationDocumentsDirectory();
        final destPath = '${appDir.path}/portada_custom_${libro.id}.jpg';
        final destFile = File(destPath);
        if (file.bytes != null) {
          await destFile.writeAsBytes(file.bytes!);
        } else if (file.path != null) {
          await File(file.path!).copy(destPath);
        }
        setState(() {
          libro.rutaPortadaCache = destPath;
        });
        await _guardarBiblioteca();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🖼️ ¡Portada personalizada asignada con éxito!'),
              backgroundColor: ColoresApp.acentoOscuro,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error cambiando portada: $e');
    }
  }

  void _mostrarOpcionesLibroRapido(Libro libro) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ColoresApp.fondoTarjeta,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(libro.titulo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 10),
                const Divider(color: Colors.white24),
                ListTile(
                  leading: Icon(libro.esFavorito ? Icons.star : Icons.star_border, color: Colors.amber),
                  title: Text(libro.esFavorito ? 'Quitar de favoritos' : 'Añadir a favoritos', style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => libro.esFavorito = !libro.esFavorito);
                    _guardarBiblioteca();
                    _aplicarFiltroSeccion();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.image_outlined, color: ColoresApp.acento),
                  title: const Text('Cambiar / Asignar portada', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _cambiarPortadaLibro(libro);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.note_alt, color: ColoresApp.acento),
                  title: const Text('Notas personales', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _abrirNotasDelLibro(libro);
                  },
                ),
                if (!libro.esAudiolibro && !libro.esVideo && !libro.esDocx)
                  ListTile(
                    leading: const Icon(Icons.folder_outlined, color: ColoresApp.acento),
                    title: const Text('Cambiar categoría', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      _cambiarCategoriaLibro(libro);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmarEliminarLibro(libro);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _importarArchivo() async {
    HapticFeedback.selectionClick();
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          backgroundColor: ColoresApp.fondoTarjeta,
          content: Row(
            children: [
              CircularProgressIndicator(color: ColoresApp.acento),
              SizedBox(width: 20),
              Text('Abriendo selector...', style: TextStyle(color: Colors.white))
            ],
          ),
        ),
      );
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: false,
        withReadStream: true,
      );

      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (result == null || result.files.isEmpty) return;

      final archivoUnico = result.files.single;
      final nombre = archivoUnico.name;
      final extValidas = ['pdf', 'mp3', 'm4a', 'wav', 'aac', 'epub', 'mp4', 'mov', 'mkv', 'avi', 'docx'];
      final extLower = nombre.contains('.') ? nombre.split('.').last.toLowerCase() : '';

      if (!extValidas.contains(extLower)) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Formato no soportado. Usa PDF, EPUB, Word, MP3 o Video.')));
        }
        return;
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            backgroundColor: ColoresApp.fondoTarjeta,
            content: Row(
              children: [
                CircularProgressIndicator(color: ColoresApp.acento),
                SizedBox(width: 20),
                Text('Importando archivo...', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        );
      }

      final bool esDocx = extLower == 'docx';
      final bool esEpub = extLower == 'epub';
      final bool esAudio = ['mp3', 'm4a', 'wav', 'aac'].contains(extLower);
      final bool esVideo = ['mp4', 'mov', 'mkv', 'avi'].contains(extLower);

      final appDir = await getApplicationDocumentsDirectory();
      final nuevaRuta = '${appDir.path}/${DateTime.now().millisecondsSinceEpoch}_$nombre';
      final archivoDestino = File(nuevaRuta);

      if (archivoUnico.path != null && archivoUnico.path!.isNotEmpty && await File(archivoUnico.path!).exists()) {
        await File(archivoUnico.path!).copy(nuevaRuta);
      } else if (archivoUnico.readStream != null) {
        final sink = archivoDestino.openWrite();
        await for (var chunk in archivoUnico.readStream!) {
          sink.add(chunk);
        }
        await sink.flush();
        await sink.close();
      } else if (archivoUnico.bytes != null && archivoUnico.bytes!.isNotEmpty) {
        await archivoDestino.writeAsBytes(archivoUnico.bytes!);
      } else {
        throw Exception('No se pudo acceder a la ruta o flujo del archivo seleccionado.');
      }

      final catInicial = (categoriaSeleccionada == 'Todas') ? 'General' : categoriaSeleccionada;

      final nuevoLibro = Libro(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        titulo: nombre.replaceAll(RegExp(r'\.(pdf|mp3|m4a|wav|aac|epub|mp4|mov|mkv|avi|docx)$', caseSensitive: false), ''),
        rutaLocal: nuevaRuta,
        categoria: catInicial,
        esAudiolibro: esAudio,
        esEpub: esEpub,
        esVideo: esVideo,
        esDocx: esDocx,
      );

      setState(() {
        libros.add(nuevoLibro);
        if (esAudio) {
          seccionActual = 'audiolibros';
        } else if (esVideo) {
          seccionActual = 'videos';
        } else if (esDocx) {
          seccionActual = 'documentos';
        } else {
          seccionActual = 'biblioteca';
        }
      });

      _aplicarFiltroSeccion();
      await _guardarBiblioteca();

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('📚 ¡Archivo importado con éxito!'), backgroundColor: ColoresApp.acentoOscuro),
        );
      }
    } catch (e) {
      debugPrint('Error crítico al importar archivo: $e');
      if (mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al importar: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _agregarLibroOAudiolibro() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ColoresApp.fondoTarjeta,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('📥 Importar Contenido',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Selecciona un archivo PDF, EPUB, Word, Audiolibro (MP3) o Video.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColoresApp.acentoOscuro,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.folder_open_rounded, color: Colors.white),
                        label: const Text('Explorar Archivos del Dispositivo',
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.pop(context);
                          _importarArchivo();
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _agregarPistaMusica() async {
    try {
      final permisosOk = await PermisosService.solicitarPermisosAlmacenamiento();
      if (!permisosOk) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Se necesita permiso de almacenamiento')));
        }
        return;
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
        withData: false,
        withReadStream: true,
      );
      if (result == null || result.files.isEmpty) return;

      final pickedFile = result.files.single;
      final nombre = pickedFile.name;

      final appDir = await getApplicationDocumentsDirectory();
      final carpetaMusica = Directory('${appDir.path}/musica_fondo');
      if (!await carpetaMusica.exists()) await carpetaMusica.create(recursive: true);
      final nuevaRuta = '${carpetaMusica.path}/${DateTime.now().millisecondsSinceEpoch}_$nombre';
      final archivoDestino = File(nuevaRuta);

      if (pickedFile.path != null && pickedFile.path!.isNotEmpty && await File(pickedFile.path!).exists()) {
        await File(pickedFile.path!).copy(nuevaRuta);
      } else if (pickedFile.readStream != null) {
        final sink = archivoDestino.openWrite();
        await for (var chunk in pickedFile.readStream!) {
          sink.add(chunk);
        }
        await sink.flush();
        await sink.close();
      } else if (pickedFile.bytes != null && pickedFile.bytes!.isNotEmpty) {
        await archivoDestino.writeAsBytes(pickedFile.bytes!);
      } else {
        throw Exception('No se pudo leer la pista seleccionada.');
      }

      final nuevaPista = PistaMusica(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        titulo: nombre.replaceAll(RegExp(r'\.(mp3|m4a|wav|aac|ogg)$', caseSensitive: false), ''),
        rutaLocal: nuevaRuta,
      );

      if (!mounted) return;
      setState(() => pistasMusica.add(nuevaPista));
      await _guardarPistasMusica();

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('"${nuevaPista.titulo}" agregada a tu música')));
      }
    } catch (e) {
      debugPrint('Error agregando pista de música: $e');
    }
  }

  void _eliminarPistaMusica(PistaMusica pista) {
    setState(() => pistasMusica.removeWhere((p) => p.id == pista.id));
    _guardarPistasMusica();
  }

  Future<void> _guardarFondoPreferencias() async {
    await _guardarAjustes();
  }

  void _mostrarModalPersonalizarApariencia() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ColoresApp.fondoTarjeta,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🎨 Personalizar Apariencia',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 6),
                    const Text(
                      'Agrega tu fondo, foto o imagen preferida para darle otro estilo visual.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 20),
                    const Text('Fondos clásicos y cósmicos por defecto:',
                        style: TextStyle(color: ColoresApp.acento, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 80,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: ColoresApp.fondosPorDefecto
                            .map((ruta) => _miniaturaFondo(ruta, setModalState))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text('✨ Colores Sólidos Minimalistas (Magia Visual):',
                        style: TextStyle(color: ColoresApp.acento, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 50,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: ColoresApp.fondosSolidos.entries
                            .map((entry) => _miniaturaColorSolido(entry.key, setModalState))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: ColoresApp.acentoOscuro),
                        icon: const Icon(Icons.photo_library, color: Colors.white),
                        label: const Text('Elegir foto personalizada de la galería',
                            style: TextStyle(color: Colors.white)),
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
                          if (result != null && result.files.single.bytes != null) {
                            final bytesImg = result.files.single.bytes!;
                            final nombreImg = result.files.single.name;
                            final appDir = await getApplicationDocumentsDirectory();
                            final destinoImg = File('${appDir.path}/$nombreImg');
                            await destinoImg.writeAsBytes(bytesImg);

                            if (!mounted) return;
                            setState(() {
                              ajustes.tipoFondo = 'galeria';
                              ajustes.rutaFondoSeleccionado = destinoImg.path;
                              ajustes.colorSolidoId = null;
                            });
                            await _guardarFondoPreferencias();
                            if (!context.mounted) return;
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _miniaturaFondo(String assetPath, StateSetter setModalState) {
    final seleccionada = ajustes.tipoFondo == 'defecto' && ajustes.rutaFondoSeleccionado == assetPath;
    return GestureDetector(
      onTap: () {
        setState(() {
          ajustes.tipoFondo = 'defecto';
          ajustes.rutaFondoSeleccionado = assetPath;
          ajustes.colorSolidoId = null;
        });
        setModalState(() {});
        _guardarFondoPreferencias();
      },
      child: Container(
        width: 60,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: seleccionada ? ColoresApp.acento : Colors.transparent, width: 2.5),
          image: DecorationImage(image: AssetImage(assetPath), fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _miniaturaColorSolido(String colorId, StateSetter setModalState) {
    final color = ColoresApp.fondosSolidos[colorId]!;
    final seleccionada = ajustes.tipoFondo == 'solido' && ajustes.colorSolidoId == colorId;
    return GestureDetector(
      onTap: () {
        setState(() {
          ajustes.tipoFondo = 'solido';
          ajustes.colorSolidoId = colorId;
        });
        setModalState(() {});
        _guardarFondoPreferencias();
      },
      child: Container(
        width: 50,
        height: 50,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: seleccionada ? ColoresApp.acento : Colors.white24, width: 2.5),
          boxShadow: [if (seleccionada) BoxShadow(color: ColoresApp.acento.withValues(alpha: 0.5), blurRadius: 8)],
        ),
        child: Center(child: seleccionada ? const Icon(Icons.check, color: Colors.white, size: 22) : null),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: ColoresApp.acento,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({required IconData icon, required String title, required bool value, required ValueChanged<bool> onChanged}) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: ColoresApp.fondoPrincipal,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: ColoresApp.acento, size: 20),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
      activeThumbColor: ColoresApp.acento,
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildSliderTile({required IconData icon, required String title, required double value, required double min, required double max, required ValueChanged<double> onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ColoresApp.fondoPrincipal,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: ColoresApp.acento, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500))),
              Text('${(value * 100).toInt()}%', style: const TextStyle(color: ColoresApp.acento, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            activeColor: ColoresApp.acento,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorTile({required IconData icon, required String title, required String currentValue, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: ColoresApp.fondoPrincipal,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: ColoresApp.acento, size: 20),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: ColoresApp.fondoPrincipal,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ColoresApp.acento.withValues(alpha: 0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(currentValue, style: const TextStyle(color: ColoresApp.acento, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, color: ColoresApp.acento, size: 16),
          ],
        ),
      ),
      onTap: onTap,
    );
  }

  void _mostrarSelectorVelocidadVoz(StateSetter setModalState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ColoresApp.fondoTarjeta,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final velocidades = [0.5, 1.0, 1.25, 1.5, 2.0];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Velocidad de Lectura (TTS)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Divider(color: Colors.white24),
                ...velocidades.map((v) {
                  final bool activo = ajustes.velocidadVoz == v;
                  return ListTile(
                    title: Text('${v}x', style: TextStyle(color: activo ? ColoresApp.acento : Colors.white)),
                    trailing: activo ? const Icon(Icons.check_circle_rounded, color: ColoresApp.acento) : null,
                    onTap: () async {
                      setModalState(() => ajustes.velocidadVoz = v);
                      setState(() {});
                      await _guardarAjustes();
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _mostrarSelectorNarrador(StateSetter setModalState) {
    final ttsPreview = FlutterTts();
    showModalBottomSheet(
      context: context,
      backgroundColor: ColoresApp.fondoTarjeta,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Icon(Icons.record_voice_over_rounded, color: ColoresApp.acento, size: 24),
                        SizedBox(width: 10),
                        Text('Voces Instaladas en tu Dispositivo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Elige la voz instalada del sistema que leerá tus libros con pronunciación y pausas naturales.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white12),
                    Expanded(
                      child: FutureBuilder<dynamic>(
                        future: ttsPreview.getVoices,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(color: ColoresApp.acento),
                            );
                          }

                          if (!snapshot.hasData || snapshot.data == null) {
                            return const Center(
                              child: Text('No se detectaron voces en el dispositivo', style: TextStyle(color: Colors.white54)),
                            );
                          }

                          final vocesEsp = (snapshot.data as List).where((v) {
                            if (v is! Map) return false;
                            final loc = (v['locale'] ?? '').toString().toLowerCase();
                            final name = (v['name'] ?? '').toString().toLowerCase();
                            return loc.startsWith('es') || name.contains('es-') || name.contains('es_');
                          }).toList();

                          if (vocesEsp.isEmpty) {
                            return SingleChildScrollView(
                              child: Column(
                                children: [
                                  const Icon(Icons.record_voice_over_outlined, color: Colors.white38, size: 48),
                                  const SizedBox(height: 12),
                                  const Text('No se encontraron voces instaladas en español', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: ColoresApp.acento.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: ColoresApp.acento.withValues(alpha: 0.3)),
                                    ),
                                    child: const Text(
                                      '💡 Ve a Configuración de tu Android > Texto a Voz > "Servicios de Voz de Google" > Instalar datos de voz > Español (Alta Definición).',
                                      style: TextStyle(color: Colors.white70, fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            itemCount: vocesEsp.length,
                            itemBuilder: (context, index) {
                              final v = vocesEsp[index];
                              final String vName = v['name'].toString();
                              final String vLoc = v['locale'].toString();

                              final bool esMale = vName.toLowerCase().contains('sfd') ||
                                  vName.toLowerCase().contains('sfg') ||
                                  vName.toLowerCase().contains('eed') ||
                                  vName.toLowerCase().contains('male') ||
                                  vName.toLowerCase().contains('hombre') ||
                                  vName.toLowerCase().contains('-b-') ||
                                  vName.toLowerCase().contains('-d-');

                              final bool esHD = vName.toLowerCase().contains('network') ||
                                  vName.toLowerCase().contains('hd') ||
                                  vName.toLowerCase().contains('neural');

                              final bool activo = ajustes.narradorSeleccionado == vName;

                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: Material(
                                  color: activo ? ColoresApp.acento.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: activo ? const BorderSide(color: ColoresApp.acento, width: 1.5) : BorderSide.none,
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    leading: Container(
                                      width: 44, height: 44,
                                      decoration: BoxDecoration(
                                        gradient: activo
                                            ? const LinearGradient(colors: [ColoresApp.acento, ColoresApp.acentoOscuro])
                                            : LinearGradient(colors: [Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.05)]),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Text(
                                          esMale ? '👨' : '👩',
                                          style: const TextStyle(fontSize: 22),
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      vName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: activo ? ColoresApp.acento : Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    subtitle: Wrap(
                                      spacing: 6,
                                      runSpacing: 2,
                                      children: [
                                        Text('Idioma: $vLoc • ${esMale ? "Masculino" : "Femenino"}', style: TextStyle(color: activo ? ColoresApp.acento.withValues(alpha: 0.7) : Colors.white54, fontSize: 11)),
                                        if (esHD)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                                            child: const Text('HD Neural', style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                                          ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.play_circle_filled_rounded, color: activo ? ColoresApp.acento : Colors.white38, size: 28),
                                          onPressed: () async {
                                            try {
                                              await ttsPreview.stop();
                                              await NarradoresConfig.aplicarNarrador(ttsPreview, vName);
                                              final frasePrueba = TextProcessorTTS.prepararTextoParaTTS('Esta es una muestra de lectura fluida con la voz $vName del sistema. Respeta comas, puntos y pausas.');
                                              await ttsPreview.speak(frasePrueba);
                                            } catch (_) {}
                                          },
                                        ),
                                        if (activo) const Icon(Icons.check_circle_rounded, color: ColoresApp.acento, size: 22),
                                      ],
                                    ),
                                    onTap: () async {
                                      await ttsPreview.stop();
                                      setSheetState(() {});
                                      setModalState(() => ajustes.narradorSeleccionado = vName);
                                      setState(() {});
                                      await _guardarAjustes();
                                    },
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) => ttsPreview.stop());
  }

  Future<void> _probarSonidoEfecto(String nombreTono) async {
    try {
      final rutaAsset = TonosEfectos.lista[nombreTono] ?? 'sounds/effect_1.mp3';
      await _previewPlayerEfecto.stop();
      await _previewPlayerEfecto.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            audioFocus: AndroidAudioFocus.none,
            usageType: AndroidUsageType.media,
            contentType: AndroidContentType.music,
          ),
        ),
      );
      final double vol = (ajustes.volumenEfecto > 0) ? ajustes.volumenEfecto : 0.8;
      await _previewPlayerEfecto.setVolume(vol);
      await _previewPlayerEfecto.play(AssetSource(rutaAsset));
    } catch (e) {
      debugPrint('Error reproduciendo prueba de sonido de página: $e');
    }
  }

  void _mostrarSelectorEfectosPagina(StateSetter setModalState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ColoresApp.fondoTarjeta,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Elige tu efecto de página (Toca para escuchar)',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Selecciona un efecto y escucha la prueba de sonido al instante.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 10),
                const Divider(color: Colors.white24),
                Expanded(
                  child: ListView(
                    shrinkWrap: true,
                    children: TonosEfectos.lista.keys.map((nombreTono) {
                      final bool activo = ajustes.nombreSonidoActual == nombreTono;
                      return ListTile(
                        leading: IconButton(
                          icon: Icon(
                            activo ? Icons.volume_up_rounded : Icons.play_circle_fill_rounded,
                            color: activo ? ColoresApp.acento : Colors.white70,
                          ),
                          tooltip: 'Probar sonido',
                          onPressed: () => _probarSonidoEfecto(nombreTono),
                        ),
                        title: Text(
                          nombreTono,
                          style: TextStyle(
                            color: activo ? ColoresApp.acento : Colors.white,
                            fontWeight: activo ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          activo ? 'Efecto seleccionado' : 'Toca para probar y seleccionar',
                          style: TextStyle(color: activo ? ColoresApp.acento.withValues(alpha: 0.7) : Colors.grey, fontSize: 11),
                        ),
                        trailing: activo ? const Icon(Icons.check_circle_rounded, color: ColoresApp.acento) : null,
                        onTap: () async {
                          setModalState(() {
                            ajustes.nombreSonidoActual = nombreTono;
                          });
                          setState(() {});
                          await _guardarAjustes();
                          await _probarSonidoEfecto(nombreTono);
                          if (!context.mounted) return;
                          Navigator.pop(context);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _mostrarConfiguracionGeneral() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ColoresApp.fondoTarjeta,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                height: MediaQuery.of(context).size.height * 0.8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Configuración General',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24),
                    Expanded(
                      child: ListView(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: ColoresApp.fondoPrincipal,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.workspace_premium_rounded, color: ColoresApp.acento, size: 20),
                            ),
                            title: const Text('Versión Pro (12 días gratis)', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            subtitle: const Text('Desbloquea todo por 20.000 COP al año', style: TextStyle(color: Colors.grey, fontSize: 11)),
                            trailing: OutlinedButton(
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: ColoresApp.acento)),
                              child: const Text('Suscribirse', style: TextStyle(fontSize: 11, color: ColoresApp.acento)),
                              onPressed: () {
                                Navigator.pop(context);
                                _comprarSuscripcion();
                              },
                            ),
                          ),
                          _buildSectionHeader('Apariencia y Visualización'),
                          _buildSelectorTile(
                            icon: Icons.language_rounded,
                            title: 'Idioma / Language',
                            currentValue: TextosIdioma.instancia.idiomaActual,
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: ColoresApp.fondoTarjeta,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                ),
                                builder: (BuildContext context) {
                                  return SafeArea(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            'Selecciona un idioma / Select Language',
                                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 10),
                                          const Divider(color: Colors.white24),
                                          ...TextosIdioma.idiomasDisponibles.map((idioma) {
                                            final bool esActivo = TextosIdioma.instancia.idiomaActual == idioma;
                                            return ListTile(
                                              title: Text(
                                                idioma,
                                                style: TextStyle(
                                                  color: esActivo ? ColoresApp.acento : Colors.white,
                                                  fontWeight: esActivo ? FontWeight.bold : FontWeight.normal,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              trailing: esActivo ? const Icon(Icons.check_circle_rounded, color: ColoresApp.acento) : null,
                                              onTap: () async {
                                                TextosIdioma.instancia.establecerIdioma(idioma);
                                                ajustes.idioma = idioma;
                                                await _guardarAjustes();
                                                _aplicarFiltroSeccion();
                                                if (!context.mounted) return;
                                                Navigator.pop(context);
                                                setState(() {});
                                              },
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          _buildSwitchTile(
                            icon: ajustes.modoOscuro ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                            title: 'Modo Oscuro',
                            value: ajustes.modoOscuro,
                            onChanged: (val) {
                              setModalState(() => ajustes.modoOscuro = val);
                              setState(() {});
                              _guardarAjustes();
                            },
                          ),
                          _buildSwitchTile(
                            icon: Icons.menu_book_rounded,
                            title: 'Modo Sepia (Papel Antiguo)',
                            value: ajustes.modoSepia,
                            onChanged: (val) {
                              setModalState(() => ajustes.modoSepia = val);
                              setState(() {});
                              _guardarAjustes();
                            },
                          ),
                          _buildSwitchTile(
                            icon: Icons.shield_rounded,
                            title: 'Filtro de Luz Azul (Antifatiga)',
                            value: ajustes.filtroLuzAzul,
                            onChanged: (val) {
                              setModalState(() => ajustes.filtroLuzAzul = val);
                              setState(() {});
                              _guardarAjustes();
                            },
                          ),
                          _buildSliderTile(
                            icon: Icons.brightness_6_rounded,
                            title: 'Brillo de Pantalla',
                            value: ajustes.nivelBrillo,
                            min: 0.1,
                            max: 1.0,
                            onChanged: (v) {
                              setModalState(() => ajustes.nivelBrillo = v);
                              setState(() {});
                              _guardarAjustes();
                            },
                          ),
                          if (ajustes.filtroLuzAzul)
                            _buildSliderTile(
                              icon: Icons.color_lens_rounded,
                              title: 'Intensidad del Filtro',
                              value: ajustes.intensidadFiltro,
                              min: 0.0,
                              max: 1.0,
                              onChanged: (v) {
                                setModalState(() => ajustes.intensidadFiltro = v);
                                setState(() {});
                                _guardarAjustes();
                              },
                            ),
                          _buildSectionHeader('Audio, Voz y Lectura'),
                          _buildSelectorTile(
                            icon: Icons.speed_rounded,
                            title: 'Velocidad de Voz (TTS)',
                            currentValue: '${ajustes.velocidadVoz}x',
                            onTap: () => _mostrarSelectorVelocidadVoz(setModalState),
                          ),
                          _buildSelectorTile(
                            icon: Icons.record_voice_over_rounded,
                            title: 'Narrador de Voz',
                            currentValue: ajustes.narradorSeleccionado,
                            onTap: () => _mostrarSelectorNarrador(setModalState),
                          ),
                          _buildSwitchTile(
                            icon: Icons.volume_up_rounded,
                            title: 'Sonido al Pasar Página',
                            value: ajustes.sonidoActivado,
                            onChanged: (val) {
                              setModalState(() => ajustes.sonidoActivado = val);
                              setState(() {});
                              _guardarAjustes();
                            },
                          ),
                          if (ajustes.sonidoActivado) ...[
                            _buildSliderTile(
                              icon: Icons.volume_mute_rounded,
                              title: 'Volumen del Efecto',
                              value: ajustes.volumenEfecto,
                              min: 0.0,
                              max: 1.0,
                              onChanged: (v) {
                                setModalState(() => ajustes.volumenEfecto = v);
                                setState(() {});
                                _guardarAjustes();
                              },
                            ),
                            _buildSelectorTile(
                              icon: Icons.audio_file_rounded,
                              title: 'Efecto de Paso de Página',
                              currentValue: ajustes.nombreSonidoActual,
                              onTap: () => _mostrarSelectorEfectosPagina(setModalState),
                            ),
                          ],
                          _buildSectionHeader('Sistema'),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: ColoresApp.fondoPrincipal,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.cleaning_services_rounded, color: ColoresApp.acento, size: 20),
                            ),
                            title: const Text('Limpiar Caché y Temporales', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                            subtitle: const Text('Libera espacio de portadas generadas', style: TextStyle(color: Colors.grey, fontSize: 11)),
                            onTap: () async {
                              try {
                                final cacheDir = await getTemporaryDirectory();
                                if (cacheDir.existsSync()) {
                                  cacheDir.deleteSync(recursive: true);
                                  cacheDir.createSync();
                                }
                                final appCacheDir = await getApplicationCacheDirectory();
                                if (appCacheDir.existsSync()) {
                                  appCacheDir.deleteSync(recursive: true);
                                  appCacheDir.createSync();
                                }
                                setState(() {
                                  for (final libro in libros) {
                                    libro.rutaPortadaCache = null;
                                  }
                                });
                                await _guardarBiblioteca();
                                if (context.mounted) {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: ColoresApp.fondoTarjeta,
                                      title: const Row(
                                        children: [
                                          Icon(Icons.cleaning_services_rounded, color: ColoresApp.acento),
                                          SizedBox(width: 8),
                                          Text('Caché Limpiado', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      content: const Text(
                                        '🧹 ¡Caché y archivos temporales limpiados con éxito!\n\nSe ha liberado espacio de memoria en el dispositivo y se han restablecido los temporales.',
                                        style: TextStyle(color: Colors.white70, fontSize: 13),
                                      ),
                                      actions: [
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: ColoresApp.acentoOscuro),
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Entendido', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              } catch (e) {
                                debugPrint('Error limpiando caché: $e');
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _mostrarMenuOrden() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ColoresApp.fondoTarjeta,
      builder: (context) {
        Widget opcion(String nombre, IconData icon) {
          final activa = ajustes.ordenBiblioteca == nombre;
          return ListTile(
            leading: Icon(icon, color: activa ? ColoresApp.acento : Colors.grey),
            title: Text(nombre, style: TextStyle(color: activa ? ColoresApp.acento : Colors.white, fontWeight: activa ? FontWeight.bold : FontWeight.normal)),
            trailing: activa ? const Icon(Icons.check, color: ColoresApp.acento) : null,
            onTap: () {
              setState(() => ajustes.ordenBiblioteca = nombre);
              _aplicarFiltroSeccion();
              _guardarAjustes();
              Navigator.pop(context);
            },
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Ordenar biblioteca por', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              opcion('Recientes', Icons.new_releases_outlined),
              opcion('A-Z', Icons.sort_by_alpha),
              opcion('Categoría', Icons.folder_outlined),
            ],
          ),
        );
      },
    );
  }

  Color _colorDeFondoSolido() {
    if (ajustes.colorSolidoId != null && ColoresApp.fondosSolidos.containsKey(ajustes.colorSolidoId)) {
      return ColoresApp.fondosSolidos[ajustes.colorSolidoId]!;
    }
    return ajustes.modoOscuro ? const Color(0xFF0E2229) : const Color(0xFFF5F5F5);
  }

  Widget _itemDrawer(IconData icon, String claveSeccion) {
    final bool activo = seccionActual == claveSeccion;
    return ListTile(
      selected: activo,
      selectedTileColor: ColoresApp.acento.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: activo ? ColoresApp.acentoOscuro : ColoresApp.fondoTarjeta,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: activo ? ColoresApp.acento : Colors.white.withValues(alpha: 0.08),
            width: 1.2,
          ),
          boxShadow: [
            if (activo)
              BoxShadow(
                color: ColoresApp.acento.withValues(alpha: 0.35),
                blurRadius: 10,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Icon(icon, color: activo ? Colors.white : ColoresApp.acento, size: 18),
      ),
      title: Text(
        TextosIdioma.instancia.get(claveSeccion),
        style: TextStyle(
          color: activo ? ColoresApp.acento : Colors.white70,
          fontSize: 13,
          fontWeight: activo ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      trailing: activo
          ? Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: ColoresApp.acento,
                boxShadow: [BoxShadow(color: ColoresApp.acento, blurRadius: 6)],
              ),
            )
          : null,
      onTap: () {
        Navigator.pop(context);
        setState(() {
          seccionActual = claveSeccion;
          buscando = false;
          _searchController.clear();
        });
        _aplicarFiltroSeccion();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: TextosIdioma.instancia,
      builder: (context, child) {
        if (_cargandoLicencia) {
          return const Scaffold(
            backgroundColor: ColoresApp.fondoPrincipal,
            body: Center(child: CircularProgressIndicator(color: ColoresApp.acento)),
          );
        }

        if (!_tieneAcceso) {
          return Scaffold(
            backgroundColor: ColoresApp.fondoPrincipal,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.workspace_premium_rounded, size: 80, color: ColoresApp.acento),
                    const SizedBox(height: 20),
                    const Text(
                      'Tu período de prueba de 12 días ha finalizado',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Suscríbete a la versión Pro por 20.000 COP al año para seguir disfrutando de Mi Lector Pro sin límites.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColoresApp.acentoOscuro,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _comprarSuscripcion,
                      child: const Text('Suscribirse por 20.000 COP / año', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (_cargandoInicial) {
          return const Scaffold(
            backgroundColor: ColoresApp.fondoPrincipal,
            body: Center(child: CircularProgressIndicator(color: ColoresApp.acento)),
          );
        }

        final librosEnProgreso =
            libros.where((l) => l.ultimaPagina > 1 && !l.leido && !l.esAudiolibro && !l.esVideo).toList();

        final double anchoPantalla = MediaQuery.of(context).size.width;
        final bool esTablet = anchoPantalla > 600;
        final int columnasDinamicas = esTablet ? (columnasGrid == 2 ? 3 : 5) : columnasGrid;
        final double aspectDinamico = columnasDinamicas == 2
            ? 0.65
            : (columnasDinamicas == 3 ? 0.58 : 0.68);

        return Opacity(
          opacity: ajustes.nivelBrillo.clamp(0.1, 1.0),
          child: Stack(
            children: [
              Positioned.fill(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: (ajustes.tipoFondo == 'galeria' && File(ajustes.rutaFondoSeleccionado).existsSync())
                          ? Image.file(File(ajustes.rutaFondoSeleccionado), fit: BoxFit.fill)
                          : Image.asset(ajustes.rutaFondoSeleccionado, fit: BoxFit.fill),
                    ),
                    if (ajustes.tipoFondo == 'solido' || ajustes.colorSolidoId != null)
                      Positioned.fill(
                        child: Container(
                          color: _colorDeFondoSolido().withValues(
                            alpha: ajustes.tipoFondo == 'solido' ? 0.85 : 0.45,
                          ),
                        ),
                      ),
                    Positioned.fill(
                      child: Container(
                        color: ajustes.modoOscuro ? Colors.black.withValues(alpha: 0.60) : Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                child: Scaffold(
                  backgroundColor: Colors.transparent,
                  appBar: AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leadingWidth: 142,
                    leading: Builder(
                      builder: (context) => InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => Scaffold.of(context).openDrawer(),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ColoresApp.acento.withValues(alpha: 0.35), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: Image.asset('assets/icono.png', width: 22, height: 22, fit: BoxFit.cover),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.menu_rounded, color: ColoresApp.acento, size: 16),
                              const SizedBox(width: 4),
                              const Flexible(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Mi Lector',
                                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Menú Principal',
                                      style: TextStyle(color: ColoresApp.acento, fontSize: 8, fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    title: buscando
                        ? TextField(
                            controller: _searchController,
                            autofocus: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: TextosIdioma.instancia.get('buscarHint'),
                              border: InputBorder.none,
                              hintStyle: const TextStyle(color: Colors.grey),
                            ),
                          )
                        : Text(
                            TextosIdioma.instancia.get(seccionActual),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    actions: [
                      if (buscando && _searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.language, color: ColoresApp.acento),
                          tooltip: 'Buscar en Web',
                          onPressed: () => _buscarEnWeb(_searchController.text),
                        ),
                      IconButton(
                        icon: Icon(buscando ? Icons.close : Icons.search),
                        onPressed: () {
                          setState(() {
                            buscando = !buscando;
                            if (!buscando) _searchController.clear();
                          });
                          _aplicarFiltroSeccion();
                        },
                      ),
                    ],
                  ),
                  drawer: Drawer(
                    backgroundColor: ColoresApp.fondoDrawer,
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        DrawerHeader(
                          decoration: BoxDecoration(
                            color: ColoresApp.fondoPrincipal.withValues(alpha: 0.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [BoxShadow(color: ColoresApp.acento.withValues(alpha: 0.3), blurRadius: 10)],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.asset('assets/icono.png', width: 48, height: 48, fit: BoxFit.cover),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  const Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Mi Lector Pro', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                      SizedBox(height: 3),
                                      Text('Centro Multimedia & Libros', style: TextStyle(color: ColoresApp.acento, fontSize: 11, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ExpansionTile(
                          initiallyExpanded: true,
                          leading: const Icon(Icons.auto_stories_rounded, color: ColoresApp.acento),
                          title: Text(TextosIdioma.instancia.get('miBibliotecaTitle'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          iconColor: ColoresApp.acento,
                          collapsedIconColor: Colors.grey,
                          childrenPadding: const EdgeInsets.only(left: 12),
                          children: [
                            _itemDrawer(Icons.book_rounded, 'biblioteca'),
                            _itemDrawer(Icons.play_circle_rounded, 'leyendo'),
                            _itemDrawer(Icons.star_rounded, 'favoritos'),
                            _itemDrawer(Icons.schedule_rounded, 'porLeer'),
                            _itemDrawer(Icons.done_all_rounded, 'leidos'),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          child: Divider(color: Colors.white10, thickness: 1),
                        ),
                        ExpansionTile(
                          leading: const Icon(Icons.perm_media_rounded, color: ColoresApp.acento),
                          title: Text(TextosIdioma.instancia.get('multimediaTitle'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          iconColor: ColoresApp.acento,
                          collapsedIconColor: Colors.grey,
                          childrenPadding: const EdgeInsets.only(left: 12),
                          children: [
                            _itemDrawer(Icons.headphones_rounded, 'audiolibros'),
                            _itemDrawer(Icons.video_library_rounded, 'videos'),
                            _itemDrawer(Icons.description_rounded, 'documentos'),
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: ColoresApp.fondoTarjeta, borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.library_music_rounded, color: ColoresApp.acento, size: 18),
                              ),
                              title: Text(TextosIdioma.instancia.get('musica'), style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PantallaMusicaGratis(
                                      pistas: pistasMusica,
                                      onAgregarPista: _agregarPistaMusica,
                                      onEliminarPista: _eliminarPistaMusica,
                                    ),
                                  ),
                                ).then((_) => setState(() {}));
                              },
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          child: Divider(color: Colors.white10, thickness: 1),
                        ),
                        ExpansionTile(
                          leading: const Icon(Icons.dashboard_rounded, color: ColoresApp.acento),
                          title: Text(TextosIdioma.instancia.get('herramientasTitle'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          iconColor: ColoresApp.acento,
                          collapsedIconColor: Colors.grey,
                          childrenPadding: const EdgeInsets.only(left: 12),
                          children: [
                            _itemDrawer(Icons.bar_chart_rounded, 'estadisticas'),
                            _itemDrawer(Icons.cloud_download_rounded, 'descargar'),
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: ColoresApp.fondoTarjeta, borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.palette_rounded, color: ColoresApp.acento, size: 18),
                              ),
                              title: const Text('Personalizar Apariencia', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                              onTap: () {
                                Navigator.pop(context);
                                _mostrarModalPersonalizarApariencia();
                              },
                            ),
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: ColoresApp.fondoTarjeta, borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.settings_rounded, color: ColoresApp.acento, size: 18),
                              ),
                              title: Text(TextosIdioma.instancia.get('config'), style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                              onTap: () {
                                Navigator.pop(context);
                                _mostrarConfiguracionGeneral();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                  body: Column(
                    children: [
                      if (seccionActual == 'biblioteca' && categoriaSeleccionada == 'Todas' && librosEnProgreso.isNotEmpty)
                        SizedBox(
                          height: 110,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Text('Continuar Leyendo ▶', style: TextStyle(color: ColoresApp.acento, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(height: 6),
                                Expanded(
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    itemCount: librosEnProgreso.length,
                                    itemBuilder: (context, index) {
                                      final libro = librosEnProgreso[index];
                                      return SizedBox(
                                        width: 140,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                          child: InkWell(
                                            onTap: () => _abrirLibro(libro),
                                            child: Card(
                                              color: ColoresApp.fondoTarjeta,
                                              margin: EdgeInsets.zero,
                                              child: Padding(
                                                padding: const EdgeInsets.all(6.0),
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(libro.titulo, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                    const SizedBox(height: 4),
                                                    Text(libro.esEpub ? 'EPUB' : (libro.esDocx ? 'Word' : 'Pág. ${libro.ultimaPagina}'), style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (seccionActual != 'descargar' && seccionActual != 'audiolibros' && seccionActual != 'videos' && seccionActual != 'documentos' && seccionActual != 'estadisticas')
                        SizedBox(
                          height: 50,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: misCategorias.length,
                                    itemBuilder: (context, index) {
                                      final cat = misCategorias[index];
                                      final activa = categoriaSeleccionada == cat;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: GestureDetector(
                                          onLongPress: () => _gestionarCategoria(cat),
                                          child: ChoiceChip(
                                            label: Text(cat),
                                            selected: activa,
                                            selectedColor: ColoresApp.acentoOscuro,
                                            backgroundColor: ColoresApp.fondoTarjeta.withValues(alpha: 0.8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                            side: BorderSide.none,
                                            labelStyle: TextStyle(
                                              color: activa ? Colors.white : Colors.grey,
                                              fontSize: 12,
                                              fontWeight: activa ? FontWeight.bold : FontWeight.normal,
                                            ),
                                            onSelected: (bool selected) {
                                              setState(() => categoriaSeleccionada = cat);
                                              _aplicarFiltroSeccion();
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: ColoresApp.acento, size: 20),
                                  tooltip: 'Nueva categoría',
                                  onPressed: _crearNuevaCategoria,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.sort_rounded, color: ColoresApp.acento, size: 20),
                                  tooltip: 'Ordenar biblioteca',
                                  onPressed: _mostrarMenuOrden,
                                ),
                                IconButton(
                                  icon: Icon(
                                    columnasGrid == 3 ? Icons.grid_view_rounded : Icons.view_module_rounded,
                                    color: ColoresApp.acento,
                                    size: 20,
                                  ),
                                  tooltip: columnasGrid == 3 ? 'Vista de 2 columnas (Grande)' : 'Vista de 3 columnas (Compacta)',
                                  onPressed: () {
                                    setState(() {
                                      columnasGrid = (columnasGrid == 3) ? 2 : 3;
                                    });
                                  },
                                ),
                                MiniReproductorMusicaFondo(pistas: pistasMusica),
                              ],
                            ),
                          ),
                        ),
                      if (seccionActual == 'audiolibros' || seccionActual == 'videos' || seccionActual == 'documentos')
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${librosMostrados.length} ${librosMostrados.length == 1 ? "archivo" : "archivos"}',
                                style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      columnasGrid == 3 ? Icons.grid_view_rounded : Icons.view_module_rounded,
                                      color: ColoresApp.acento,
                                      size: 20,
                                    ),
                                    tooltip: columnasGrid == 3 ? 'Vista de 2 columnas' : 'Vista de 3 columnas',
                                    onPressed: () {
                                      setState(() {
                                        columnasGrid = (columnasGrid == 3) ? 2 : 3;
                                      });
                                    },
                                  ),
                                  MiniReproductorMusicaFondo(pistas: pistasMusica),
                                ],
                              ),
                            ],
                          ),
                        ),
                      AnimatedBuilder(
                        animation: AudioGlobal(),
                        builder: (context, _) {
                          final audio = AudioGlobal();
                          if (audio.tituloActual == null) return const SizedBox.shrink();
                          return Container(
                            width: double.infinity,
                            color: ColoresApp.fondoTarjeta,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  audio.sonando ? Icons.graphic_eq : Icons.music_note,
                                  color: ColoresApp.acento,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    audio.sonando ? '🎶 Sonando: ${audio.tituloActual}' : '⏸️ En pausa: ${audio.tituloActual}',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    audio.sonando ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                                    color: audio.sonando ? Colors.amber : ColoresApp.acento,
                                    size: 26,
                                  ),
                                  tooltip: audio.sonando ? 'Pausar música' : 'Reproducir música',
                                  onPressed: () => audio.pausarOReanudar(),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.stop_rounded, color: Colors.redAccent, size: 24),
                                  tooltip: 'Detener música',
                                  onPressed: () => audio.detener(),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      Expanded(
                        child: seccionActual == 'descargar'
                            ? const PantallaBibliotecasDirectas()
                            : seccionActual == 'estadisticas'
                                ? PantallaEstadisticas(libros: libros, pistasMusica: pistasMusica)
                                : librosMostrados.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              seccionActual == 'audiolibros'
                                                  ? Icons.headphones
                                                  : seccionActual == 'videos'
                                                      ? Icons.video_library_outlined
                                                      : Icons.library_books_outlined,
                                              size: 80,
                                              color: Colors.white24,
                                            ),
                                            const SizedBox(height: 16),
                                            Text('No hay contenidos en "${TextosIdioma.instancia.get(seccionActual)}"',
                                                style: const TextStyle(color: Colors.grey, fontSize: 14)),
                                          ],
                                        ),
                                      )
                                    : GridView.builder(
                                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
                                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: columnasDinamicas,
                                          childAspectRatio: aspectDinamico,
                                          crossAxisSpacing: 12,
                                          mainAxisSpacing: 14,
                                        ),
                                        itemCount: librosMostrados.length,
                                        itemBuilder: (context, index) {
                                          final libro = librosMostrados[index];
                                          return _tarjetaLibro(libro);
                                        },
                                      ),
                      ),
                    ],
                  ),
                  floatingActionButton: (seccionActual == 'descargar' || seccionActual == 'estadisticas')
                      ? null
                      : FloatingActionButton.extended(
                          backgroundColor: ColoresApp.acentoOscuro,
                          onPressed: _agregarLibroOAudiolibro,
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: Text(TextosIdioma.instancia.get('agregar'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                ),
              ),
              if (ajustes.filtroLuzAzul)
                IgnorePointer(
                  child: Container(color: Colors.amber.withValues(alpha: ajustes.intensidadFiltro)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDefaultCardCover(Libro libro) {
    late final IconData iconData;
    late final Color primaryColor;
    late final Color secondaryColor;
    late final String badgeLabel;

    if (libro.esAudiolibro) {
      iconData = Icons.headphones_rounded;
      primaryColor = const Color(0xFFA855F7);
      secondaryColor = const Color(0xFF3B0764);
      badgeLabel = 'AUDIO';
    } else if (libro.esVideo) {
      iconData = Icons.play_circle_fill_rounded;
      primaryColor = const Color(0xFFEC4899);
      secondaryColor = const Color(0xFF831843);
      badgeLabel = 'VIDEO';
    } else if (libro.esDocx) {
      iconData = Icons.description_rounded;
      primaryColor = const Color(0xFF38BDF8);
      secondaryColor = const Color(0xFF1E3A8A);
      badgeLabel = 'WORD';
    } else if (libro.esEpub) {
      iconData = Icons.auto_stories_rounded;
      primaryColor = const Color(0xFF34D399);
      secondaryColor = const Color(0xFF064E3B);
      badgeLabel = 'EPUB';
    } else {
      iconData = Icons.picture_as_pdf_rounded;
      primaryColor = const Color(0xFFF87171);
      secondaryColor = const Color(0xFF7F1D1D);
      badgeLabel = 'PDF';
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [secondaryColor, const Color(0xFF0E2229)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.35),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(color: primaryColor.withValues(alpha: 0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(iconData, size: 36, color: primaryColor),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: primaryColor.withValues(alpha: 0.4), width: 1),
              ),
              child: Text(
                badgeLabel,
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaLibro(Libro libro) {
    final bool tienePortadaCustom = libro.rutaPortadaCache != null && File(libro.rutaPortadaCache!).existsSync();
    final bool esPdf = !libro.esAudiolibro && !libro.esVideo && !libro.esDocx && !libro.esEpub;

    return GestureDetector(
      onLongPress: () => _mostrarOpcionesLibroRapido(libro),
      child: Container(
        key: ValueKey(libro.id),
        decoration: BoxDecoration(
          color: ColoresApp.fondoTarjeta.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: InkWell(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                onTap: () => _abrirLibro(libro),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                        child: tienePortadaCustom
                            ? Image.file(
                                File(libro.rutaPortadaCache!),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (context, error, stackTrace) => _buildDefaultCardCover(libro),
                              )
                            : (esPdf
                                ? PortadaPdfWidget(
                                    rutaPdf: libro.rutaLocal,
                                    titulo: libro.titulo,
                                    rutaPortadaCache: libro.rutaPortadaCache,
                                    onPortadaGenerada: (rutaCache) {
                                      libro.rutaPortadaCache = rutaCache;
                                      _guardarBiblioteca();
                                    },
                                  )
                                : _buildDefaultCardCover(libro)),
                      ),
                    ),
                    if (libro.ultimaPagina > 1 && !libro.leido && !libro.esAudiolibro && !libro.esVideo)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.5),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_stories_rounded, color: Colors.white, size: 10),
                              SizedBox(width: 3),
                              Text(
                                'LEYENDO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          libro.titulo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (libro.esFavorito)
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.amber.withValues(alpha: 0.2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withValues(alpha: 0.4),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                (libro.ultimaPagina > 1 && !libro.leido)
                                    ? const Color(0xFF10B981).withValues(alpha: 0.25)
                                    : ColoresApp.acento.withValues(alpha: 0.22),
                                ColoresApp.acentoOscuro.withValues(alpha: 0.12),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (libro.ultimaPagina > 1 && !libro.leido)
                                  ? const Color(0xFF10B981).withValues(alpha: 0.5)
                                  : ColoresApp.acento.withValues(alpha: 0.4),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(color: ColoresApp.acento.withValues(alpha: 0.12), blurRadius: 4),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                libro.esAudiolibro
                                    ? Icons.headphones_rounded
                                    : libro.esVideo
                                        ? Icons.play_arrow_rounded
                                        : libro.esDocx
                                            ? Icons.description_rounded
                                            : libro.esEpub
                                                ? Icons.auto_stories_rounded
                                                : Icons.picture_as_pdf_rounded,
                                size: 10,
                                color: (libro.ultimaPagina > 1 && !libro.leido) ? const Color(0xFF34D399) : ColoresApp.acento,
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  libro.esAudiolibro
                                      ? 'Audio'
                                      : libro.esVideo
                                          ? 'Video'
                                          : libro.esDocx
                                              ? 'Word'
                                              : libro.esEpub
                                                  ? 'EPUB'
                                                  : (libro.leido
                                                      ? 'Leído'
                                                      : (libro.ultimaPagina > 1
                                                          ? 'Leyendo pág. ${libro.ultimaPagina}'
                                                          : 'Pág. ${libro.ultimaPagina}')),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: (libro.ultimaPagina > 1 && !libro.leido) ? const Color(0xFF34D399) : ColoresApp.acento,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      InkWell(
                        onTap: () => _mostrarOpcionesLibroRapido(libro),
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(Icons.more_vert, color: Colors.white54, size: 16),
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
    );
  }
}
