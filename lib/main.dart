import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
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
      home: const PantallaPrincipalMiLector(),
    );
  }
}

// ---------------------------------------------------------
// MODELO DE MARCADORES MÚLTIPLES
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

// ---------------------------------------------------------
// MODELO DE LIBROS Y AUDIOLIBROS EXPANDIDO (CON SOPORTE EPUB)
// ---------------------------------------------------------
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
  String notasPersonales;
  List<Marcador> marcadores;

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
    this.notasPersonales = '',
    List<Marcador>? marcadores,
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
        'notasPersonales': notasPersonales,
        'marcadores': marcadores.map((m) => m.toMap()).toList(),
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
        notasPersonales: map['notasPersonales'] ?? '',
        marcadores: (map['marcadores'] as List<dynamic>?)
                ?.map((m) => Marcador.fromMap(m))
                .toList() ??
            [],
      );
}

// ---------------------------------------------------------
// PANTALLA PRINCIPAL DE BIBLIOTECA
// ---------------------------------------------------------
class PantallaPrincipalMiLector extends StatefulWidget {
  const PantallaPrincipalMiLector({super.key});

  @override
  State<PantallaPrincipalMiLector> createState() => _PantallaPrincipalMiLectorState();
}

class _PantallaPrincipalMiLectorState extends State<PantallaPrincipalMiLector> {
  List<Libro> libros = [];
  List<Libro> librosMostrados = [];
  List<String> misCategorias = ['Todas', 'General'];
  String categoriaSeleccionada = 'Todas';
  String seccionActual = 'Libros y documentos';
  final TextEditingController _searchController = TextEditingController();
  bool buscando = false;

  bool modoOscuroGlobal = true;
  double nivelBrilloGlobal = 1.0;
  bool filtroLuzAzulGlobal = false;
  bool modoSepiaGlobal = false;
  double intensidadFiltroGlobal = 0.2;
  double velocidadVozGlobal = 1.0;
  bool sonidoActivadoGlobal = true;
  String nombreSonidoActualGlobal = 'Local Predeterminado';
  String? rutaSonidoPersonalizadoGlobal;

  @override
  void initState() {
    super.initState();
    _cargarBibliotecaYAjustes();
    _searchController.addListener(_aplicarFiltroSeccion);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarBibliotecaYAjustes() async {
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      modoOscuroGlobal = prefs.getBool('modo_oscuro_global') ?? true;
      nivelBrilloGlobal = prefs.getDouble('nivel_brillo_global') ?? 1.0;
      filtroLuzAzulGlobal = prefs.getBool('filtro_luz_azul_global') ?? false;
      modoSepiaGlobal = prefs.getBool('modo_sepia_global') ?? false;
      intensidadFiltroGlobal = prefs.getDouble('intensidad_filtro_global') ?? 0.2;
      velocidadVozGlobal = prefs.getDouble('velocidad_voz_global') ?? 1.0;
      sonidoActivadoGlobal = prefs.getBool('sonido_activado_global') ?? true;
      nombreSonidoActualGlobal = prefs.getString('nombre_sonido_global') ?? 'Local Predeterminado';
      rutaSonidoPersonalizadoGlobal = prefs.getString('ruta_sonido_custom_global');
    });

    final List<String>? catGuardadas = prefs.getStringList('mis_categorias_app');
    if (catGuardadas != null) misCategorias = catGuardadas;

