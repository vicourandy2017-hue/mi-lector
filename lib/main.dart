import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:epub_parser/epub_parser.dart' as epubx;
import 'package:flutter_html/flutter_html.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

void main() {
  runApp(const MiLectorApp());
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

// ---------------------------------------------------------
// COLORES COMPARTIDOS
// ---------------------------------------------------------
class ColoresApp {
  static const Color fondoPrincipal = Color(0xFF0E2229);
  static const Color fondoTarjeta = Color(0xFF16333D);
  static const Color fondoDrawer = Color(0xFF0C1D23);
  static const Color acento = Color(0xFF38BDF8);
  static const Color acentoOscuro = Color(0xFF0284C7);
}

// ---------------------------------------------------------
// SOPORTE MULTI-IDIOMA REAL
// ---------------------------------------------------------
class TextosIdioma {
  static Map<String, Map<String, String>> diccionarios = {
    'Español': {
      'biblioteca': 'Libros',
      'audiolibros': 'Audiolibros 🎧',
      'videos': 'Videos 🎬',
      'estadisticas': 'Estadísticas 📊',
      'config': 'Configuración',
      'descargar': 'Biblioteca Publica',
      'musica': 'Música de fondo para leer 🎼',
      'leyendo': 'Leyendo ahora',
      'favoritos': 'Favoritos',
      'porLeer': 'Por leer',
      'leidos': 'Leídos',
      'agregar': 'Agregar contenido',
      'buscarHint': 'Buscar libro local o presiona web...',
    },
    'English': {
      'biblioteca': 'Books',
      'audiolibros': 'Audiobooks 🎧',
      'videos': 'Videos 🎬',
      'estadisticas': 'Statistics 📊',
      'config': 'Settings',
      'descargar': 'public library',
      'musica': 'Music for Reading 🎼',
      'leyendo': 'Reading Now',
      'favoritos': 'Favorites',
      'porLeer': 'To Read',
      'leidos': 'Read',
      'agregar': 'Add Content',
      'buscarHint': 'Search local book or tap web...',
    },
  };

  static String idiomaActual = 'Español';
  static String get(String clave) {
    return diccionarios[idiomaActual]?[clave] ?? clave;
  }
}

// ---------------------------------------------------------
// PANTALLA DE BIENVENIDA ESTILO PLAYSTATION
// ---------------------------------------------------------
class PantallaBienvenidaAnimada extends StatefulWidget {
  const PantallaBienvenidaAnimada({super.key});

  @override
  State<PantallaBienvenidaAnimada> createState() => _PantallaBienvenidaAnimadaState();
}

class _PantallaBienvenidaAnimadaState extends State<PantallaBienvenidaAnimada> with TickerProviderStateMixin {
  String textoCompleto = "Mi Lector Pro";
  String textoMostrado = "";
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
      if (index < textoCompleto.length) {
        setState(() {
          textoMostrado += textoCompleto[index];
        });
        index++;
      } else {
        _timerEscritura?.cancel();

        Future.delayed(const Duration(milliseconds: 1600), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const PantallaPrincipalMiLector(),
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
                // 🌟 LOGOTIPO PERSONALIZADO EN PANTALLA DE BIENVENIDA
 Container(
  width: 120,
  height: 120,
  decoration: BoxDecoration(
    color: const Color(0xFF16333D),
    borderRadius: BorderRadius.circular(28),
    border: Border.all(color: ColoresApp.acento.withOpacity(0.4), width: 1.5),
    boxShadow: [
      BoxShadow(
        color: ColoresApp.acento.withOpacity(0.25),
        blurRadius: 30,
        spreadRadius: 2,
      ),
    ],
  ),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(26),
    child: Padding(
      padding: const EdgeInsets.all(8.0),
      child: Image.asset(
        'assets/icono.png',
        fit: BoxFit.contain,
      ),
    ),
  ),
),
               const SizedBox(height: 35),

                // 🌟 Texto con efecto de escritura progresiva
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      textoMostrado,
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

// Cursor parpadeante estilo consola
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
    _cursorController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
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

// ---------------------------------------------------------
// REPRODUCTOR GLOBAL DE MÚSICA
// ---------------------------------------------------------
class AudioGlobal {
  static final AudioGlobal _instance = AudioGlobal._internal();
  factory AudioGlobal() => _instance;
  AudioGlobal._internal();

  final AudioPlayer player = AudioPlayer();
  bool sonando = false;
  String? tituloActual;
  double volumen = 0.5;
  List<VoidCallback> listeners = [];
  bool _inicializado = false;

  void init() {
    if (_inicializado) return;
    _inicializado = true;

    player.setReleaseMode(ReleaseMode.loop);
    player.onPlayerStateChanged.listen((state) {
      sonando = state == PlayerState.playing;
      notificarListeners();
    });
  }

  void registrarListener(VoidCallback callback) => listeners.add(callback);
  void removerListener(VoidCallback callback) => listeners.remove(callback);
  void notificarListeners() {
    for (var cb in listeners) {
      cb();
    }
  }

  Future<void> reproducirLocal(String ruta, String titulo) async {
    try {
      tituloActual = titulo;
      await player.stop();
      await player.setVolume(volumen);
      await player.play(DeviceFileSource(ruta));
      sonando = true;
      notificarListeners();
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
      notificarListeners();
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
    notificarListeners();
  }

  Future<void> detener() async {
    await player.stop();
    sonando = false;
    tituloActual = null;
    notificarListeners();
  }

  Future<void> cambiarVolumen(double v) async {
    volumen = v;
    await player.setVolume(v);
    notificarListeners();
  }
}

// ---------------------------------------------------------
// MODELOS
// ---------------------------------------------------------
class Marcador {
  final int pagina;
  final String etiqueta;

  Marcador({required this.pagina, required this.etiqueta});

  Map<String, dynamic> toMap() => {'pagina': pagina, 'etiqueta': etiqueta};
  factory Marcador.fromMap(Map<String, dynamic> map) => Marcador(
        pagina: map['pagina'] ?? 1,
        etiqueta: map['etiqueta'] ?? 'Marcador',
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
  String notasPersonales;
  List<Marcador> marcadores;
  int posicionMs;

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
    this.notasPersonales = '',
    List<Marcador>? marcadores,
    this.posicionMs = 0,
  }) : marcadores = marcadores ?? [];

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
        'notasPersonales': notasPersonales,
        'marcadores': marcadores.map((m) => m.toMap()).toList(),
        'posicionMs': posicionMs,
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
        notasPersonales: map['notasPersonales'] ?? '',
        marcadores: (map['marcadores'] as List<dynamic>?)
                ?.map((m) => Marcador.fromMap(m))
                .toList() ??
            [],
        posicionMs: map['posicionMs'] ?? 0,
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

Future<bool> solicitarPermisosAlmacenamiento() async {
  try {
    await Permission.storage.request();
    await Permission.audio.request();
    await Permission.videos.request();
    return true;
  } catch (e) {
    debugPrint('Error solicitando permisos de almacenamiento: $e');
    return true;
  }
}

// ---------------------------------------------------------
// PANTALLA PRINCIPAL DE BIBLIOTECA
// ---------------------------------------------------------
class PantallaPrincipalMiLector extends StatefulWidget {
  const PantallaPrincipalMiLector({super.key});

  @override
  State<PantallaPrincipalMiLector> createState() => _PantallaPrincipalMiLectorState();
}

class _PantallaPrincipalMiLectorState extends State<PantallaPrincipalMiLector> with WidgetsBindingObserver {
  List<Libro> libros = [];
  List<Libro> librosMostrados = [];
  List<PistaMusica> pistasMusica = [];
  List<String> misCategorias = ['Todas', 'General'];
  String categoriaSeleccionada = 'Todas';
  String seccionActual = 'biblioteca';
  String ordenBiblioteca = 'Recientes';
  final TextEditingController _searchController = TextEditingController();
  bool buscando = false;

  bool modoOscuroGlobal = true;
  double nivelBrilloGlobal = 1.0;
  bool filtroLuzAzulGlobal = false;
  bool modoSepiaGlobal = false;
  double volumenEfectoGlobal = 0.8;
  double intensidadFiltroGlobal = 0.2;
  double intensidadSepiaGlobal = 0.3;
  double intensidadLuzAzulGlobal = 0.2;
  double velocidadVozGlobal = 1.0;
  bool sonidoActivadoGlobal = true;
  String nombreSonidoActualGlobal = 'Local Predeterminado';
  String? rutaSonidoPersonalizadoGlobal;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AudioGlobal().init();
    _cargarBibliotecaYAjustes();
    _searchController.addListener(_aplicarFiltroSeccion);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
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
      final prefs = await SharedPreferences.getInstance();

      setState(() {
        modoOscuroGlobal = prefs.getBool('modo_oscuro_global') ?? true;
        nivelBrilloGlobal = prefs.getDouble('nivel_brillo_global') ?? 1.0;
        filtroLuzAzulGlobal = prefs.getBool('filtro_luz_azul_global') ?? false;
        modoSepiaGlobal = prefs.getBool('modo_sepia_global') ?? false;
        volumenEfectoGlobal = prefs.getDouble('volumen_efecto_global') ?? 0.8;
        intensidadFiltroGlobal = prefs.getDouble('intensidad_filtro_global') ?? 0.2;
        velocidadVozGlobal = prefs.getDouble('velocidad_voz_global') ?? 1.0;
        sonidoActivadoGlobal = prefs.getBool('sonido_activado_global') ?? true;
        nombreSonidoActualGlobal = prefs.getString('nombre_sonido_global') ?? 'Local Predeterminado';
        rutaSonidoPersonalizadoGlobal = prefs.getString('ruta_sonido_custom_global');
        ordenBiblioteca = prefs.getString('orden_biblioteca_global') ?? 'Recientes';
        TextosIdioma.idiomaActual = prefs.getString('idioma_app') ?? 'Español';
      });

      final List<String>? catGuardadas = prefs.getStringList('mis_categorias_app');
      if (catGuardadas != null) misCategorias = catGuardadas;

      final String? jsonString = prefs.getString('mis_libros_app');
      if (jsonString != null) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        libros = jsonList.map((i) => Libro.fromMap(i)).toList();
      }

      final String? jsonPistas = prefs.getString('mis_pistas_musica_app');
      if (jsonPistas != null) {
        final List<dynamic> jsonListPistas = jsonDecode(jsonPistas);
        pistasMusica = jsonListPistas.map((i) => PistaMusica.fromMap(i)).toList();
      }

      if (mounted) setState(() => _aplicarFiltroSeccion());
    } catch (e) {
      debugPrint('Error cargando biblioteca y ajustes: $e');
    }
  }

  Future<void> _guardarAjustesGlobales() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('modo_oscuro_global', modoOscuroGlobal);
      await prefs.setDouble('nivel_brillo_global', nivelBrilloGlobal);
      await prefs.setBool('filtro_luz_azul_global', filtroLuzAzulGlobal);
      await prefs.setBool('modo_sepia_global', modoSepiaGlobal);
      await prefs.setDouble('volumen_efecto_global', volumenEfectoGlobal);
      await prefs.setDouble('intensidad_filtro_global', intensidadFiltroGlobal);
      await prefs.setDouble('velocidad_voz_global', velocidadVozGlobal);
      await prefs.setBool('sonido_activado_global', sonidoActivadoGlobal);
      await prefs.setString('nombre_sonido_global', nombreSonidoActualGlobal);
      await prefs.setString('orden_biblioteca_global', ordenBiblioteca);
      await prefs.setString('idioma_app', TextosIdioma.idiomaActual);
      if (rutaSonidoPersonalizadoGlobal != null) {
        await prefs.setString('ruta_sonido_custom_global', rutaSonidoPersonalizadoGlobal!);
      } else {
        await prefs.remove('ruta_sonido_custom_global');
      }
    } catch (e) {
      debugPrint('Error guardando ajustes globales: $e');
    }
  }

  Future<void> _guardarBiblioteca() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonList = jsonEncode(libros.map((l) => l.toMap()).toList());
      await prefs.setString('mis_libros_app', jsonList);
      await prefs.setStringList('mis_categorias_app', misCategorias);
    } catch (e) {
      debugPrint('Error guardando biblioteca: $e');
    }
  }

  Future<void> _guardarPistasMusica() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonList = jsonEncode(pistasMusica.map((p) => p.toMap()).toList());
      await prefs.setString('mis_pistas_musica_app', jsonList);
    } catch (e) {
      debugPrint('Error guardando pistas de música: $e');
    }
  }

  void _aplicarFiltroSeccion() {
    List<Libro> temp = List.from(libros);

    if (seccionActual == 'audiolibros') {
      temp = temp.where((l) => l.esAudiolibro).toList();
    } else if (seccionActual == 'videos') {
      temp = temp.where((l) => l.esVideo).toList();
    } else if (seccionActual == 'favoritos') {
      temp = temp.where((l) => l.esFavorito).toList();
    } else if (seccionActual == 'porLeer') {
      temp = temp.where((l) => l.porLeer && !l.leido).toList();
    } else if (seccionActual == 'leidos') {
      temp = temp.where((l) => l.leido).toList();
    } else if (seccionActual == 'leyendo') {
      temp = temp.where((l) => l.ultimaPagina > 1 && !l.leido && !l.esVideo).toList();
    } else if (seccionActual == 'biblioteca') {
      temp = temp.where((l) => !l.esAudiolibro && !l.esVideo).toList();
    }

    if (categoriaSeleccionada != 'Todas' &&
        seccionActual != 'audiolibros' &&
        seccionActual != 'videos' &&
        seccionActual != 'estadisticas') {
      temp = temp.where((l) => l.categoria == categoriaSeleccionada).toList();
    }

    final q = _searchController.text.toLowerCase();
    if (q.isNotEmpty) {
      temp = temp.where((l) => l.titulo.toLowerCase().contains(q)).toList();
    }

    if (ordenBiblioteca == 'A-Z') {
      temp.sort((a, b) => a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase()));
    } else if (ordenBiblioteca == 'Categoría') {
      temp.sort((a, b) => a.categoria.toLowerCase().compareTo(b.categoria.toLowerCase()));
    } else {
      temp.sort((a, b) => b.id.compareTo(a.id));
    }

    setState(() {
      librosMostrados = temp;
    });
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
            modoOscuro: modoOscuroGlobal,
            modoSepia: modoSepiaGlobal,
            brillo: nivelBrilloGlobal,
            velocidadVoz: velocidadVozGlobal,
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
            modoOscuroInicial: modoOscuroGlobal,
            brilloInicial: nivelBrilloGlobal,
            filtroLuzAzulInicial: filtroLuzAzulGlobal,
            modoSepiaInicial: modoSepiaGlobal,
            intensidadFiltroInicial: intensidadFiltroGlobal,
            velocidadInicial: velocidadVozGlobal,
            sonidoActivadoInicial: sonidoActivadoGlobal,
            nombreSonidoInicial: nombreSonidoActualGlobal,
            rutaSonidoInicial: rutaSonidoPersonalizadoGlobal,
            volumenEfectoInicial: volumenEfectoGlobal,
            pistasMusica: pistasMusica,
          ),
        ),
      );
    }
    _guardarBiblioteca();
    _aplicarFiltroSeccion();
  }

  Future<void> _buscarEnWeb(String consulta) async {
    if (consulta.trim().isEmpty) return;
    final Uri url = Uri.parse('https://www.google.com/search?q=${Uri.encodeComponent(consulta)}+filetype:pdf');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('launchUrl devolvió false');
      }
    } catch (e) {
      debugPrint('Error al abrir navegador web: $e');
    }
  }

  void _crearNuevaCategoria() {
    TextEditingController catController = TextEditingController();
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ColoresApp.acentoOscuro),
            onPressed: () {
              String nombre = catController.text.trim();
              if (nombre.isNotEmpty && !misCategorias.contains(nombre)) {
                setState(() {
                  misCategorias.add(nombre);
                  categoriaSeleccionada = nombre;
                  _aplicarFiltroSeccion();
                });
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
    TextEditingController catController = TextEditingController(text: categoriaActual);
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
              String nuevoNombre = catController.text.trim();
              if (nuevoNombre.isEmpty || nuevoNombre == categoriaActual) {
                Navigator.pop(context);
                return;
              }
              if (misCategorias.contains(nuevoNombre)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ya existe una categoría con ese nombre.')),
                );
                return;
              }
              setState(() {
                int idx = misCategorias.indexOf(categoriaActual);
                if (idx != -1) misCategorias[idx] = nuevoNombre;
                for (var libro in libros) {
                  if (libro.categoria == categoriaActual) libro.categoria = nuevoNombre;
                }
                if (categoriaSeleccionada == categoriaActual) categoriaSeleccionada = nuevoNombre;
                _aplicarFiltroSeccion();
              });
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
                for (var libro in libros) {
                  if (libro.categoria == categoria) libro.categoria = 'General';
                }
                if (categoriaSeleccionada == categoria) categoriaSeleccionada = 'Todas';
                _aplicarFiltroSeccion();
              });
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
    TextEditingController notasController = TextEditingController(text: libro.notasPersonales);
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
              final bool seleccionada = libro.categoria == cat;
              return ListTile(
                title: Text(cat, style: TextStyle(color: seleccionada ? ColoresApp.acento : Colors.white)),
                trailing: seleccionada ? const Icon(Icons.check, color: ColoresApp.acento) : null,
                onTap: () {
                  setState(() {
                    libro.categoria = cat;
                    _aplicarFiltroSeccion();
                  });
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
        content: Text('¿Seguro que quieres eliminar "${libro.titulo}"? Se perderán sus notas y marcadores.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              final int indiceOriginal = libros.indexWhere((l) => l.id == libro.id);
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
                        final int idx = indiceOriginal.clamp(0, libros.length);
                        libros.insert(idx, libro);
                        _aplicarFiltroSeccion();
                      });
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

  void _agregarLibroOAudiolibro() {
    double progresoCarga = 0.0;
    bool cargandoArchivo = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: ColoresApp.fondoTarjeta,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
                        const Text(
                          '📥 Importar Contenido',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (!cargandoArchivo)
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey),
                            onPressed: () => Navigator.pop(context),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Selecciona un archivo PDF, EPUB, Audiolibro (MP3) o Video desde tu dispositivo.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 20),

                    if (cargandoArchivo) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Cargando archivo...', style: TextStyle(color: ColoresApp.acento, fontSize: 13)),
                          Text('${(progresoCarga * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: progresoCarga,
                        backgroundColor: ColoresApp.fondoPrincipal,
                        color: ColoresApp.acento,
                        minHeight: 8,
                      ),
                      const SizedBox(height: 20),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColoresApp.acentoOscuro,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.folder_open_rounded, color: Colors.white),
                          label: const Text(
                            'Explorar Archivos del Dispositivo',
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () async {
                            try {
                              await solicitarPermisosAlmacenamiento();

                              FilePickerResult? result = await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['pdf', 'mp3', 'm4a', 'wav', 'aac', 'epub', 'mp4', 'mov', 'mkv', 'avi'],
                                allowMultiple: false,
                              );

                              if (result == null || result.files.isEmpty || result.files.single.path == null) {
                                return;
                              }

                              String pathOrigen = result.files.single.path!;
                              String nombre = result.files.single.name;
                              String ext = nombre.toLowerCase();

                              bool esAudio = ext.endsWith('.mp3') || ext.endsWith('.m4a') || ext.endsWith('.wav') || ext.endsWith('.aac');
                              bool esPdf = ext.endsWith('.pdf');
                              bool esEpub = ext.endsWith('.epub');
                              bool esVideo = ext.endsWith('.mp4') || ext.endsWith('.mov') || ext.endsWith('.mkv') || ext.endsWith('.avi');

                              if (!esPdf && !esAudio && !esEpub && !esVideo) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Formato no soportado. Usa PDF, EPUB, Audio o Video.')),
                                  );
                                }
                                return;
                              }

                              setModalState(() {
                                cargandoArchivo = true;
                                progresoCarga = 0.05;
                              });
                              await Future.delayed(const Duration(milliseconds: 100));

                              final File archivoOrigen = File(pathOrigen);
                              int totalBytes = await archivoOrigen.length();
                              Directory appDir = await getApplicationDocumentsDirectory();
                              String nuevaRuta = '${appDir.path}/$nombre';

                              final File archivoDestino = File(nuevaRuta);
                              final IOSink sink = archivoDestino.openWrite();
                              int bytesCopiados = 0;

                              await for (List<int> chunk in archivoOrigen.openRead()) {
                                sink.add(chunk);
                                bytesCopiados += chunk.length;
                                if (totalBytes > 0) {
                                  setModalState(() {
                                    progresoCarga = (bytesCopiados / totalBytes).clamp(0.0, 1.0);
                                  });
                                }
                              }
                              await sink.close();

                              String catInicial = (categoriaSeleccionada == 'Todas') ? 'General' : categoriaSeleccionada;

                              final nuevoLibro = Libro(
                                id: DateTime.now().millisecondsSinceEpoch.toString(),
                                titulo: nombre.replaceAll(RegExp(r'\.(pdf|mp3|m4a|wav|aac|epub|mp4|mov|mkv|avi)$', caseSensitive: false), ''),
                                rutaLocal: nuevaRuta,
                                categoria: catInicial,
                                esAudiolibro: esAudio,
                                esEpub: esEpub,
                                esVideo: esVideo,
                              );

                              setState(() {
                                libros.add(nuevoLibro);
                                if (esAudio) {
                                  seccionActual = 'audiolibros';
                                } else if (esVideo) {
                                  seccionActual = 'videos';
                                } else {
                                  seccionActual = 'biblioteca';
                                }
                                _aplicarFiltroSeccion();
                              });

                              await _guardarBiblioteca();

                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            } catch (e) {
                              debugPrint('Error al agregar archivo: $e');
                              if (context.mounted) Navigator.pop(context);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
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
      await solicitarPermisosAlmacenamiento();
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);
      if (result == null || result.files.isEmpty || result.files.single.path == null) return;

      String pathOrigen = result.files.single.path!;
      String nombre = result.files.single.name;

      Directory appDir = await getApplicationDocumentsDirectory();
      Directory carpetaMusica = Directory('${appDir.path}/musica_fondo');
      if (!await carpetaMusica.exists()) await carpetaMusica.create(recursive: true);

      String nuevaRuta = '${carpetaMusica.path}/$nombre';
      await File(pathOrigen).copy(nuevaRuta);

      final nuevaPista = PistaMusica(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        titulo: nombre.replaceAll(RegExp(r'\.(mp3|m4a|wav|aac|ogg)$', caseSensitive: false), ''),
        rutaLocal: nuevaRuta,
      );

      setState(() => pistasMusica.add(nuevaPista));
      await _guardarPistasMusica();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${nuevaPista.titulo}" agregada a tu música para leer')),
        );
      }
    } catch (e) {
      debugPrint('Error agregando pista de música: $e');
    }
  }

  void _eliminarPistaMusica(PistaMusica pista) {
    setState(() => pistasMusica.removeWhere((p) => p.id == pista.id));
    _guardarPistasMusica();
  }

  Future<void> _abrirPixabayEfectos() async {
    final Uri url = Uri.parse('https://pixabay.com/es/sound-effects/search/pass/');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('launchUrl devolvió false');
      }
    } catch (e) {
      debugPrint('Error al abrir Pixabay: $e');
    }
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
                padding: const EdgeInsets.all(20),
                height: 750,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Configuración General y Lectura', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const Divider(color: Colors.white24),

                      const Text('Idioma / Language', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: ['Español', 'English'].map((idioma) {
                          bool sel = TextosIdioma.idiomaActual == idioma;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: ChoiceChip(
                              label: Text(idioma),
                              selected: sel,
                              selectedColor: ColoresApp.acentoOscuro,
                              backgroundColor: ColoresApp.fondoPrincipal,
                              onSelected: (val) async {
                                setModalState(() => TextosIdioma.idiomaActual = idioma);
                                setState(() => TextosIdioma.idiomaActual = idioma);
                                await _guardarAjustesGlobales();
                                _aplicarFiltroSeccion();
                                if (mounted) {
                                  Navigator.pop(context);
                                  setState(() {});
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                      const Divider(color: Colors.white24),

                      const Text('Brillo de pantalla', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Row(
                        children: [
                          const Icon(Icons.brightness_low, color: Colors.grey, size: 18),
                          Expanded(
                            child: Slider(
                              value: nivelBrilloGlobal,
                              min: 0.1,
                              max: 1.0,
                              activeColor: ColoresApp.acento,
                              onChanged: (v) {
                                setModalState(() => nivelBrilloGlobal = v);
                                setState(() {});
                                _guardarAjustesGlobales();
                              },
                            ),
                          ),
                          const Icon(Icons.brightness_high, color: Colors.white, size: 18),
                        ],
                      ),
                      const SizedBox(height: 10),

                      const Text('Intensidad del filtro de lectura', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Row(
                        children: [
                          const Icon(Icons.filter_b_and_w, color: Colors.grey, size: 18),
                          Expanded(
                            child: Slider(
                              value: intensidadFiltroGlobal,
                              min: 0.0,
                              max: 1.0,
                              activeColor: ColoresApp.acento,
                              onChanged: (v) {
                                setModalState(() => intensidadFiltroGlobal = v);
                                setState(() {});
                                _guardarAjustesGlobales();
                              },
                            ),
                          ),
                          const Icon(Icons.color_lens, color: Colors.white, size: 18),
                        ],
                      ),
                      const SizedBox(height: 10),

                      const Text('Velocidad de voz (TTS)', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _chipVelocidadGlobal(0.5, '0.5x', setModalState),
                          _chipVelocidadGlobal(1.0, '1.0x', setModalState),
                          _chipVelocidadGlobal(1.25, '1.25x', setModalState),
                          _chipVelocidadGlobal(1.5, '1.5x', setModalState),
                        ],
                      ),
                      const SizedBox(height: 15),

                      const Text('Volumen del efecto de pasar página', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Row(
                        children: [
                          const Icon(Icons.volume_mute, color: Colors.grey, size: 18),
                          Expanded(
                            child: Slider(
                              value: volumenEfectoGlobal,
                              min: 0.0,
                              max: 1.0,
                              activeColor: ColoresApp.acento,
                              onChanged: (v) {
                                setModalState(() => volumenEfectoGlobal = v);
                                setState(() {});
                                _guardarAjustesGlobales();
                              },
                            ),
                          ),
                          const Icon(Icons.volume_up, color: Colors.white, size: 18),
                        ],
                      ),
                      const Divider(color: Colors.white24),

                      SwitchListTile(
                        title: const Text('Modo Oscuro / Claro', style: TextStyle(color: Colors.white, fontSize: 13)),
                        secondary: Icon(modoOscuroGlobal ? Icons.dark_mode : Icons.light_mode, color: ColoresApp.acento),
                        activeColor: ColoresApp.acento,
                        value: modoOscuroGlobal,
                        onChanged: (val) {
                          setModalState(() => modoOscuroGlobal = val);
                          setState(() => modoOscuroGlobal = val);
                          _guardarAjustesGlobales();
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Filtro de Luz Azul (Antifatiga Nocturna)', style: TextStyle(color: Colors.white, fontSize: 13)),
                        secondary: const Icon(Icons.shield_rounded, color: Colors.amberAccent),
                        activeColor: ColoresApp.acento,
                        value: filtroLuzAzulGlobal,
                        onChanged: (val) {
                          setModalState(() => filtroLuzAzulGlobal = val);
                          setState(() => filtroLuzAzulGlobal = val);
                          _guardarAjustesGlobales();
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Modo Sepia / Papel Antiguo', style: TextStyle(color: Colors.white, fontSize: 13)),
                        secondary: const Icon(Icons.menu_book, color: Colors.orangeAccent),
                        activeColor: ColoresApp.acentoOscuro,
                        value: modoSepiaGlobal,
                        onChanged: (val) {
                          setModalState(() => modoSepiaGlobal = val);
                          setState(() => modoSepiaGlobal = val);
                          _guardarAjustesGlobales();
                        },
                      ),
                      const Divider(color: Colors.white24),

                      SwitchListTile(
                        title: const Text('Efecto de sonido al pasar página', style: TextStyle(color: Colors.white, fontSize: 13)),
                        secondary: const Icon(Icons.volume_up_rounded, color: ColoresApp.acento),
                        activeColor: ColoresApp.acento,
                        value: sonidoActivadoGlobal,
                        onChanged: (val) {
                          setModalState(() => sonidoActivadoGlobal = val);
                          setState(() => sonidoActivadoGlobal = val);
                          _guardarAjustesGlobales();
                        },
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: ColoresApp.acentoOscuro),
                          icon: const Icon(Icons.cloud_download, color: Colors.white, size: 16),
                          label: const Text('Descargar efectos de sonido en Pixabay...', style: TextStyle(color: Colors.white, fontSize: 12)),
                          onPressed: _abrirPixabayEfectos,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: ColoresApp.acento)),
                          icon: const Icon(Icons.folder_open, color: ColoresApp.acento, size: 16),
                          label: Text(
                            'Audio personalizado ($nombreSonidoActualGlobal)', 
                            style: const TextStyle(color: ColoresApp.acento, fontSize: 11), 
                            overflow: TextOverflow.ellipsis
                          ),
                          onPressed: () async {
                            try {
                              FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);
                              if (result != null && result.files.isNotEmpty && result.files.single.path != null) {
                                String path = result.files.single.path!;
                                String name = result.files.single.name;
                                setModalState(() {
                                  rutaSonidoPersonalizadoGlobal = path;
                                  nombreSonidoActualGlobal = name;
                                });
                                setState(() {});
                                _guardarAjustesGlobales();
                              }
                            } catch (e) {
                              debugPrint('Error seleccionando audio: $e');
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _chipVelocidadGlobal(double val, String label, StateSetter setModalState) {
    bool seleccionado = velocidadVozGlobal == val;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 11, color: seleccionado ? Colors.white : Colors.grey)),
        selected: seleccionado,
        selectedColor: ColoresApp.acentoOscuro,
        backgroundColor: ColoresApp.fondoPrincipal,
        onSelected: (bool selected) {
          if (selected) {
            setModalState(() => velocidadVozGlobal = val);
            setState(() => velocidadVozGlobal = val);
            _guardarAjustesGlobales();
          }
        },
      ),
    );
  }

  void _mostrarExplicacionTraduccionCompleta(Libro libro) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ColoresApp.fondoTarjeta,
        title: Row(
          children: const [
            Icon(Icons.g_translate, color: ColoresApp.acento),
            SizedBox(width: 10),
            Text('Traducir PDF Completo'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Para traducir "${libro.titulo}" completo manteniendo imágenes:', style: const TextStyle(fontSize: 13, color: Colors.white70)),
            const SizedBox(height: 12),
            const Text('1. Usa Google Translate Documents gratis:'),
            const SelectableText('https://translate.google.com/?op=docs', style: TextStyle(color: ColoresApp.acento, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('2. Sube tu PDF y tradúcelo.'),
            const SizedBox(height: 8),
            const Text('3. Añade el nuevo PDF con el botón "Agregar libro".'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido', style: TextStyle(color: ColoresApp.acento))),
        ],
      ),
    );
  }

  void _mostrarMenuOrden() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ColoresApp.fondoTarjeta,
      builder: (context) {
        Widget opcion(String nombre, IconData icon) {
          final bool activa = ordenBiblioteca == nombre;
          return ListTile(
            leading: Icon(icon, color: activa ? ColoresApp.acento : Colors.grey),
            title: Text(nombre, style: TextStyle(color: activa ? ColoresApp.acento : Colors.white)),
            trailing: activa ? const Icon(Icons.check, color: ColoresApp.acento) : null,
            onTap: () {
              setState(() {
                ordenBiblioteca = nombre;
                _aplicarFiltroSeccion();
              });
              _guardarAjustesGlobales();
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

  @override
  Widget build(BuildContext context) {
    final List<Libro> librosEnProgreso = libros.where((l) => l.ultimaPagina > 1 && !l.leido && !l.esAudiolibro && !l.esVideo).toList();

    return Opacity(
      opacity: nivelBrilloGlobal.clamp(0.1, 1.0),
      child: Stack(
        children: [
          SafeArea(
            child: Scaffold(
              backgroundColor: modoSepiaGlobal 
                  ? const Color(0xFFF4ECD8) 
                  : (modoOscuroGlobal ? const Color(0xFF0E2229) : const Color(0xFFF5F5F5)),
              appBar: AppBar(
                title: buscando
                    ? TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: TextosIdioma.get('buscarHint'),
                          border: InputBorder.none,
                          hintStyle: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : Text(TextosIdioma.get(seccionActual), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
                actions: [
                  if (buscando && _searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.language, color: ColoresApp.acento),
                      tooltip: 'Buscar en Web',
                      onPressed: () => _buscarEnWeb(_searchController.text),
                    ),
                  if (!buscando && seccionActual != 'descargar' && seccionActual != 'estadisticas')
                    IconButton(
                      icon: const Icon(Icons.sort),
                      tooltip: 'Ordenar biblioteca',
                      onPressed: _mostrarMenuOrden,
                    ),
                  IconButton(
                    icon: Icon(buscando ? Icons.close : Icons.search),
                    onPressed: () {
                      setState(() {
                        buscando = !buscando;
                        if (!buscando) {
                          _searchController.clear();
                          _aplicarFiltroSeccion();
                        }
                      });
                    },
                  ),
                ],
              ),

              // 🌟 DRAWER CON TU IMAGEN PERSONALIZADA
              drawer: Drawer(
                backgroundColor: ColoresApp.fondoDrawer,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
  DrawerHeader(
  decoration: const BoxDecoration(color: ColoresApp.fondoTarjeta),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          'assets/icono.png',
          width: 45,
          height: 45,
          fit: BoxFit.cover,
        ),
      ),
      const SizedBox(height: 10),
      const Text('Mi Lector Pro', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
      const Text('Tu biblioteca personalizada', style: TextStyle(color: Colors.grey, fontSize: 12)),
    ],
  ),
),
                  _itemDrawer(Icons.headphones_rounded, 'audiolibros'),
                    _itemDrawer(Icons.video_library_rounded, 'videos'),
                    _itemDrawer(Icons.bar_chart, 'estadisticas'),
                    ListTile(
                      leading: const Icon(Icons.settings, color: Colors.grey),
                      title: Text(TextosIdioma.get('config'), style: const TextStyle(color: Colors.white70)),
                      onTap: () {
                        Navigator.pop(context);
                        _mostrarConfiguracionGeneral();
                      },
                    ),
                    _itemDrawer(Icons.cloud_download_outlined, 'descargar'),
                    ListTile(
                      leading: const Icon(Icons.library_music_rounded, color: Colors.grey),
                      title: Text(TextosIdioma.get('musica'), style: const TextStyle(color: Colors.white70)),
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
                    const Divider(color: Colors.white24),
                    _itemDrawer(Icons.play_circle_outline, 'leyendo'),
                    _itemDrawer(Icons.menu_book, 'biblioteca'),
                    _itemDrawer(Icons.star_border, 'favoritos'),
                    _itemDrawer(Icons.access_time, 'porLeer'),
                    _itemDrawer(Icons.done_all, 'leidos'),
                  ],
                ),
              ),

              body: Column(
                children: [
                  if (seccionActual == 'biblioteca' && categoriaSeleccionada == 'Todas' && librosEnProgreso.isNotEmpty && !buscando)
                    Container(
                      height: 110,
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
                                return Container(
                                  width: 140,
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
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
                                            Text(libro.esEpub ? 'EPUB' : 'Pág. ${libro.ultimaPagina}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                          ],
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

                  if (seccionActual != 'descargar' && seccionActual != 'audiolibros' && seccionActual != 'videos' && seccionActual != 'estadisticas')
                    Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: misCategorias.length,
                              itemBuilder: (context, index) {
                                final cat = misCategorias[index];
                                final bool activa = categoriaSeleccionada == cat;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                  child: GestureDetector(
                                    onLongPress: () => _gestionarCategoria(cat),
                                    child: ChoiceChip(
                                      label: Text(cat),
                                      selected: activa,
                                      selectedColor: ColoresApp.acentoOscuro,
                                      backgroundColor: ColoresApp.fondoTarjeta,
                                      labelStyle: TextStyle(
                                        color: activa ? Colors.white : Colors.grey[300],
                                        fontWeight: activa ? FontWeight.bold : FontWeight.normal,
                                      ),
                                      onSelected: (bool selected) {
                                        setState(() {
                                          categoriaSeleccionada = cat;
                                          _aplicarFiltroSeccion();
                                        });
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: ColoresApp.acento),
                            tooltip: 'Nueva categoría',
                            onPressed: _crearNuevaCategoria,
                          ),
                        ],
                      ),
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
                                        Text('No hay contenidos en "${TextosIdioma.get(seccionActual)}"', style: const TextStyle(color: Colors.grey, fontSize: 16)),
                                      ],
                                    ),
                                  )
                                : GridView.builder(
                                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      childAspectRatio: 0.52,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                    ),
                                    itemCount: librosMostrados.length,
                                    itemBuilder: (context, index) {
                                      final libro = librosMostrados[index];
                                      return Container(
                                        key: ValueKey(libro.id),
                                        decoration: BoxDecoration(
                                          color: ColoresApp.fondoTarjeta,
                                          borderRadius: BorderRadius.circular(10),
                                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            Expanded(
                                              child: InkWell(
                                                onTap: () => _abrirLibro(libro),
                                                child: ClipRRect(
                                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                                                  child: libro.esAudiolibro
                                                      ? Container(
                                                          color: const Color(0xFF1E3A8A),
                                                          child: const Center(child: Icon(Icons.headphones_rounded, size: 50, color: ColoresApp.acento)),
                                                        )
                                                      : libro.esVideo
                                                          ? Container(
                                                              color: const Color(0xFF3B0764),
                                                              child: const Center(child: Icon(Icons.play_circle_fill_rounded, size: 50, color: ColoresApp.acento)),
                                                            )
                                                          : libro.esEpub
                                                              ? Container(
                                                                  color: const Color(0xFF1F2937),
                                                                  child: const Center(child: Icon(Icons.menu_book_rounded, size: 50, color: ColoresApp.acento)),
                                                                )
                                                              : PortadaPdfWidget(key: ValueKey(libro.id), rutaPdf: libro.rutaLocal, titulo: libro.titulo),
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.all(6.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    libro.titulo,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 11,
                                                      color: modoSepiaGlobal ? Colors.black87 : Colors.white,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    libro.esAudiolibro
                                                        ? 'Audiolibro'
                                                        : libro.esVideo
                                                            ? 'Video'
                                                            : (libro.esEpub ? 'EPUB' : 'Pág. ${libro.ultimaPagina}'),
                                                    style: TextStyle(color: modoSepiaGlobal ? Colors.black54 : Colors.grey, fontSize: 9),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      InkWell(
                                                        onTap: () {
                                                          setState(() => libro.esFavorito = !libro.esFavorito);
                                                          _guardarBiblioteca();
                                                          _aplicarFiltroSeccion();
                                                        },
                                                        child: Padding(
                                                          padding: const EdgeInsets.all(2.0),
                                                          child: Icon(
                                                            libro.esFavorito ? Icons.star : Icons.star_border,
                                                            color: libro.esFavorito ? Colors.amber : Colors.grey,
                                                            size: 16,
                                                          ),
                                                        ),
                                                      ),
                                                      InkWell(
                                                        onTap: () => _abrirNotasDelLibro(libro),
                                                        child: Padding(
                                                          padding: const EdgeInsets.all(2.0),
                                                          child: Icon(
                                                            Icons.note_alt,
                                                            color: libro.notasPersonales.isNotEmpty ? ColoresApp.acento : Colors.grey,
                                                            size: 16,
                                                          ),
                                                        ),
                                                      ),
                                                      PopupMenuButton<String>(
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                                        icon: const Icon(Icons.more_vert, color: Colors.grey, size: 18),
                                                        onSelected: (val) {
                                                          if (val == 'category') {
                                                            _cambiarCategoriaLibro(libro);
                                                          } else if (val == 'delete') {
                                                            _confirmarEliminarLibro(libro);
                                                          } else if (val == 'translate') {
                                                            _mostrarExplicacionTraduccionCompleta(libro);
                                                          }
                                                        },
                                                        itemBuilder: (context) => [
                                                          if (!libro.esAudiolibro && !libro.esVideo) ...[
                                                            const PopupMenuItem(
                                                              value: 'category',
                                                              child: Row(children: [Icon(Icons.folder_outlined, size: 18, color: ColoresApp.acento), SizedBox(width: 8), Text('Cambiar categoría')]),
                                                            ),
                                                            if (!libro.esEpub)
                                                              const PopupMenuItem(
                                                                value: 'translate',
                                                                child: Row(children: [Icon(Icons.translate, size: 18, color: ColoresApp.acento), SizedBox(width: 8), Text('Traducir PDF')]),
                                                              ),
                                                          ],
                                                          const PopupMenuItem(value: 'delete', child: Text('Eliminar', style: TextStyle(color: Colors.redAccent))),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                  ),
                ],
              ),

              floatingActionButton: Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: FloatingActionButton.extended(
                  backgroundColor: ColoresApp.acentoOscuro,
                  onPressed: _agregarLibroOAudiolibro,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: Text(TextosIdioma.get('agregar'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),

          if (filtroLuzAzulGlobal)
            IgnorePointer(
              child: Container(
                color: Colors.amber.withOpacity(intensidadFiltroGlobal.clamp(0.05, 0.5)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _itemDrawer(IconData icon, String claveInterna) {
    final bool seleccionado = seccionActual == claveInterna;
    return ListTile(
      leading: Icon(icon, color: seleccionado ? ColoresApp.acento : Colors.grey),
      title: Text(
        TextosIdioma.get(claveInterna),
        style: TextStyle(
          color: seleccionado ? ColoresApp.acento : Colors.white70,
          fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () {
        setState(() {
          seccionActual = claveInterna;
          _aplicarFiltroSeccion();
        });
        Navigator.pop(context);
      },
    );
  }
}

// ---------------------------------------------------------
// PANTALLA DE ESTADÍSTICAS Y HÁBITOS
// ---------------------------------------------------------
class PantallaEstadisticas extends StatelessWidget {
  final List<Libro> libros;
  final List<PistaMusica> pistasMusica;

  const PantallaEstadisticas({super.key, required this.libros, this.pistasMusica = const []});

  @override
  Widget build(BuildContext context) {
    int totalPdfs = libros.where((l) => !l.esAudiolibro && !l.esEpub && !l.esVideo).length;
    int totalEpub = libros.where((l) => l.esEpub).length;
    int totalAudio = libros.where((l) => l.esAudiolibro).length;
    int totalVideo = libros.where((l) => l.esVideo).length;
    int leidos = libros.where((l) => l.leido).length;
    int enProgreso = libros.where((l) => l.ultimaPagina > 1 && !l.leido).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Estadísticas y Hábitos de Lectura', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
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
            _cardStat('Audiolibros', '$totalAudio', Icons.headphones, Colors.purpleAccent),
            const SizedBox(width: 10),
            _cardStat('Videos', '$totalVideo', Icons.video_library, Colors.pinkAccent),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _cardStat('Pistas de Música', '${pistasMusica.length}', Icons.library_music, Colors.tealAccent),
            const SizedBox(width: 10),
            _cardStat('Total', '${libros.length}', Icons.library_books, Colors.amberAccent),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          color: ColoresApp.fondoTarjeta,
          child: const ListTile(
            leading: Icon(Icons.local_fire_department, color: Colors.amber, size: 36),
            title: Text('Racha de Lectura Activa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text('¡Excelente hábito! Continúa explorando tus libros y documentos.', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Widget _cardStat(String titulo, String valor, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: ColoresApp.fondoTarjeta, borderRadius: BorderRadius.circular(10)),
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

// ---------------------------------------------------------
// BIBLIOTECAS WEB DE DESCARGA DIRECTA
// ---------------------------------------------------------
class PantallaBibliotecasDirectas extends StatelessWidget {
  const PantallaBibliotecasDirectas({super.key});

  void _abrirSitioEnApp(BuildContext context, String titulo, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PantallaVisorWebCompleto(titulo: titulo, url: url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> bibliotecas = [
      {
        'nombre': 'Elejandría (Recomendada)',
        'desc': 'Libros en español gratis en PDF y EPUB (Dominio público).',
        'url': 'https://www.elejandria.com',
        'icon': '📚'
      },
      {
        'nombre': 'Proyecto Gutenberg',
        'desc': 'Más de 70.000 libros gratuitos en EPUB y PDF clásicos.',
        'url': 'https://www.gutenberg.org',
        'icon': '🏛️'
      },
      {
        'nombre': 'Open Library / Internet Archive',
        'desc': 'Millones de libros globales gratis con préstamo digital.',
        'url': 'https://openlibrary.org/?lang=es',
        'icon': '🌐'
      },
      {
        'nombre': 'Biblioteca Digital Hispánica',
        'desc': 'Manuscritos y obras históricas de la BNE de España.',
        'url': 'http://www.bne.es/es/Catalogos/BibliotecaDigitalHispanica/',
        'icon': '📜'
      },
      {
        'nombre': 'Wikisource en Español',
        'desc': 'Biblioteca colaborativa de novelas y ensayos clásicos.',
        'url': 'https://es.wikisource.org',
        'icon': '📝'
      },
      {
        'nombre': 'Cervantes Virtual',
        'desc': 'Literatura clásica e hispanoamericana académica.',
        'url': 'https://www.cervantesvirtual.com',
        'icon': '🎓'
      },
      {
        'nombre': 'InTechOpen (Académico)',
        'desc': 'Libros de ciencia, ingeniería y tecnología en PDF.',
        'url': 'https://www.intechopen.com/books',
        'icon': '💻'
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Biblioteca Pública de Obras Clásicas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 6),
        const Text('Explora colecciones digitales de literatura clásica y textos de dominio público.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 16),
        ...bibliotecas.map((b) => Card(
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

// ---------------------------------------------------------
// MÚSICA CLÁSICA GRATUITA PARA LEER
// ---------------------------------------------------------
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
        setState(() => _idSonando = null);
      } else {
        await _previa.stop();
        await _previa.play(DeviceFileSource(pista.rutaLocal));
        setState(() => _idSonando = pista.id);
      }
    } catch (e) {
      debugPrint('Error probando pista: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> fuentes = [
      {
        'nombre': 'WWFM Classical Network',
        'desc': 'Emisora pública universitaria en alta fidelidad. Sonido continuo garantizado en segundo plano.',
        'url': 'https://wwfm.streamguys1.com/live-mp3',
        'icon': '📻'
      },
      {
        'nombre': 'Musopen - Repositorio Oficial',
        'desc': 'Plataforma legal de partituras y grabaciones de música clásica de dominio público.',
        'url': 'https://musopen.org/',
        'icon': '🏛️'
      },
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Música para Leer 🎼')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ColoresApp.acentoOscuro,
        icon: const Icon(Icons.library_add, color: Colors.white),
        label: const Text('Agregar pista', style: TextStyle(color: Colors.white)),
        onPressed: () async {
          await widget.onAgregarPista();
          setState(() {});
        },
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Emisora Pública y Fuentes Clásicas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 6),
          const Text(
            'Toca la emisora online para iniciar la música en segundo plano. Puedes presionar "atrás" o abrir tus libros y la reproducción continuará sonando sin pararse.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          ...fuentes.map((f) => Card(
                color: ColoresApp.fondoTarjeta,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Text(f['icon']!, style: const TextStyle(fontSize: 32)),
                  title: Text(f['nombre']!, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  subtitle: Text(f['desc']!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  trailing: Icon(
                    f['url']!.contains('streamguys1')
                        ? Icons.play_circle_fill
                        : Icons.arrow_forward_ios,
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
          Text('Tus pistas guardadas (${widget.pistas.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          if (widget.pistas.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('Aún no tienes música guardada en la app. Descarga una pieza clásica y agrégala con el botón de abajo.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            )
          else
            ...widget.pistas.map((p) {
              final bool sonando = _idSonando == p.id;
              return Card(
                color: ColoresApp.fondoTarjeta,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(sonando ? Icons.stop_circle : Icons.music_note, color: ColoresApp.acento),
                  title: Text(p.titulo, style: const TextStyle(color: Colors.white, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
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

// ---------------------------------------------------------
// WIDGET DE PORTADA PDF NATIVA
// ---------------------------------------------------------
class PortadaPdfWidget extends StatefulWidget {
  final String rutaPdf;
  final String titulo;

  const PortadaPdfWidget({super.key, required this.rutaPdf, required this.titulo});

  @override
  State<PortadaPdfWidget> createState() => _PortadaPdfWidgetState();
}

class _PortadaPdfWidgetState extends State<PortadaPdfWidget> {
  pdfx.PdfPageImage? _imagenPortada;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _generarPortada();
  }

  Future<void> _generarPortada() async {
    try {
      final doc = await pdfx.PdfDocument.openFile(widget.rutaPdf);
      final page = await doc.getPage(1);
      final pageImage = await page.render(
        width: page.width * 1.5,
        height: page.height * 1.5,
        format: pdfx.PdfPageImageFormat.jpeg,
      );
      await page.close();
      await doc.close();

      if (mounted) {
        setState(() {
          _imagenPortada = pageImage;
          _cargando = false;
        });
      }
    } catch (e) {
      debugPrint('Error generando portada de "${widget.titulo}": $e');
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Container(
        color: const Color(0xFF244A57),
        child: const Center(child: CircularProgressIndicator(color: ColoresApp.acento)),
      );
    }

    if (_imagenPortada != null) {
      return Image.memory(_imagenPortada!.bytes, fit: BoxFit.cover, width: double.infinity);
    }

    return Container(
      color: const Color(0xFF244A57),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 40),
          const SizedBox(height: 8),
          Text(widget.titulo, maxLines: 3, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.white70)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// MINI REPRODUCTOR GLOBAL DE MÚSICA DE FONDO
// ---------------------------------------------------------
class MiniReproductorMusicaFondo extends StatefulWidget {
  final List<PistaMusica> pistas;

  const MiniReproductorMusicaFondo({super.key, required this.pistas});

  @override
  State<MiniReproductorMusicaFondo> createState() => _MiniReproductorMusicaFondoState();
}

class _MiniReproductorMusicaFondoState extends State<MiniReproductorMusicaFondo> {
  @override
  void initState() {
    super.initState();
    AudioGlobal().registrarListener(_actualizarUI);
  }

  @override
  void dispose() {
    AudioGlobal().removerListener(_actualizarUI);
    super.dispose();
  }

  void _actualizarUI() {
    if (mounted) setState(() {});
  }

  void _mostrarSelectorPistas() {
    if (widget.pistas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aún no tienes música guardada. Ve a "Música para Leer 🎼".')),
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
              ...widget.pistas.map((p) => ListTile(
                    leading: const Icon(Icons.music_note, color: ColoresApp.acento),
                    title: Text(p.titulo, style: const TextStyle(color: Colors.white, fontSize: 13)),
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

  void _mostrarPanelControl() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ColoresApp.fondoTarjeta,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AudioGlobal().tituloActual != null ? 'Sonando: ${AudioGlobal().tituloActual}' : 'Sin música',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
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
                            onChanged: (v) {
                              setModalState(() => AudioGlobal().volumen = v);
                              setState(() {});
                              AudioGlobal().cambiarVolumen(v);
                            },
                          ),
                        ),
                        const Icon(Icons.volume_up, color: Colors.white, size: 18),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton.icon(
                          icon: Icon(AudioGlobal().sonando ? Icons.pause : Icons.play_arrow, color: ColoresApp.acento),
                          label: Text(AudioGlobal().sonando ? 'Pausar' : 'Reproducir', style: const TextStyle(color: ColoresApp.acento)),
                          onPressed: () async {
                            await AudioGlobal().pausarOReanudar();
                            setModalState(() {});
                            setState(() {});
                          },
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.playlist_play, color: Colors.white70),
                          label: const Text('Cambiar pista', style: TextStyle(color: Colors.white70)),
                          onPressed: () {
                            Navigator.pop(context);
                            _mostrarSelectorPistas();
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
    final bool sonando = AudioGlobal().sonando;
    return IconButton(
      icon: Icon(sonando ? Icons.music_note : Icons.music_off, color: sonando ? ColoresApp.acento : Colors.grey, size: 20),
      tooltip: 'Música de fondo para leer',
      onPressed: () {
        if (!AudioGlobal().sonando && AudioGlobal().tituloActual == null) {
          _mostrarSelectorPistas();
        } else {
          _mostrarPanelControl();
        }
      },
    );
  }
}

// ---------------------------------------------------------
// LECTOR PDF CON RESALTADOR Y BORRADOR
// ---------------------------------------------------------
class AreaResaltada {
  final double x;
  final double y;
  final double ancho;
  final double alto;
  final Color color;
  final double opacidad;

  AreaResaltada({
    required this.x,
    required this.y,
    required this.ancho,
    required this.alto,
    required this.color,
    required this.opacidad,
  });

  Map<String, dynamic> toMap() => {
        'x': x,
        'y': y,
        'ancho': ancho,
        'alto': alto,
        'color': color.value,
        'opacidad': opacidad,
      };

  factory AreaResaltada.fromMap(Map<String, dynamic> map) => AreaResaltada(
        x: map['x'] ?? 0.0,
        y: map['y'] ?? 0.0,
        ancho: map['ancho'] ?? 0.0,
        alto: map['alto'] ?? 0.0,
        color: Color(map['color'] ?? Colors.yellow.value),
        opacidad: map['opacidad'] ?? 0.3,
      );
}

class PantallaLectorPDF extends StatefulWidget {
  final Libro libro;
  final bool modoOscuroInicial;
  final double brilloInicial;
  final bool filtroLuzAzulInicial;
  final bool modoSepiaInicial;
  final double intensidadFiltroInicial;
  final double velocidadInicial;
  final bool sonidoActivadoInicial;
  final String nombreSonidoInicial;
  final String? rutaSonidoInicial;
  final double volumenEfectoInicial;
  final List<PistaMusica> pistasMusica;

  const PantallaLectorPDF({
    super.key,
    required this.libro,
    required this.modoOscuroInicial,
    required this.brilloInicial,
    required this.filtroLuzAzulInicial,
    required this.modoSepiaInicial,
    required this.intensidadFiltroInicial,
    required this.velocidadInicial,
    required this.sonidoActivadoInicial,
    required this.nombreSonidoInicial,
    required this.rutaSonidoInicial,
    required this.volumenEfectoInicial,
    this.pistasMusica = const [],
  });

  @override
  State<PantallaLectorPDF> createState() => _PantallaLectorPDFState();
}

class _PantallaLectorPDFState extends State<PantallaLectorPDF> {
  int totalPaginas = 0;
  int paginaActual = 0;
  late bool modoOscuro;
  late double nivelBrillo;
  late bool modoSepia;
  late double intensidadFiltro;
  bool cargandoDocumento = true;
  late double velocidadVoz;
  late double volumenEfecto;

  bool modoResaltadorActivo = false;
  bool modoBorradorActivo = false;
  Color colorResaltadorActual = Colors.yellow;
  double opacidadResaltadorActual = 0.3;

  final Map<int, List<AreaResaltada>> _resaltadosPorPagina = {};
  final AudioPlayer _playerEfectoPagina = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();

  late bool sonidoActivado;
  late String nombreSonidoActual;
  late String? rutaSonidoPersonalizado;

  @override
  void initState() {
    super.initState();
    modoOscuro = widget.modoOscuroInicial;
    nivelBrillo = widget.brilloInicial;
    modoSepia = widget.modoSepiaInicial;
    intensidadFiltro = widget.intensidadFiltroInicial;
    velocidadVoz = widget.velocidadInicial;
    sonidoActivado = widget.sonidoActivadoInicial;
    nombreSonidoActual = widget.nombreSonidoInicial;
    rutaSonidoPersonalizado = widget.rutaSonidoInicial;
    volumenEfecto = widget.volumenEfectoInicial;

    _initTts();
  }

  void _initTts() async {
    try {
      await _flutterTts.setLanguage("es-ES");
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(velocidadVoz);
    } catch (e) {
      debugPrint('Error inicializando TTS: $e');
    }
  }

  @override
  void dispose() {
    _playerEfectoPagina.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _reproducirSonidoPagina() async {
    if (!sonidoActivado) return;
    try {
      await _playerEfectoPagina.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.notificationEvent,
            audioFocus: AndroidAudioFocus.none,
          ),
        ),
      );

      await _playerEfectoPagina.setVolume(volumenEfecto);
      await _playerEfectoPagina.setPlayerMode(PlayerMode.lowLatency);

      if (rutaSonidoPersonalizado != null && File(rutaSonidoPersonalizado!).existsSync()) {
        await _playerEfectoPagina.stop();
        await _playerEfectoPagina.play(DeviceFileSource(rutaSonidoPersonalizado!));
      } else {
        await _playerEfectoPagina.stop();
        await _playerEfectoPagina.play(AssetSource('sounds/page_turn.mp3'));
      }
    } catch (e) {
      debugPrint('Error reproduciendo sonido de página: $e');
    }
  }

  void _mostrarVisorInterno(String titulo, String urlBusqueda) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PantallaVisorWebCompleto(titulo: titulo, url: urlBusqueda),
      ),
    );
  }

  void _manejarAccionResaltador(DragUpdateDetails details) {
    final double x = details.localPosition.dx;
    final double y = details.localPosition.dy;

    setState(() {
      _resaltadosPorPagina.putIfAbsent(paginaActual, () => []);

      if (modoResaltadorActivo) {
        _resaltadosPorPagina[paginaActual]!.add(
          AreaResaltada(
            x: x - 20,
            y: y - 10,
            ancho: 40,
            alto: 22,
            color: colorResaltadorActual,
            opacidad: opacidadResaltadorActual,
          ),
        );
      } else if (modoBorradorActivo) {
        _resaltadosPorPagina[paginaActual]!.removeWhere((r) {
          return (x >= r.x - 15 && x <= r.x + r.ancho + 15) &&
                 (y >= r.y - 15 && y <= r.y + r.alto + 15);
        });
      }
    });
  }

  void _mostrarMenuPersonalizacionResaltador() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ColoresApp.fondoTarjeta,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                    const Text(
                      '🎨 Personalizar Resaltador',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    const Text('Selecciona el color del marcador:', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
                        const Text('Opacidad del trazo:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        Text('${(opacidadResaltadorActual * 100).toInt()}%', style: const TextStyle(color: ColoresApp.acento, fontWeight: FontWeight.bold)),
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
          border: Border.all(
            color: seleccionado ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            if (seleccionado)
              const BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double porcentajeLectura = totalPaginas > 0 ? ((paginaActual + 1) / totalPaginas) * 100 : 0.0;
    final List<AreaResaltada> resaltadosActuales = _resaltadosPorPagina[paginaActual] ?? [];

    return SafeArea(
      child: Scaffold(
        backgroundColor: modoSepia
            ? const Color(0xFFF4ECD8)
            : (modoOscuro ? const Color(0xFF121212) : const Color(0xFFF5F5F5)),
        appBar: AppBar(
          backgroundColor: ColoresApp.fondoPrincipal,
          title: Text(widget.libro.titulo, style: const TextStyle(fontSize: 15)),
          actions: [
            MiniReproductorMusicaFondo(pistas: widget.pistasMusica),

            IconButton(
              icon: Icon(
                Icons.highlight,
                color: modoResaltadorActivo ? colorResaltadorActual : Colors.grey,
              ),
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
              icon: Icon(
                Icons.cleaning_services_rounded,
                color: modoBorradorActivo ? Colors.redAccent : Colors.grey,
              ),
              tooltip: 'Activar Borrador',
              onPressed: () {
                setState(() {
                  modoBorradorActivo = !modoBorradorActivo;
                  if (modoBorradorActivo) modoResaltadorActivo = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(modoBorradorActivo ? '🧹 Borrador ACTIVO: Pasa el dedo sobre lo resaltado para borrarlo' : 'Borrador desactivado'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),

            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              tooltip: 'Opciones de anotación',
              onSelected: (val) {
                if (val == 'config_resaltador') {
                  _mostrarMenuPersonalizacionResaltador();
                } else if (val == 'limpiar_pagina') {
                  setState(() {
                    _resaltadosPorPagina[paginaActual]?.clear();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('🗑️ Resaltados borrados en esta página')),
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'config_resaltador',
                  child: Row(
                    children: [
                      Icon(Icons.palette, color: ColoresApp.acento, size: 20),
                      SizedBox(width: 10),
                      Text('Ajustar color y opacidad'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'limpiar_pagina',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep, color: Colors.redAccent, size: 20),
                      SizedBox(width: 10),
                      Text('Borrar todos los resaltados de esta página'),
                    ],
                  ),
                ),
              ],
            ),

            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${paginaActual + 1} / $totalPaginas', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('${porcentajeLectura.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 9, color: ColoresApp.acento)),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            Opacity(
              opacity: nivelBrillo.clamp(0.1, 1.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      PDFView(
                        filePath: widget.libro.rutaLocal,
                        enableSwipe: true,
                        swipeHorizontal: true,
                        pageSnap: true,
                        autoSpacing: false,
                        pageFling: true,
                        defaultPage: widget.libro.ultimaPagina > 0 ? widget.libro.ultimaPagina - 1 : 0,
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
                          }
                        },
                      ),

                      Positioned.fill(
                        child: (modoResaltadorActivo || modoBorradorActivo)
                            ? GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onPanUpdate: (details) => _manejarAccionResaltador(details),
                                child: Stack(
                                  children: resaltadosActuales.map((r) {
                                    return Positioned(
                                      left: r.x,
                                      top: r.y,
                                      child: Container(
                                        width: r.ancho,
                                        height: r.alto,
                                        decoration: BoxDecoration(
                                          color: r.color.withOpacity(r.opacidad),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              )
                            : IgnorePointer(
                                child: Stack(
                                  children: resaltadosActuales.map((r) {
                                    return Positioned(
                                      left: r.x,
                                      top: r.y,
                                      child: Container(
                                        width: r.ancho,
                                        height: r.alto,
                                        decoration: BoxDecoration(
                                          color: r.color.withOpacity(r.opacidad),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
            if (widget.filtroLuzAzulInicial)
              IgnorePointer(
                child: Container(
                  color: Colors.amber.withOpacity(0.2),
                ),
              ),
            if (cargandoDocumento)
              Container(
                color: ColoresApp.fondoPrincipal,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: ColoresApp.acento),
                      const SizedBox(height: 16),
                      Text('Cargando libro...', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: Container(
          color: ColoresApp.fondoPrincipal,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(side: const BorderSide(color: ColoresApp.acento)),
                icon: const Icon(Icons.search, size: 16, color: ColoresApp.acento),
                label: const Text('Wikipedia / Diccionario', style: TextStyle(fontSize: 11, color: ColoresApp.acento)),
                onPressed: () {
                  _mostrarVisorInterno(
                    'Diccionario / Wikipedia', 
                    'https://es.wikipedia.org/wiki/Special:Search?search=${Uri.encodeComponent(widget.libro.titulo)}'
                  );
                },
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.amberAccent)),
                icon: const Icon(Icons.translate, size: 16, color: Colors.amberAccent),
                label: const Text('Traductor Rápido', style: TextStyle(fontSize: 11, color: Colors.amberAccent)),
                onPressed: () {
                  _mostrarVisorInterno(
                    'Traductor Web', 
                    'https://translate.google.com/?sl=auto&tl=es&op=translate'
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// LECTOR DE EPUB FLUIDO
// ---------------------------------------------------------
class PantallaLectorEpub extends StatefulWidget {
  final Libro libro;
  final bool modoOscuro;
  final bool modoSepia;
  final double brillo;
  final double velocidadVoz;
  final List<PistaMusica> pistasMusica;

  const PantallaLectorEpub({
    super.key,
    required this.libro,
    required this.modoOscuro,
    required this.modoSepia,
    required this.brillo,
    required this.velocidadVoz,
    this.pistasMusica = const [],
  });

  @override
  State<PantallaLectorEpub> createState() => _PantallaLectorEpubState();
}

class _PantallaLectorEpubState extends State<PantallaLectorEpub> {
  epubx.EpubBook? _epubBook;
  bool _cargando = true;
  double _tamanioFuente = 18.0;
  
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
      await _flutterTts.setLanguage("es-ES");
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(widget.velocidadVoz);

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
      List<int> bytes = await file.readAsBytes();
      epubx.EpubBook book = await epubx.EpubReader.readBook(bytes);
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
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _toggleLecturaVozCapitulo(int index, String textoCapitulo) async {
    try {
      final bool esElMismoCapitulo = capituloLeyendoIndex == index;

      if (estaLeyendoVoz && esElMismoCapitulo) {
        await _flutterTts.stop();
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

      String textoLimpio = textoCapitulo.replaceAll(RegExp(r'<[^>]*>'), '');
      setState(() {
        estaLeyendoVoz = true;
        capituloLeyendoIndex = index;
      });
      await _flutterTts.speak(textoLimpio);
    } catch (e) {
      debugPrint('Error en lectura de voz: $e');
    }
  }

  void _mostrarVisorInterno(String titulo, String urlBusqueda) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PantallaVisorWebCompleto(titulo: titulo, url: urlBusqueda),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor = widget.modoSepia ? const Color(0xFFF4ECD8) : (widget.modoOscuro ? const Color(0xFF121212) : const Color(0xFFF5F5F5));
    Color textColor = widget.modoSepia ? Colors.black87 : (widget.modoOscuro ? Colors.white70 : Colors.black87);

    List<epubx.EpubChapter> capitulos = [];
    if (_epubBook != null && _epubBook!.Chapters != null) {
      capitulos = _epubBook!.Chapters!;
    }

    return SafeArea(
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: ColoresApp.fondoPrincipal,
          title: Text(widget.libro.titulo, style: const TextStyle(fontSize: 14)),
          actions: [
            MiniReproductorMusicaFondo(pistas: widget.pistasMusica),
            IconButton(
              icon: const Icon(Icons.text_decrease),
              onPressed: () => setState(() => _tamanioFuente = (_tamanioFuente - 2).clamp(12.0, 32.0)),
            ),
            Center(child: Text('${_tamanioFuente.toInt()}px', style: const TextStyle(fontSize: 12))),
            IconButton(
              icon: const Icon(Icons.text_increase),
              onPressed: () => setState(() => _tamanioFuente = (_tamanioFuente + 2).clamp(12.0, 32.0)),
            ),
          ],
        ),
        body: _cargando
            ? const Center(child: CircularProgressIndicator(color: ColoresApp.acento))
            : capitulos.isEmpty
                ? const Center(child: Text('No se pudieron leer los capítulos de este EPUB.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: capitulos.length,
                    itemBuilder: (context, index) {
                      final chapter = capitulos[index];
                      String tituloCapitulo = chapter.Title ?? 'Capítulo ${index + 1}';
                      String contenidoHtml = chapter.HtmlContent ?? '';
                      final bool leyendoEsteCapitulo = estaLeyendoVoz && capituloLeyendoIndex == index;

                      return ExpansionTile(
                        title: Row(
                          children: [
                            Expanded(child: Text(tituloCapitulo, style: TextStyle(fontWeight: FontWeight.bold, color: textColor))),
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
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
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
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0, left: 8.0, right: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(side: const BorderSide(color: ColoresApp.acento)),
                                  icon: const Icon(Icons.search, size: 16, color: ColoresApp.acento),
                                  label: const Text('Wikipedia / Diccionario', style: TextStyle(fontSize: 11, color: ColoresApp.acento)),
                                  onPressed: () {
                                    String termino = chapter.Title ?? widget.libro.titulo;
                                    _mostrarVisorInterno(
                                      'Diccionario / Wikipedia', 
                                      'https://es.wikipedia.org/wiki/Special:Search?search=${Uri.encodeComponent(termino)}'
                                    );
                                  },
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.amberAccent)),
                                  icon: const Icon(Icons.translate, size: 16, color: Colors.amberAccent),
                                  label: const Text('Traductor Rápido', style: TextStyle(fontSize: 11, color: Colors.amberAccent)),
                                  onPressed: () {
                                    _mostrarVisorInterno(
                                      'Traductor Web', 
                                      'https://translate.google.com/?sl=auto&tl=es&op=translate'
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
      ),
    );
  }
}

// ---------------------------------------------------------
// PANTALLA DE VISOR WEB COMPLETO
// ---------------------------------------------------------
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

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setUserAgent("Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36")
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) setState(() => cargando = false);
          },
          onNavigationRequest: (NavigationRequest request) {
            String urlLower = request.url.toLowerCase();
            if (urlLower.startsWith('intent://') || 
                urlLower.startsWith('market://') || 
                urlLower.startsWith('whatsapp://') || 
                urlLower.endsWith('.pdf') || 
                urlLower.endsWith('.epub') || 
                urlLower.contains('download') || 
                urlLower.contains('descargar')) {
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
                if (mounted) Navigator.pop(context);
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => controller.reload(),
            ),
          ],
        ),
        body: Stack(
          children: [
            Container(
              color: Colors.white,
              child: WebViewWidget(controller: controller),
            ),
            if (cargando)
              Container(
                color: ColoresApp.fondoPrincipal,
                child: const Center(
                  child: CircularProgressIndicator(color: ColoresApp.acento),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// REPRODUCTOR DE AUDIOLIBROS
// ---------------------------------------------------------
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

  void _prepararAudio() async {
    try {
      _player.onDurationChanged.listen((d) => setState(() => duracionTotal = d));
      _player.onPositionChanged.listen((p) {
        setState(() => posicionActual = p);
        widget.libro.posicionMs = p.inMilliseconds;
      });
      _player.onPlayerComplete.listen((_) {
        setState(() => sonando = false);
        widget.libro.posicionMs = 0;
        widget.libro.leido = true;
      });

      await _player.setSource(DeviceFileSource(widget.libro.rutaLocal));

      if (widget.libro.posicionMs > 0 && !_yaReanudo) {
        _yaReanudo = true;
        await _player.seek(Duration(milliseconds: widget.libro.posicionMs));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Reanudando desde ${_formatDuration(Duration(milliseconds: widget.libro.posicionMs))}')),
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

  void _playPausa() async {
    try {
      if (sonando) {
        await _player.pause();
        setState(() => sonando = false);
      } else {
        await _player.setPlaybackRate(velocidadAudio);
        await _player.play(DeviceFileSource(widget.libro.rutaLocal));
        if (posicionActual.inMilliseconds > 0) {
          await _player.seek(posicionActual);
        }
        setState(() => sonando = true);
      }
    } catch (e) {
      debugPrint('Error en reproducción de audiolibro: $e');
    }
  }

  void _cambiarVelocidad(double nuevaVelocidad) async {
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
        if (minutosRestantesTimer > 1) {
          setState(() => minutosRestantesTimer--);
        } else {
          _player.pause();
          timer.cancel();
          setState(() {
            sonando = false;
            minutosRestantesTimer = 0;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Temporizador finalizado: Audiolibro pausado.')),
          );
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
              Text(widget.libro.titulo, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              if (minutosRestantesTimer > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text('Apagado automático en $minutosRestantesTimer min', style: const TextStyle(color: Colors.amberAccent, fontSize: 12)),
                ),
              const SizedBox(height: 10),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Velocidad:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(width: 8),
                  _chipVelocidadAudio(0.5, '0.5x'),
                  _chipVelocidadAudio(1.0, '1.0x'),
                  _chipVelocidadAudio(1.5, '1.5x'),
                  _chipVelocidadAudio(2.0, '2.0x'),
                ],
              ),

              const SizedBox(height: 10),
              Slider(
                value: posicionActual.inSeconds.toDouble().clamp(0.0, duracionTotal.inSeconds > 0 ? duracionTotal.inSeconds.toDouble() : 1.0),
                max: duracionTotal.inSeconds > 0 ? duracionTotal.inSeconds.toDouble() : 1.0,
                activeColor: ColoresApp.acento,
                onChanged: (val) => _player.seek(Duration(seconds: val.toInt())),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(posicionActual), style: const TextStyle(color: Colors.grey)),
                    Text(_formatDuration(duracionTotal), style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(iconSize: 40, icon: const Icon(Icons.replay_10, color: Colors.white), onPressed: () => _saltarSegundos(-10)),
                  const SizedBox(width: 20),
                  IconButton(
                    iconSize: 64,
                    icon: Icon(sonando ? Icons.pause_circle_filled : Icons.play_circle_filled, color: ColoresApp.acento),
                    onPressed: _playPausa,
                  ),
                  const SizedBox(width: 20),
                  IconButton(iconSize: 40, icon: const Icon(Icons.forward_10, color: Colors.white), onPressed: () => _saltarSegundos(10)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipVelocidadAudio(double val, String label) {
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

// ---------------------------------------------------------
// REPRODUCTOR DE VIDEO
// ---------------------------------------------------------
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
                                        ? const Icon(Icons.play_circle_fill, size: 70, color: Colors.white70)
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const Text('No se pudo cargar el video.', style: TextStyle(color: Colors.white70)),
              ),
            ),
            if (listo)
              Container(
                color: ColoresApp.fondoPrincipal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    Slider(
                      value: posicion.inSeconds.toDouble().clamp(0.0, duracion.inSeconds > 0 ? duracion.inSeconds.toDouble() : 1.0),
                      max: duracion.inSeconds > 0 ? duracion.inSeconds.toDouble() : 1.0,
                      activeColor: ColoresApp.acento,
                      onChanged: (val) => _controller!.seekTo(Duration(seconds: val.toInt())),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(posicion), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        Text(_formatDuration(duracion), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(icon: const Icon(Icons.replay_10, color: Colors.white), onPressed: () => _saltarSegundos(-10)),
                        IconButton(
                          iconSize: 50,
                          icon: Icon(_controller!.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: ColoresApp.acento),
                          onPressed: () {
                            setState(() {
                              _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
                            });
                          },
                        ),
                        IconButton(icon: const Icon(Icons.forward_10, color: Colors.white), onPressed: () => _saltarSegundos(10)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Velocidad:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(width: 8),
                        _chipVelocidadVideo(1.0, '1.0x'),
                        _chipVelocidadVideo(1.25, '1.25x'),
                        _chipVelocidadVideo(1.5, '1.5x'),
                        _chipVelocidadVideo(2.0, '2.0x'),
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

  Widget _chipVelocidadVideo(double val, String label) {
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