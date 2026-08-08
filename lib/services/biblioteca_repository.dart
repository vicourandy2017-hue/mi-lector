import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/libro.dart';
import '../models/pista_musica.dart';
import '../models/ajustes_app.dart';

class BibliotecaRepository {
  // ── Claves de almacenamiento ─────────────────────────────────────────────
  static const _kLibros            = 'mis_libros_app';
  static const _kCategorias        = 'mis_categorias_app';
  static const _kPistas            = 'mis_pistas_musica_app';
  static const _kTipoFondo         = 'tipo_fondo_app';
  static const _kRutaFondo         = 'ruta_fondo_app';
  static const _kColorSolidoId     = 'color_solido_id_app';
  static const _kModoOscuro        = 'modo_oscuro_global';
  static const _kNivelBrillo       = 'nivel_brillo_global';
  static const _kFiltroLuzAzul     = 'filtro_luz_azul_global';
  static const _kModoSepia         = 'modo_sepia_global';
  static const _kVolumenEfecto     = 'volumen_efecto_global';
  static const _kIntensidadFiltro  = 'intensidad_filtro_global';
  static const _kVelocidadVoz      = 'velocidad_voz_global';
  static const _kSonidoActivado    = 'sonido_activado_global';
  static const _kNombreSonido      = 'nombre_sonido_global';
  static const _kRutaSonidoCustom  = 'ruta_sonido_custom_global';
  static const _kOrdenBiblioteca   = 'orden_biblioteca_global';
  static const _kIdioma            = 'idioma_app';

  // ── Libros ───────────────────────────────────────────────────────────────
  Future<List<Libro>> cargarLibros() async {
    final prefs = await SharedPreferences.getInstance();
    final json  = prefs.getString(_kLibros);
    if (json == null) return [];
    try {
      final lista = jsonDecode(json) as List<dynamic>;
      return lista.map((i) => Libro.fromMap(i as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> guardarLibros(List<Libro> libros) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLibros, jsonEncode(libros.map((l) => l.toMap()).toList()));
  }

  // ── Categorías ───────────────────────────────────────────────────────────
  Future<List<String>> cargarCategorias() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kCategorias) ?? ['Todas', 'General'];
  }

  Future<void> guardarCategorias(List<String> categorias) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kCategorias, categorias);
  }

  // ── Pistas de música ─────────────────────────────────────────────────────
  Future<List<PistaMusica>> cargarPistasMusica() async {
    final prefs = await SharedPreferences.getInstance();
    final json  = prefs.getString(_kPistas);
    if (json == null) return [];
    try {
      final lista = jsonDecode(json) as List<dynamic>;
      return lista.map((i) => PistaMusica.fromMap(i as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> guardarPistasMusica(List<PistaMusica> pistas) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPistas, jsonEncode(pistas.map((p) => p.toMap()).toList()));
  }

  // ── Ajustes ──────────────────────────────────────────────────────────────
  Future<AjustesApp> cargarAjustes({required bool esOscuroSistemaPorDefecto}) async {
    final prefs = await SharedPreferences.getInstance();
    return AjustesApp(
      tipoFondo             : prefs.getString(_kTipoFondo) ?? 'defecto',
      rutaFondoSeleccionado : prefs.getString(_kRutaFondo) ?? 'assets/images/fondo1.jpg',
      colorSolidoId         : prefs.getString(_kColorSolidoId),
      modoOscuro            : prefs.getBool(_kModoOscuro) ?? esOscuroSistemaPorDefecto,
      nivelBrillo           : prefs.getDouble(_kNivelBrillo) ?? 1.0,
      filtroLuzAzul         : prefs.getBool(_kFiltroLuzAzul) ?? false,
      modoSepia             : prefs.getBool(_kModoSepia) ?? false,
      volumenEfecto         : prefs.getDouble(_kVolumenEfecto) ?? 0.8,
      intensidadFiltro      : prefs.getDouble(_kIntensidadFiltro) ?? 0.2,
      velocidadVoz          : prefs.getDouble(_kVelocidadVoz) ?? 1.0,
      sonidoActivado        : prefs.getBool(_kSonidoActivado) ?? true,
      nombreSonidoActual    : prefs.getString(_kNombreSonido) ?? 'Local Predeterminado',
      rutaSonidoPersonalizado: prefs.getString(_kRutaSonidoCustom),
      ordenBiblioteca       : prefs.getString(_kOrdenBiblioteca) ?? 'Recientes',
      idioma                : prefs.getString(_kIdioma) ?? 'Español',
    );
  }

  Future<void> guardarAjustes(AjustesApp a) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTipoFondo, a.tipoFondo);
    await prefs.setString(_kRutaFondo, a.rutaFondoSeleccionado);
    if (a.colorSolidoId != null) {
      await prefs.setString(_kColorSolidoId, a.colorSolidoId!);
    } else {
      await prefs.remove(_kColorSolidoId);
    }
    await prefs.setBool(_kModoOscuro, a.modoOscuro);
    await prefs.setDouble(_kNivelBrillo, a.nivelBrillo);
    await prefs.setBool(_kFiltroLuzAzul, a.filtroLuzAzul);
    await prefs.setBool(_kModoSepia, a.modoSepia);
    await prefs.setDouble(_kVolumenEfecto, a.volumenEfecto);
    await prefs.setDouble(_kIntensidadFiltro, a.intensidadFiltro);
    await prefs.setDouble(_kVelocidadVoz, a.velocidadVoz);
    await prefs.setBool(_kSonidoActivado, a.sonidoActivado);
    await prefs.setString(_kNombreSonido, a.nombreSonidoActual);
    await prefs.setString(_kOrdenBiblioteca, a.ordenBiblioteca);
    await prefs.setString(_kIdioma, a.idioma);
    if (a.rutaSonidoPersonalizado != null) {
      await prefs.setString(_kRutaSonidoCustom, a.rutaSonidoPersonalizado!);
    } else {
      await prefs.remove(_kRutaSonidoCustom);
    }
  }
}