    final String? jsonString = prefs.getString('mis_libros_app');
    if (jsonString != null) {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      setState(() {
        libros = jsonList.map((i) => Libro.fromMap(i)).toList();
        _aplicarFiltroSeccion();
      });
    }
  }

  Future<void> _guardarAjustesGlobales() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('modo_oscuro_global', modoOscuroGlobal);
    await prefs.setDouble('nivel_brillo_global', nivelBrilloGlobal);
    await prefs.setBool('filtro_luz_azul_global', filtroLuzAzulGlobal);
    await prefs.setBool('modo_sepia_global', modoSepiaGlobal);
    await prefs.setDouble('intensidad_filtro_global', intensidadFiltroGlobal);
    await prefs.setDouble('velocidad_voz_global', velocidadVozGlobal);
    await prefs.setBool('sonido_activado_global', sonidoActivadoGlobal);
    await prefs.setString('nombre_sonido_global', nombreSonidoActualGlobal);
    if (rutaSonidoPersonalizadoGlobal != null) {
      await prefs.setString('ruta_sonido_custom_global', rutaSonidoPersonalizadoGlobal!);
    } else {
      await prefs.remove('ruta_sonido_custom_global');
    }
  }

  Future<void> _guardarBiblioteca() async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonList = jsonEncode(libros.map((l) => l.toMap()).toList());
    await prefs.setString('mis_libros_app', jsonList);
    await prefs.setStringList('mis_categorias_app', misCategorias);
  }

  void _aplicarFiltroSeccion() {
    List<Libro> temp = List.from(libros);

    if (seccionActual == 'Audiolibros 🎧') {
      temp = temp.where((l) => l.esAudiolibro).toList();
    } else if (seccionActual == 'Favoritos') {
      temp = temp.where((l) => l.esFavorito).toList();
    } else if (seccionActual == 'Por leer') {
      temp = temp.where((l) => l.porLeer && !l.leido).toList();
    } else if (seccionActual == 'Leídos') {
      temp = temp.where((l) => l.leido).toList();
    } else if (seccionActual == 'Leyendo ahora') {
      temp = temp.where((l) => l.ultimaPagina > 1 && !l.leido).toList();
    } else if (seccionActual == 'Libros y documentos') {
      temp = temp.where((l) => !l.esAudiolibro).toList();
    }

    if (categoriaSeleccionada != 'Todas' && seccionActual != 'Audiolibros 🎧' && seccionActual != 'Estadísticas 📊') {
      temp = temp.where((l) => l.categoria == categoriaSeleccionada).toList();
    }

    final q = _searchController.text.toLowerCase();
    if (q.isNotEmpty) {
      temp = temp.where((l) => l.titulo.toLowerCase().contains(q)).toList();
    }

    setState(() {
      librosMostrados = temp;
    });
  }

  Future<void> _buscarEnWeb(String consulta) async {
    if (consulta.trim().isEmpty) return;
    final Uri url = Uri.parse('https://www.google.com/search?q=${Uri.encodeComponent(consulta)}+filetype:pdf');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el navegador web')),
        );
      }
    }
  }

  void _crearNuevaCategoria() {
    TextEditingController catController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16333D),
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
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

  void _abrirNotasDelLibro(Libro libro) {
    TextEditingController notasController = TextEditingController(text: libro.notasPersonales);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16333D),
        title: Row(
          children: [
            const Icon(Icons.note_alt, color: Color(0xFF38BDF8)),
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
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
          backgroundColor: const Color(0xFF16333D),
          title: Text('Categoría para: ${libro.titulo}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: opciones.map((cat) {
              final bool seleccionada = libro.categoria == cat;
              return ListTile(
                title: Text(cat, style: TextStyle(color: seleccionada ? const Color(0xFF38BDF8) : Colors.white)),
                trailing: seleccionada ? const Icon(Icons.check, color: Color(0xFF38BDF8)) : null,
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

  Future<void> _agregarLibroOAudiolibro() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'mp3', 'm4a', 'wav', 'aac', 'epub'],
        allowMultiple: false,
      );

      if (result == null || result.files.single.path == null) return;

      String pathOrigen = result.files.single.path!;
      String nombre = result.files.single.name;
      String ext = nombre.toLowerCase();

      bool esAudio = ext.endsWith('.mp3') || ext.endsWith('.m4a') || ext.endsWith('.wav') || ext.endsWith('.aac');
      bool esPdf = ext.endsWith('.pdf');
      bool esEpub = ext.endsWith('.epub');

      if (!esPdf && !esAudio && !esEpub) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Por favor selecciona un archivo PDF, EPUB o de Audio (MP3/M4A).')),
          );
        }
        return;
      }

      Directory appDir = await getApplicationDocumentsDirectory();
      String nuevaRuta = '${appDir.path}/$nombre';
      await File(pathOrigen).copy(nuevaRuta);

      String catInicial = (categoriaSeleccionada == 'Todas') ? 'General' : categoriaSeleccionada;

      final nuevoLibro = Libro(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        titulo: nombre.replaceAll(RegExp(r'\.(pdf|mp3|m4a|wav|aac|epub)$', caseSensitive: false), ''),
        rutaLocal: nuevaRuta,
        categoria: catInicial,
        esAudiolibro: esAudio,
        esEpub: esEpub,
      );

      setState(() {
        libros.add(nuevoLibro);
        if (esAudio) {
          seccionActual = 'Audiolibros 🎧';
        } else {
          seccionActual = 'Libros y documentos';
        }
        _aplicarFiltroSeccion();
      });

      await _guardarBiblioteca();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al abrir archivo: $e')));
      }
    }
  }

  Future<void> _abrirPixabayEfectos() async {
    final Uri url = Uri.parse('https://pixabay.com/es/sound-effects/search/pass/');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir Pixabay')));
      }
    }
  }

  void _mostrarConfiguracionGeneral() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16333D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: 580,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Configuración General y Protección Visual', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const Divider(color: Colors.white24),
                    
                    SwitchListTile(
                      title: const Text('Modo Oscuro / Claro', style: TextStyle(color: Colors.white, fontSize: 13)),
                      secondary: Icon(modoOscuroGlobal ? Icons.dark_mode : Icons.light_mode, color: const Color(0xFF38BDF8)),
                      activeColor: const Color(0xFF38BDF8),
                      value: modoOscuroGlobal,
                      onChanged: (val) {
                        setModalState(() => modoOscuroGlobal = val);
                        setState(() => modoOscuroGlobal = val);
                        _guardarAjustesGlobales();
                      },
                    ),

                    SwitchListTile(
                      title: const Text('Filtro de Luz Azul (Antifatiga Nocturna)', style: TextStyle(color: Colors.white, fontSize: 13)),
                      subtitle: const Text('Tinte cálido para lectura nocturna prolongada', style: TextStyle(color: Colors.grey, fontSize: 11)),
                      secondary: const Icon(Icons.shield_rounded, color: Colors.amberAccent),
                      activeColor: const Color(0xFF38BDF8),
                      value: filtroLuzAzulGlobal,
                      onChanged: (val) {
                        setModalState(() => filtroLuzAzulGlobal = val);
                        setState(() => filtroLuzAzulGlobal = val);
                        _guardarAjustesGlobales();
                      },
                    ),

                    SwitchListTile(
                      title: const Text('Modo Sepia / Papel Antiguo', style: TextStyle(color: Colors.white, fontSize: 13)),
                      subtitle: const Text('Fondo estilo pergamino suave para la vista', style: TextStyle(color: Colors.grey, fontSize: 11)),
                      secondary: const Icon(Icons.menu_book, color: Colors.orangeAccent),
                      activeColor: const Color(0xFF0284C7),
                      value: modoSepiaGlobal,
                      onChanged: (val) {
                        setModalState(() => modoSepiaGlobal = val);
                        setState(() => modoSepiaGlobal = val);
                        _guardarAjustesGlobales();
                      },
                    ),

                    if (filtroLuzAzulGlobal || modoSepiaGlobal) ...[
                      const Text('Intensidad del filtro de protección', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Slider(
                        value: intensidadFiltroGlobal.clamp(0.05, 0.5),
                        min: 0.05,
                        max: 0.5,
                        activeColor: Colors.amber,
                        onChanged: (v) {
                          setModalState(() => intensidadFiltroGlobal = v);
                          setState(() => intensidadFiltroGlobal = v);
                          _guardarAjustesGlobales();
                        },
                      ),
                    ],

                    const Text('Brillo de pantalla predeterminado', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Row(
                      children: [
                        const Icon(Icons.brightness_5, color: Colors.grey, size: 18),
                        Expanded(
                          child: Slider(
                            value: nivelBrilloGlobal.clamp(0.1, 1.0),
                            min: 0.1,
                            max: 1.0,
                            activeColor: const Color(0xFF38BDF8),
                            onChanged: (v) {
                              setModalState(() => nivelBrilloGlobal = v);
                              setState(() => nivelBrilloGlobal = v);
                              _guardarAjustesGlobales();
                            },
                          ),
                        ),
                        const Icon(Icons.brightness_7, color: Colors.white, size: 18),
                      ],
                    ),

                    const Text('Velocidad de Lectura en Voz Alta (TTS)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _chipVelocidadGlobal(0.5, '0.5x', setModalState),
                        _chipVelocidadGlobal(1.0, '1.0x', setModalState),
                        _chipVelocidadGlobal(1.5, '1.5x', setModalState),
                        _chipVelocidadGlobal(2.0, '2.0x', setModalState),
                      ],
                    ),
                    const Divider(color: Colors.white24),

                    SwitchListTile(
                      title: const Text('Efecto de sonido al pasar página', style: TextStyle(color: Colors.white, fontSize: 13)),
                      activeColor: const Color(0xFF38BDF8),
                      value: sonidoActivadoGlobal,
                      onChanged: (val) {
                        setModalState(() => sonidoActivadoGlobal = val);
                        setState(() => sonidoActivadoGlobal = val);
                        _guardarAjustesGlobales();
                      },
                    ),

                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                      icon: const Icon(Icons.cloud_download, color: Colors.white, size: 16),
                      label: const Text('Descargar efectos de sonido en Pixabay...', style: TextStyle(color: Colors.white, fontSize: 12)),
                      onPressed: _abrirPixabayEfectos,
                    ),
                    const SizedBox(height: 6),

                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF38BDF8))),
                      icon: const Icon(Icons.folder_open, color: Color(0xFF38BDF8), size: 16),
                      label: Text('Audio personalizado ($nombreSonidoActualGlobal)', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11)),
                      onPressed: () async {
                        FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);
                        if (result != null && result.files.single.path != null) {
                          String path = result.files.single.path!;
                          String name = result.files.single.name;
                          setModalState(() {
                            rutaSonidoPersonalizadoGlobal = path;
                            nombreSonidoActualGlobal = name;
                          });
                          setState(() {});
                          _guardarAjustesGlobales();
                        }
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

  Widget _chipVelocidadGlobal(double val, String label, StateSetter setModalState) {
    bool seleccionado = velocidadVozGlobal == val;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 11, color: seleccionado ? Colors.white : Colors.grey)),
        selected: seleccionado,
        selectedColor: const Color(0xFF0284C7),
        backgroundColor: const Color(0xFF0E2229),
        onSelected: (bool selected) {
          setModalState(() => velocidadVozGlobal = val);
          setState(() => velocidadVozGlobal = val);
          _guardarAjustesGlobales();
        },
      ),
    );
  }

  void _mostrarExplicacionTraduccionCompleta(Libro libro) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16333D),
        title: Row(
          children: const [
            Icon(Icons.g_translate, color: Color(0xFF38BDF8)),
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
            const SelectableText('https://translate.google.com/?op=docs', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('2. Sube tu PDF y tradúcelo.'),
            const SizedBox(height: 8),
            const Text('3. Añade el nuevo PDF con el botón "Agregar libro".'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido', style: TextStyle(color: Color(0xFF38BDF8)))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Libro> librosEnProgreso = libros.where((l) => l.ultimaPagina > 1 && !l.leido && !l.esAudiolibro).toList();

    return Scaffold(
      appBar: AppBar(
        title: buscando
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Buscar libro local o presiona web...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey),
                ),
              )
            : Text(seccionActual, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
        actions: [
          if (buscando && _searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.language, color: Color(0xFF38BDF8)),
              tooltip: 'Buscar en Web',
              onPressed: () => _buscarEnWeb(_searchController.text),
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

      drawer: Drawer(
        backgroundColor: const Color(0xFF0C1D23),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF16333D)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_add_rounded, size: 45, color: Color(0xFF38BDF8)),
                  SizedBox(height: 10),
                  Text('Mi Lector Pro', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('Tu biblioteca personalizada', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            _itemDrawer(Icons.headphones_rounded, 'Audiolibros 🎧'),
            _itemDrawer(Icons.bar_chart, 'Estadísticas 📊'),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.grey),
              title: const Text('Configuración', style: TextStyle(color: Colors.white70)),
              onTap: () {
                Navigator.pop(context);
                _mostrarConfiguracionGeneral();
              },
            ),
            _itemDrawer(Icons.cloud_download_outlined, 'Descargar Libros Gratis'),
            const Divider(color: Colors.white24),
            _itemDrawer(Icons.play_circle_outline, 'Leyendo ahora'),
            _itemDrawer(Icons.menu_book, 'Libros y documentos'),
            _itemDrawer(Icons.star_border, 'Favoritos'),
            _itemDrawer(Icons.access_time, 'Por leer'),
            _itemDrawer(Icons.done_all, 'Leídos'),
          ],
        ),
      ),

      body: Column(
        children: [
          if (seccionActual == 'Libros y documentos' && categoriaSeleccionada == 'Todas' && librosEnProgreso.isNotEmpty && !buscando)
            Container(
              height: 110,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('Continuar Leyendo ▶', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold)),
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
                            onTap: () async {
                              if (libro.esEpub) {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PantallaLectorEpub(
                                      libro: libro,
                                      modoOscuro: modoOscuroGlobal,
                                      modoSepia: modoSepiaGlobal,
                                      brillo: nivelBrilloGlobal,
                                      velocidadVoz: velocidadVozGlobal,
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
                                    ),
                                  ),
                                );
                              }
                              _guardarBiblioteca();
                              _aplicarFiltroSeccion();
                            },
                            child: Card(
                              color: const Color(0xFF16333D),
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

          if (seccionActual != 'Descargar Libros Gratis' && seccionActual != 'Audiolibros 🎧' && seccionActual != 'Estadísticas 📊')
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
                          child: ChoiceChip(
                            label: Text(cat),
                            selected: activa,
                            selectedColor: const Color(0xFF0284C7),
                            backgroundColor: const Color(0xFF16333D),
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
                        );
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Color(0xFF38BDF8)),
                    tooltip: 'Nueva categoría',
                    onPressed: _crearNuevaCategoria,
                  ),
                ],
              ),
            ),

          Expanded(
            child: seccionActual == 'Descargar Libros Gratis'
                ? const PantallaBibliotecasDirectas()
                : seccionActual == 'Estadísticas 📊'
                    ? PantallaEstadisticas(libros: libros)
                    : librosMostrados.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(seccionActual == 'Audiolibros 🎧' ? Icons.headphones : Icons.library_books_outlined, size: 80, color: Colors.white24),
                                const SizedBox(height: 16),
                                Text('No hay contenidos en "$seccionActual"', style: const TextStyle(color: Colors.grey, fontSize: 16)),
                              ],
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(12),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 0.58,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: librosMostrados.length,
                            itemBuilder: (context, index) {
                              final libro = librosMostrados[index];
                              return Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16333D),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () async {
                                          if (libro.esAudiolibro) {
                                            await Navigator.push(context, MaterialPageRoute(builder: (context) => PantallaReproductorAudiolibro(libro: libro)));
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
                                                ),
                                              ),
                                            );
                                          }
                                          _guardarBiblioteca();
                                          _aplicarFiltroSeccion();
                                        },
                                        child: ClipRRect(
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                                          child: libro.esAudiolibro
                                              ? Container(
                                                  color: const Color(0xFF1E3A8A),
                                                  child: const Center(child: Icon(Icons.headphones_rounded, size: 50, color: Color(0xFF38BDF8))),
                                                )
                                              : libro.esEpub
                                                  ? Container(
                                                      color: const Color(0xFF1F2937),
                                                      child: const Center(child: Icon(Icons.menu_book_rounded, size: 50, color: Color(0xFF38BDF8))),
                                                    )
                                                  : PortadaPdfWidget(rutaPdf: libro.rutaLocal, titulo: libro.titulo),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(6.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(libro.titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 2),
                                          Text(
                                            libro.esAudiolibro ? 'Audiolibro MP3' : (libro.esEpub ? '${libro.categoria} • EPUB' : '${libro.categoria} • Pág. ${libro.ultimaPagina}'),
                                            style: const TextStyle(color: Colors.grey, fontSize: 9),
                                          ),
                                          const SizedBox(height: 4),

                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              IconButton(
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                icon: Icon(libro.esFavorito ? Icons.star : Icons.star_border, color: libro.esFavorito ? Colors.amber : Colors.grey, size: 18),
                                                onPressed: () {
                                                  setState(() => libro.esFavorito = !libro.esFavorito);
                                                  _guardarBiblioteca();
                                                  _aplicarFiltroSeccion();
                                                },
                                              ),
                                              IconButton(
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                icon: Icon(Icons.note_alt, color: libro.notasPersonales.isNotEmpty ? const Color(0xFF38BDF8) : Colors.grey, size: 18),
                                                tooltip: 'Notas',
                                                onPressed: () => _abrirNotasDelLibro(libro),
                                              ),
                                              PopupMenuButton<String>(
                                                padding: EdgeInsets.zero,
                                                icon: const Icon(Icons.more_vert, color: Colors.grey, size: 18),
                                                onSelected: (val) {
                                                  if (val == 'category') {
                                                    _cambiarCategoriaLibro(libro);
                                                  } else if (val == 'delete') {
                                                    setState(() => libros.removeWhere((l) => l.id == libro.id));
                                                    _guardarBiblioteca();
                                                    _aplicarFiltroSeccion();
                                                  } else if (val == 'translate') {
                                                    _mostrarExplicacionTraduccionCompleta(libro);
                                                  }
                                                },
                                                itemBuilder: (context) => [
                                                  if (!libro.esAudiolibro) ...[
                                                    const PopupMenuItem(
                                                      value: 'category',
                                                      child: Row(children: [Icon(Icons.folder_outlined, size: 18, color: Color(0xFF38BDF8)), SizedBox(width: 8), Text('Cambiar categoría')]),
                                                    ),
                                                    if (!libro.esEpub)
                                                      const PopupMenuItem(
                                                        value: 'translate',
                                                        child: Row(children: [Icon(Icons.translate, size: 18, color: Color(0xFF38BDF8)), SizedBox(width: 8), Text('Traducir PDF')]),
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

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0284C7),
        onPressed: _agregarLibroOAudiolibro,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Agregar libro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _itemDrawer(IconData icon, String titulo) {
    final bool seleccionado = seccionActual == titulo;
    return ListTile(
      leading: Icon(icon, color: seleccionado ? const Color(0xFF38BDF8) : Colors.grey),
      title: Text(
        titulo,
        style: TextStyle(
          color: seleccionado ? const Color(0xFF38BDF8) : Colors.white70,
          fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () {
        setState(() {
          seccionActual = titulo;
          _aplicarFiltroSeccion();
        });
        Navigator.pop(context);
      },
    );
  }
}

// ---------------------------------------------------------
// PANTALLA DE ESTADÍSTICAS Y HÁBITOS DE LECTURA
// ---------------------------------------------------------
class PantallaEstadisticas extends StatelessWidget {
  final List<Libro> libros;

  const PantallaEstadisticas({super.key, required this.libros});

  @override
  Widget build(BuildContext context) {
    int totalPdfs = libros.where((l) => !l.esAudiolibro && !l.esEpub).length;
    int totalEpub = libros.where((l) => l.esEpub).length;
    int totalAudio = libros.where((l) => l.esAudiolibro).length;
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
            _cardStat('En Lectura', '$enProgreso', Icons.menu_book, const Color(0xFF38BDF8)),
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
            _cardStat('Total', '${libros.length}', Icons.library_books, Colors.tealAccent),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          color: const Color(0xFF16333D),
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
        decoration: BoxDecoration(color: const Color(0xFF16333D), borderRadius: BorderRadius.circular(10)),
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
// BIBLIOTECAS WEB DE DESCARGA DIRECTA (DENTRO DE LA APP)
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
        const Text('Bibliotecas y Repositorios Gratuitos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 6),
        const Text('Toca cualquier biblioteca para buscar y descargar tus libros directamente dentro de la aplicación.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 16),
        ...bibliotecas.map((b) => Card(
              color: const Color(0xFF16333D),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Text(b['icon']!, style: const TextStyle(fontSize: 32)),
                title: Text(b['nombre']!, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                subtitle: Text(b['desc']!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF38BDF8)),
                onTap: () => _abrirSitioEnApp(context, b['nombre']!, b['url']!),
              ),
            )),
      ],
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
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Container(
        color: const Color(0xFF244A57),
        child: const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8))),
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
// LECTOR PDF CON WIKIPEDIA, TRADUCTOR Y FILTROS
// ---------------------------------------------------------
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
  });

  @override
  State<PantallaLectorPDF> createState() => _PantallaLectorPDFState();
}

class _PantallaLectorPDFState extends State<PantallaLectorPDF> {
  int totalPaginas = 0;
  int paginaActual = 0;
  PDFViewController? _pdfViewController;
  late bool modoOscuro;
  late double nivelBrillo;
  late bool filtroLuzAzul;
  late bool modoSepia;
  late double intensidadFiltro;
  bool cargandoDocumento = true;
  late double velocidadVoz;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();

  late bool sonidoActivado;
  late String nombreSonidoActual;
  late String? rutaSonidoPersonalizado;

  @override
  void initState() {
    super.initState();
    modoOscuro = widget.modoOscuroInicial;
    nivelBrillo = widget.brilloInicial;
    filtroLuzAzul = widget.filtroLuzAzulInicial;
    modoSepia = widget.modoSepiaInicial;
    intensidadFiltro = widget.intensidadFiltroInicial;
    velocidadVoz = widget.velocidadInicial;
    sonidoActivado = widget.sonidoActivadoInicial;
    nombreSonidoActual = widget.nombreSonidoInicial;
    rutaSonidoPersonalizado = widget.rutaSonidoInicial;

    _initTts();
  }

  void _initTts() async {
    await _flutterTts.setLanguage("es-ES");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(velocidadVoz);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _reproducirSonidoPagina() async {
    if (!sonidoActivado) return;
    try {
      if (rutaSonidoPersonalizado != null && File(rutaSonidoPersonalizado!).existsSync()) {
        await _audioPlayer.stop();
        await _audioPlayer.play(DeviceFileSource(rutaSonidoPersonalizado!));
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.play(AssetSource('sounds/page_turn.mp3'));
      }
    } catch (_) {}
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
    final double porcentajeLectura = totalPaginas > 0 ? ((paginaActual + 1) / totalPaginas) * 100 : 0.0;

    return Scaffold(
      backgroundColor: modoSepia
          ? const Color(0xFFF4ECD8)
          : (modoOscuro ? const Color(0xFF121212) : const Color(0xFFF5F5F5)),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E2229),
        title: Text(widget.libro.titulo, style: const TextStyle(fontSize: 15)),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${paginaActual + 1} / $totalPaginas', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('${porcentajeLectura.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 9, color: Color(0xFF38BDF8))),
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
            child: PDFView(
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
              onViewCreated: (PDFViewController controller) => _pdfViewController = controller,
              onPageChanged: (int? page, int? total) {
                if (page != null && page != paginaActual) {
                  _reproducirSonidoPagina();
                  setState(() {
                    paginaActual = page;
                    widget.libro.ultimaPagina = page + 1;
                  });
                }
              },
            ),
          ),
          if (filtroLuzAzul)
            IgnorePointer(
              child: Container(
                color: Colors.amber.withOpacity(intensidadFiltro.clamp(0.05, 0.5)),
              ),
            ),
          if (cargandoDocumento)
            Container(
              color: const Color(0xFF0E2229),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF38BDF8)),
                    SizedBox(height: 16),
                    Text('Cargando libro...', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        color: const Color(0xFF0E2229),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF38BDF8))),
              icon: const Icon(Icons.search, size: 16, color: Color(0xFF38BDF8)),
              label: const Text('Wikipedia / Diccionario', style: TextStyle(fontSize: 11, color: Color(0xFF38BDF8))),
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
    );
  }
}

// ---------------------------------------------------------
// PANTALLA LECTOR DE EPUB FLUIDO (CON TTS Y WIKIPEDIA INTERNA)
// ---------------------------------------------------------
class PantallaLectorEpub extends StatefulWidget {
  final Libro libro;
  final bool modoOscuro;
  final bool modoSepia;
  final double brillo;
  final double velocidadVoz;

  const PantallaLectorEpub({
    super.key,
    required this.libro,
    required this.modoOscuro,
    required this.modoSepia,
    required this.brillo,
    required this.velocidadVoz,
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

  @override
  void initState() {
    super.initState();
    _cargarEpub();
    _initTts();
  }

  void _initTts() async {
    await _flutterTts.setLanguage("es-ES");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(widget.velocidadVoz);

    _flutterTts.setCompletionHandler(() {
      setState(() => estaLeyendoVoz = false);
    });
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

  Future<void> _toggleLecturaVoz(String textoCompleto) async {
    if (estaLeyendoVoz) {
      await _flutterTts.stop();
      setState(() => estaLeyendoVoz = false);
    } else {
      if (textoCompleto.trim().isEmpty) return;
      String textoLimpio = textoCompleto.replaceAll(RegExp(r'<[^>]*>'), '');
      setState(() => estaLeyendoVoz = true);
      await _flutterTts.speak(textoLimpio);
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

    String textoCapitulosTotal = capitulos.map((c) => c.HtmlContent ?? '').join(' ');

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E2229),
        title: Text(widget.libro.titulo, style: const TextStyle(fontSize: 14)),
        actions: [
          IconButton(
            icon: Icon(estaLeyendoVoz ? Icons.stop_circle : Icons.volume_up, color: const Color(0xFF38BDF8)),
            tooltip: 'Leer capítulo en voz alta',
            onPressed: () => _toggleLecturaVoz(textoCapitulosTotal),
          ),
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
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          : capitulos.isEmpty
              ? const Center(child: Text('No se pudieron leer los capítulos de este EPUB.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: capitulos.length,
                  itemBuilder: (context, index) {
                    final chapter = capitulos[index];
                    String tituloCapitulo = chapter.Title ?? 'Capítulo ${index + 1}';
                    String contenidoHtml = chapter.HtmlContent ?? '';

                    return ExpansionTile(
                      title: Text(tituloCapitulo, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
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
                                style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF38BDF8))),
                                icon: const Icon(Icons.search, size: 16, color: Color(0xFF38BDF8)),
                                label: const Text('Wikipedia / Diccionario', style: TextStyle(fontSize: 11, color: Color(0xFF38BDF8))),
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
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() => cargando = false);
          },
          onNavigationRequest: (NavigationRequest request) {
            String urlLower = request.url.toLowerCase();
            if (urlLower.endsWith('.pdf') || urlLower.endsWith('.epub') || urlLower.contains('download') || urlLower.contains('descargar')) {
              launchUrl(Uri.parse(request.url), mode: LaunchMode.externalApplication);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Iniciando descarga externa del libro... Añádelo a la app al finalizar.')),
              );
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E2229),
        title: Text(widget.titulo, style: const TextStyle(fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            if (await controller.canGoBack()) {
              controller.goBack();
            } else {
              Navigator.pop(context);
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
              color: const Color(0xFF0E2229),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
              ),
            ),
        ],
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

  Timer? _timerApagado;
  int minutosRestantesTimer = 0;
  double velocidadAudio = 1.0;

  @override
  void initState() {
    super.initState();
    _prepararAudio();
  }

  void _prepararAudio() async {
    _player.onDurationChanged.listen((d) => setState(() => duracionTotal = d));
    _player.onPositionChanged.listen((p) => setState(() => posicionActual = p));
    _player.onPlayerComplete.listen((_) => setState(() => sonando = false));

    await _player.setSource(DeviceFileSource(widget.libro.rutaLocal));
  }

  @override
  void dispose() {
    _timerApagado?.cancel();
    _player.dispose();
    super.dispose();
  }

  void _playPausa() async {
    if (sonando) {
      await _player.pause();
      setState(() => sonando = false);
    } else {
      await _player.setPlaybackRate(velocidadAudio);
      await _player.play(DeviceFileSource(widget.libro.rutaLocal));
      setState(() => sonando = true);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reproductor de Audiolibro'),
        backgroundColor: const Color(0xFF0E2229),
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
                color: const Color(0xFF16333D),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
              ),
              child: const Icon(Icons.headphones_rounded, size: 100, color: Color(0xFF38BDF8)),
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
              activeColor: const Color(0xFF38BDF8),
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
                  icon: Icon(sonando ? Icons.pause_circle_filled : Icons.play_circle_filled, color: const Color(0xFF38BDF8)),
                  onPressed: _playPausa,
                ),
                const SizedBox(width: 20),
                IconButton(iconSize: 40, icon: const Icon(Icons.forward_10, color: Colors.white), onPressed: () => _saltarSegundos(10)),
              ],
            )
          ],
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
        selectedColor: const Color(0xFF0284C7),
        backgroundColor: const Color(0xFF16333D),
        onSelected: (bool selected) => _cambiarVelocidad(val),
      ),
    );
  }
}