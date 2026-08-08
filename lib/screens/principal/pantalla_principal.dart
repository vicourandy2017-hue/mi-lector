import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/colors.dart';
import '../../core/idiomas.dart';
import '../../core/audio_global.dart';
import '../../core/debouncer.dart';
import '../../models/libro.dart';
import '../../models/pista_musica.dart';
import '../../models/ajustes_app.dart';
import '../../services/biblioteca_repository.dart';
import '../../services/importacion_service.dart';

import '../../widgets/onda_sonido_widget.dart';
import '../../widgets/tarjeta_libro_glass.dart';
import '../../models/racha_lectura.dart';
import '../lector/pantalla_lector_pdf.dart';
import '../lector/pantalla_lector_epub.dart';
import '../lector/pantalla_lector_docx.dart';
import '../reproductores/pantalla_audiolibro.dart';
import '../reproductores/pantalla_video.dart';
import '../biblioteca/pantalla_estadisticas.dart';
import '../biblioteca/pantalla_bibliotecas_directas.dart';
import '../musica/pantalla_musica.dart';
import '../web/pantalla_visor_web.dart';

// ─── ID producto IAP ────────────────────────────────────────────────────────
const String _kProductId = 'mi_lector_pro_premium';
const int    _kDiasGratis = 12;

class PantallaPrincipalMiLector extends StatefulWidget {
  const PantallaPrincipalMiLector({super.key});

  @override
  State<PantallaPrincipalMiLector> createState() =>
      _PantallaPrincipalMiLectorState();
}

class _PantallaPrincipalMiLectorState
    extends State<PantallaPrincipalMiLector> {
  // ── Repositorio y utilidades ──────────────────────────────────────────────
  final _repo      = BibliotecaRepository();
  final _debouncer = Debouncer(milliseconds: 300);

  // ── Estado de la app ──────────────────────────────────────────────────────
  List<Libro>     _libros          = [];
  List<Libro>     _librosMostrados = [];
  List<PistaMusica> _pistas        = [];
  List<String>    _categorias      = ['Todas', 'General'];
  String          _categoriaActual = 'Todas';
  String          _seccion         = 'biblioteca';
  AjustesApp      _ajustes         = AjustesApp();
  bool            _cargando        = true;

  // ── Búsqueda ──────────────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  bool  _buscando   = false;

  // ── IAP / Licencia ────────────────────────────────────────────────────────
  bool   _tieneAcceso      = true;
  bool   _cargandoLicencia = true;
  bool   _cargandoCompra   = false;
  final  _iap = InAppPurchase.instance;
  late   StreamSubscription<List<PurchaseDetails>> _iapSub;
  List<ProductDetails> _productos = [];

  // ── Drawer ────────────────────────────────────────────────────────────────
  final _drawerKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    AudioGlobal().init();
    _cargarTodo();
    _inicializarTienda();
    _verificarAcceso();
  }

  // ─── Carga inicial ────────────────────────────────────────────────────────
  Future<void> _cargarTodo() async {
    final oscuro = WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
    final ajustes   = await _repo.cargarAjustes(esOscuroSistemaPorDefecto: oscuro);
    final libros    = await _repo.cargarLibros();
    final cats      = await _repo.cargarCategorias();
    final pistas    = await _repo.cargarPistasMusica();

    TextosIdioma.instancia.inicializarSinNotificar(ajustes.idioma);
    AudioGlobal().cambiarVolumen(ajustes.volumenEfecto);

    if (mounted) {
      setState(() {
        _ajustes    = ajustes;
        _libros     = libros;
        _categorias = cats;
        _pistas     = pistas;
        _cargando   = false;
      });
      _aplicarFiltro();
    }
  }

  // ─── IAP / Licencia ────────────────────────────────────────────────────────
  Future<void> _inicializarTienda() async {
    final disponible = await _iap.isAvailable();
    if (!disponible) return;
    _iapSub = _iap.purchaseStream.listen(_procesarCompras);
    try {
      final resp = await _iap.queryProductDetails({_kProductId});
      if (mounted) setState(() => _productos = resp.productDetails);
    } catch (_) {}
  }

  void _procesarCompras(List<PurchaseDetails> lista) {
    for (final compra in lista) {
      if (compra.status == PurchaseStatus.purchased ||
          compra.status == PurchaseStatus.restored) {
        if (mounted) setState(() { _tieneAcceso = true; _cargandoCompra = false; });
        _guardarAccesoPremium();
        if (compra.pendingCompletePurchase) {
          _iap.completePurchase(compra);
        }
      } else if (compra.status == PurchaseStatus.error) {
        if (mounted) setState(() => _cargandoCompra = false);
      }
    }
  }

  Future<void> _verificarAcceso() async {
    final prefs = await SharedPreferences.getInstance();
    // Verificar si ya pagó
    if (prefs.getBool('premium_activo') == true) {
      if (mounted) setState(() { _tieneAcceso = true; _cargandoLicencia = false; });
      return;
    }
    // Período de prueba
    final primerUsoStr = prefs.getString('primer_uso_fecha');
    if (primerUsoStr == null) {
      await prefs.setString('primer_uso_fecha', DateTime.now().toIso8601String());
      if (mounted) setState(() { _tieneAcceso = true; _cargandoLicencia = false; });
      return;
    }
    final primerUso = DateTime.tryParse(primerUsoStr) ?? DateTime.now();
    final dias = DateTime.now().difference(primerUso).inDays;
    if (mounted) {
      setState(() {
        _tieneAcceso      = dias < _kDiasGratis;
        _cargandoLicencia = false;
      });
    }
  }

  Future<void> _guardarAccesoPremium() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('premium_activo', true);
  }

  Future<void> _comprarPremium() async {
    if (_productos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tienda no disponible en este momento.')),
      );
      return;
    }
    setState(() => _cargandoCompra = true);
    await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: _productos.first),
    );
  }

  // ─── Filtros ──────────────────────────────────────────────────────────────
  void _aplicarFiltro() {
    List<Libro> base;
    switch (_seccion) {
      case 'leyendo'    : base = _libros.where((l) => l.ultimaPagina > 1 && !l.leido).toList(); break;
      case 'favoritos'  : base = _libros.where((l) => l.esFavorito).toList(); break;
      case 'porLeer'    : base = _libros.where((l) => l.porLeer && !l.leido).toList(); break;
      case 'leidos'     : base = _libros.where((l) => l.leido).toList(); break;
      case 'audiolibros': base = _libros.where((l) => l.esAudiolibro).toList(); break;
      case 'videos'     : base = _libros.where((l) => l.esVideo).toList(); break;
      case 'documentos' : base = _libros.where((l) => l.esDocx).toList(); break;
      default           : base = _libros;
    }

    // Filtro de categoría
    if (_categoriaActual != 'Todas') {
      base = base.where((l) => l.categoria == _categoriaActual).toList();
    }

    // Búsqueda
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      base = base.where((l) => l.titulo.toLowerCase().contains(q)).toList();
    }

    // Orden
    switch (_ajustes.ordenBiblioteca) {
      case 'A-Z'      : base.sort((a, b) => a.titulo.compareTo(b.titulo)); break;
      case 'Z-A'      : base.sort((a, b) => b.titulo.compareTo(a.titulo)); break;
      case 'Recientes': break; // El orden de inserción es el más reciente
    }

    setState(() => _librosMostrados = base);
  }

  void _cambiarSeccion(String s) {
    setState(() { _seccion = s; _categoriaActual = 'Todas'; });
    _aplicarFiltro();
    Navigator.pop(context); // cerrar Drawer
  }

  // ─── Acciones de biblioteca ───────────────────────────────────────────────
  Future<void> _importarArchivo() async {
    final libro = await ImportacionService.importarArchivo(
      context,
      categoriaInicial: _categoriaActual == 'Todas' ? 'General' : _categoriaActual,
    );
    if (libro != null) {
      setState(() => _libros.insert(0, libro));
      await _repo.guardarLibros(_libros);
      _aplicarFiltro();
    }
  }

  Future<void> _importarPista() async {
    final pista = await ImportacionService.importarPistaMusica(context);
    if (pista != null) {
      setState(() => _pistas.add(pista));
      await _repo.guardarPistasMusica(_pistas);
    }
  }

  void _eliminarPista(PistaMusica pista) {
    setState(() => _pistas.removeWhere((p) => p.id == pista.id));
    _repo.guardarPistasMusica(_pistas);
  }

  Future<void> _abrirLibro(Libro libro) async {
    final inicioLectura = DateTime.now();

    if (libro.esAudiolibro) {
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => PantallaReproductorAudiolibro(
          libro: libro, onCambio: _guardarLibros, pistasMusica: _pistas),
      ));
    } else if (libro.esVideo) {
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => PantallaReproductorVideo(
          libro: libro, onCambio: _guardarLibros, pistasMusica: _pistas),
      ));
    } else if (libro.esEpub) {
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => PantallaLectorEpub(
          libro         : libro,
          modoOscuro    : _ajustes.modoOscuro,
          modoSepia     : _ajustes.modoSepia,
          brillo        : _ajustes.nivelBrillo,
          velocidadVoz  : _ajustes.velocidadVoz,
          pistasMusica  : _pistas,
          onCambio      : _guardarLibros,
        ),
      ));
    } else if (libro.esDocx) {
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => PantallaLectorDocx(
          libro        : libro,
          modoOscuro   : _ajustes.modoOscuro,
          modoSepia    : _ajustes.modoSepia,
          brillo       : _ajustes.nivelBrillo,
          velocidadVoz : _ajustes.velocidadVoz,
          pistasMusica : _pistas,
          onCambio     : _guardarLibros,
        ),
      ));
    } else {
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => PantallaLectorPDF(
          libro        : libro,
          ajustes      : _ajustes,
          onCambio     : _guardarLibros,
          pistasMusica : _pistas,
        ),
      ));
    }

    final duracion = DateTime.now().difference(inicioLectura);
    if (duracion.inSeconds >= 10) {
      final minutos = (duracion.inSeconds / 60).ceil();
      await RachaLectura.registrarMinutosLectura(minutos);
    }

    _aplicarFiltro();
  }

  Future<void> _guardarLibros() async {
    await _repo.guardarLibros(_libros);
    if (mounted) _aplicarFiltro();
  }

  Future<void> _guardarAjustes() async {
    await _repo.guardarAjustes(_ajustes);
  }

  // ─── Categorías ────────────────────────────────────────────────────────────
  void _crearCategoria() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: ColoresApp.fondoTarjeta,
        title: const Text('Nueva categoría', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Nombre de la categoría',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: ColoresApp.acento)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: ColoresApp.acento, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ColoresApp.acento),
            onPressed: () {
              final nombre = ctrl.text.trim();
              if (nombre.isNotEmpty && !_categorias.contains(nombre)) {
                setState(() => _categorias.add(nombre));
                _repo.guardarCategorias(_categorias);
              }
              Navigator.pop(context);
            },
            child: const Text('Crear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _gestionarCategoria(String cat) {
    if (cat == 'Todas' || cat == 'General') return;
    showModalBottomSheet(
      context: context,
      backgroundColor: ColoresApp.fondoTarjeta,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Categoría "$cat"',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: ColoresApp.acento),
              title: const Text('Renombrar', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(context); _renombrarCategoria(cat); },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              title: const Text('Eliminar', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(context); _eliminarCategoria(cat); },
            ),
          ],
        ),
      ),
    );
  }

  void _renombrarCategoria(String cat) {
    final ctrl = TextEditingController(text: cat);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: ColoresApp.fondoTarjeta,
        title: const Text('Renombrar categoría', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: ColoresApp.acento)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ColoresApp.acento),
            onPressed: () {
              final nuevo = ctrl.text.trim();
              if (nuevo.isNotEmpty && nuevo != cat) {
                setState(() {
                  final idx = _categorias.indexOf(cat);
                  if (idx >= 0) _categorias[idx] = nuevo;
                  for (final l in _libros) {
                    if (l.categoria == cat) l.categoria = nuevo;
                  }
                  if (_categoriaActual == cat) _categoriaActual = nuevo;
                });
                _repo.guardarCategorias(_categorias);
                _guardarLibros();
              }
              Navigator.pop(context);
            },
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _eliminarCategoria(String cat) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: ColoresApp.fondoTarjeta,
        title: const Text('¿Eliminar categoría?', style: TextStyle(color: Colors.white)),
        content: Text('Los libros de "$cat" quedarán en "General".',
          style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              setState(() {
                _categorias.remove(cat);
                for (final l in _libros) {
                  if (l.categoria == cat) l.categoria = 'General';
                }
                if (_categoriaActual == cat) _categoriaActual = 'Todas';
              });
              _repo.guardarCategorias(_categorias);
              _guardarLibros();
              Navigator.pop(context);
              _aplicarFiltro();
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── Opciones de libro ────────────────────────────────────────────────────
  void _opcionesLibro(Libro libro) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ColoresApp.fondoTarjeta,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _opcionItem(Icons.star_rounded,
              libro.esFavorito ? 'Quitar de favoritos' : 'Agregar a favoritos',
              () { setState(() => libro.esFavorito = !libro.esFavorito); _guardarLibros(); }),
            _opcionItem(Icons.bookmark_rounded,
              libro.porLeer ? 'Quitar de "Por leer"' : 'Marcar como "Por leer"',
              () { setState(() { libro.porLeer = !libro.porLeer; if (libro.porLeer) libro.leido = false; }); _guardarLibros(); }),
            _opcionItem(Icons.check_circle_rounded, 'Marcar como leído',
              () { setState(() { libro.leido = true; libro.porLeer = false; }); _guardarLibros(); }),
            _opcionItem(Icons.edit_note_rounded, 'Notas personales',
              () { Navigator.pop(context); _mostrarNotas(libro); }),
            _opcionItem(Icons.folder_rounded, 'Cambiar categoría',
              () { Navigator.pop(context); _cambiarCategoria(libro); }),
            _opcionItem(Icons.delete_outline_rounded, 'Eliminar de la biblioteca',
              () { Navigator.pop(context); _confirmarEliminar(libro); },
              color: Colors.redAccent),
          ],
        ),
      ),
    );
  }

  Widget _opcionItem(IconData icono, String texto, VoidCallback onTap,
      {Color? color}) {
    final c = color ?? Colors.white;
    return ListTile(
      leading: Icon(icono, color: color ?? ColoresApp.acento, size: 22),
      title: Text(texto, style: TextStyle(color: c, fontSize: 14)),
      onTap: onTap,
    );
  }

  void _mostrarNotas(Libro libro) {
    final ctrl = TextEditingController(text: libro.notasPersonales);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ColoresApp.fondoTarjeta,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.edit_note_rounded, color: ColoresApp.acento),
                const SizedBox(width: 8),
                Expanded(child: Text(libro.titulo,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              maxLines: 6,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Escribe tus notas aquí...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: ColoresApp.fondoPrincipal,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColoresApp.acento,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  setState(() => libro.notasPersonales = ctrl.text.trim());
                  _guardarLibros();
                  Navigator.pop(context);
                },
                child: const Text('Guardar notas', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _cambiarCategoria(Libro libro) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: ColoresApp.fondoTarjeta,
        title: const Text('Cambiar categoría', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 280,
          child: ListView(
            shrinkWrap: true,
            children: _categorias
                .where((c) => c != 'Todas')
                .map((c) {
                  final bool esSeleccionado = libro.categoria == c;
                  return ListTile(
                    leading: Icon(
                      esSeleccionado ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                      color: esSeleccionado ? ColoresApp.acento : Colors.grey,
                    ),
                    title: Text(
                      c,
                      style: TextStyle(
                        color: esSeleccionado ? ColoresApp.acento : Colors.white,
                        fontWeight: esSeleccionado ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      setState(() => libro.categoria = c);
                      _guardarLibros();
                      Navigator.pop(context);
                    },
                  );
                })
                .toList(),
          ),
        ),
      ),
    );
  }

  void _confirmarEliminar(Libro libro) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: ColoresApp.fondoTarjeta,
        title: const Text('¿Eliminar libro?', style: TextStyle(color: Colors.white)),
        content: Text('Se eliminará "${libro.titulo}" de tu biblioteca.',
          style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              setState(() => _libros.removeWhere((l) => l.id == libro.id));
              _guardarLibros();
              _aplicarFiltro();
              Navigator.pop(context);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _mostrarModalPersonalizarApariencia() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ColoresApp.fondoDrawer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, sc) => StatefulBuilder(
          builder: (ctx2, setModal) {
            final fondos = [
              'assets/images/fondo1.jpg',
              'assets/images/fondo2.jpg',
              'assets/images/fondo3.jpg',
              'assets/images/fondo4.jpg',
            ];
            return SingleChildScrollView(
              controller: sc,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('🎨 Personalizar Apariencia', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Fondos Predeterminados', style: TextStyle(color: ColoresApp.acento, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: fondos.length,
                      itemBuilder: (context, idx) {
                        final ruta = fondos[idx];
                        final act = _ajustes.tipoFondo == 'defecto' && _ajustes.rutaFondoSeleccionado == ruta;
                        return GestureDetector(
                          onTap: () {
                            setModal(() {
                              setState(() {
                                _ajustes.tipoFondo = 'defecto';
                                _ajustes.rutaFondoSeleccionado = ruta;
                                _guardarAjustes();
                              });
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 10),
                            width: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: act ? ColoresApp.acento : Colors.transparent, width: 2),
                              image: DecorationImage(image: AssetImage(ruta), fit: BoxFit.cover),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: ColoresApp.acento),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.photo_library_rounded, color: ColoresApp.acento),
                      label: const Text('Elegir foto de la Galería', style: TextStyle(color: Colors.white)),
                      onPressed: () async {
                        final res = await FilePicker.platform.pickFiles(type: FileType.image);
                        if (res != null && res.files.single.path != null) {
                          setModal(() {
                            setState(() {
                              _ajustes.tipoFondo = 'archivo';
                              _ajustes.rutaFondoSeleccionado = res.files.single.path!;
                              _guardarAjustes();
                            });
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Filtros y Brillo', style: TextStyle(color: ColoresApp.acento, fontWeight: FontWeight.bold, fontSize: 13)),
                  _switchTile('Modo oscuro', _ajustes.modoOscuro, (v) { setModal(() => setState(() { _ajustes.modoOscuro = v; _guardarAjustes(); })); }),
                  _switchTile('Modo sepia', _ajustes.modoSepia, (v) { setModal(() => setState(() { _ajustes.modoSepia = v; _guardarAjustes(); })); }),
                  _switchTile('Filtro luz azul', _ajustes.filtroLuzAzul, (v) { setModal(() => setState(() { _ajustes.filtroLuzAzul = v; _guardarAjustes(); })); }),
                  _sliderTile('Brillo', _ajustes.nivelBrillo, 0.3, 1.0, (v) { setModal(() => setState(() { _ajustes.nivelBrillo = v; _guardarAjustes(); })); }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── Configuración General ─────────────────────────────────────────────────
  void _mostrarConfiguracion() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ColoresApp.fondoDrawer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, sc) => StatefulBuilder(
          builder: (ctx2, setModal) => _buildConfigPanel(sc, setModal),
        ),
      ),
    );
  }

  Widget _buildConfigPanel(ScrollController sc, StateSetter set) {
    return SingleChildScrollView(
      controller: sc,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Configuración',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),

            // ── Apariencia ──────────────────────────────────────────────────
            _seccionHeader('🎨 Apariencia'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.image_rounded, color: ColoresApp.acento),
              title: const Text('Fondo de Pantalla', style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: Text(
                _ajustes.tipoFondo == 'defecto'
                    ? 'Predeterminado'
                    : _ajustes.tipoFondo == 'archivo'
                        ? 'Imagen de Galería'
                        : 'Color Sólido',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
              onTap: () {
                Navigator.pop(context);
                _mostrarModalPersonalizarApariencia();
              },
            ),
            _switchTile('Modo oscuro', _ajustes.modoOscuro,
              (v) { set(() { setState(() => _ajustes.modoOscuro = v); _guardarAjustes(); }); }),
            _switchTile('Modo sepia', _ajustes.modoSepia,
              (v) { set(() { setState(() => _ajustes.modoSepia = v); _guardarAjustes(); }); }),
            _switchTile('Filtro luz azul', _ajustes.filtroLuzAzul,
              (v) { set(() { setState(() => _ajustes.filtroLuzAzul = v); _guardarAjustes(); }); }),
            _sliderTile('Nivel de Brillo', _ajustes.nivelBrillo, 0.3, 1.0,
              (v) { set(() { setState(() => _ajustes.nivelBrillo = v); _guardarAjustes(); }); }),
            if (_ajustes.filtroLuzAzul)
              _sliderTile('Intensidad filtro luz azul', _ajustes.intensidadFiltro, 0.0, 0.6,
                (v) { set(() { setState(() => _ajustes.intensidadFiltro = v); _guardarAjustes(); }); }),

            const SizedBox(height: 16),
            // ── Sonido ──────────────────────────────────────────────────────
            _seccionHeader('🔊 Sonido'),
            _switchTile('Sonido al pasar página', _ajustes.sonidoActivado,
              (v) { set(() { setState(() => _ajustes.sonidoActivado = v); _guardarAjustes(); }); }),
            if (_ajustes.sonidoActivado) ...[
              _sliderTile('Volumen efecto', _ajustes.volumenEfecto, 0.0, 1.0,
                (v) { set(() { setState(() => _ajustes.volumenEfecto = v); _guardarAjustes(); }); }),
              _selectorTile('Efecto al pasar página', _ajustes.nombreSonidoActual,
                ['Efecto 1', 'Efecto 2', 'Efecto 3', 'Efecto 4', 'Efecto 5', 'Efecto 6', 'Efecto 7', 'Efecto 8', 'Efecto 9', 'Efecto 10', 'Efecto 11', 'Efecto 12'],
                (v) { if (v != null) { set(() { setState(() => _ajustes.nombreSonidoActual = v); _guardarAjustes(); }); } }),
            ],
            _sliderTile('Velocidad de voz TTS', _ajustes.velocidadVoz, 0.5, 2.0,
              (v) { set(() { setState(() => _ajustes.velocidadVoz = v); _guardarAjustes(); }); }),

            const SizedBox(height: 16),
            // ── Biblioteca ─────────────────────────────────────────────────
            _seccionHeader('📚 Biblioteca'),
            _selectorTile('Ordenar por', _ajustes.ordenBiblioteca,
              ['Recientes', 'A-Z', 'Z-A'],
              (v) { if (v != null) { set(() { setState(() => _ajustes.ordenBiblioteca = v); _guardarAjustes(); _aplicarFiltro(); }); } }),
            _selectorTile('Idioma', _ajustes.idioma,
              TextosIdioma.idiomasDisponibles,
              (v) { if (v != null) {
                set(() { setState(() {
                  _ajustes.idioma = v;
                  TextosIdioma.instancia.establecerIdioma(v);
                  _guardarAjustes();
                }); });
              } }),

            const SizedBox(height: 16),
            // ── Música de fondo ────────────────────────────────────────────
            _seccionHeader('🎼 Música de fondo'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.music_note_rounded, color: ColoresApp.acento),
              title: const Text('Gestionar pistas', style: TextStyle(color: Colors.white)),
              subtitle: Text('${_pistas.length} pistas guardadas',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
              onTap: () {
                Navigator.pop(context);
                _cambiarSeccion('musica');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _seccionHeader(String titulo) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(titulo, style: const TextStyle(
      color: ColoresApp.acento, fontSize: 14, fontWeight: FontWeight.w700)),
  );

  Widget _switchTile(String label, bool valor, void Function(bool) onChange) =>
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title     : Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
      value     : valor,
      activeThumbColor: ColoresApp.acento,
      onChanged : onChange,
    );

  Widget _sliderTile(String label, double valor, double min, double max,
      void Function(double) onChange) =>
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(valor.toStringAsFixed(1), style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ]),
        Slider(value: valor, min: min, max: max,
          activeColor: ColoresApp.acento, inactiveColor: Colors.white24,
          onChanged: onChange),
      ],
    );

  Widget _selectorTile(String label, String actual, List<String> opciones,
      void Function(String?) onChange) {
    final valorSeguro = opciones.contains(actual) ? actual : opciones.first;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13))),
          DropdownButton<String>(
            value: valorSeguro,
            dropdownColor: ColoresApp.fondoTarjeta,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            underline: const SizedBox(),
            items: opciones.map((o) => DropdownMenuItem(value: o,
              child: Text(o, style: const TextStyle(color: Colors.white)))).toList(),
            onChanged: onChange,
          ),
        ],
      ),
    );
  }

  // ─── Fondo de pantalla ────────────────────────────────────────────────────
  Color _colorFondoSolido() {
    if (_ajustes.colorSolidoId != null) {
      return ColoresApp.fondosSolidos[_ajustes.colorSolidoId!] ??
          ColoresApp.fondoPrincipal;
    }
    return ColoresApp.fondoPrincipal;
  }

  Widget _buildFondo() {
    if (_ajustes.tipoFondo == 'archivo' && _ajustes.rutaFondoSeleccionado.isNotEmpty) {
      final f = File(_ajustes.rutaFondoSeleccionado);
      if (f.existsSync()) {
        return Image.file(f, fit: BoxFit.cover,
          width: double.infinity, height: double.infinity);
      }
    }
    if (_ajustes.tipoFondo == 'defecto') {
      final ruta = _ajustes.rutaFondoSeleccionado.isNotEmpty
          ? _ajustes.rutaFondoSeleccionado
          : 'assets/images/fondo1.jpg';
      return Image.asset(ruta,
        fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    }
    return Container(color: _colorFondoSolido());
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_cargandoLicencia) {
      return const Scaffold(
        backgroundColor: ColoresApp.fondoPrincipal,
        body: Center(child: CircularProgressIndicator(color: ColoresApp.acento)),
      );
    }

    if (!_tieneAcceso) return _buildPaywall();

    return AnimatedBuilder(
      animation: TextosIdioma.instancia,
      builder: (_, __) => Opacity(
        opacity: _ajustes.nivelBrillo.clamp(0.3, 1.0),
        child: Stack(
          children: [
            // Fondo
            Positioned.fill(child: _buildFondo()),
            // Overlay oscuro
            Positioned.fill(
              child: Container(
                color: _ajustes.modoOscuro
                    ? Colors.black.withAlpha(100)
                    : Colors.black.withAlpha(40),
              ),
            ),
            // Filtro luz azul
            if (_ajustes.filtroLuzAzul)
              Positioned.fill(
                child: Container(
                  color: const Color(0xFFFF8C00)
                      .withAlpha((_ajustes.intensidadFiltro * 255).round()),
                ),
              ),
            // SafeArea + Scaffold
            SafeArea(
              child: Scaffold(
                key            : _drawerKey,
                backgroundColor: Colors.transparent,
                appBar         : _buildAppBar(),
                drawer         : _buildDrawer(),
                body           : _cargando ? _buildLoading() : _buildBody(),
                floatingActionButton: _buildFab(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor : Colors.transparent,
      elevation       : 0,
      leadingWidth: 170,
      leading: InkWell(
        onTap: () => _drawerKey.currentState?.openDrawer(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset('assets/icono.png', width: 26, height: 26, fit: BoxFit.cover),
              ),
              const SizedBox(width: 6),
              const Text(
                'Mi Lector Pro',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
      title: _buscando
          ? TextField(
              controller  : _searchCtrl,
              autofocus   : true,
              style       : const TextStyle(color: Colors.white),
              onChanged   : (_) => _debouncer.run(_aplicarFiltro),
              decoration  : InputDecoration(
                hintText  : TextosIdioma.instancia.get('buscarHint'),
                hintStyle : const TextStyle(color: Colors.white38),
                border    : InputBorder.none,
              ),
            )
          : Text(
              _seccionLabel(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
      actions: [
        // Onda de Sonido / Ecualizador animado si hay audio sonando
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Center(child: OndaSonidoAnimada()),
        ),
        // Búsqueda web (cuando está buscando)
        if (_buscando)
          IconButton(
            tooltip  : 'Buscar en web',
            icon     : const Icon(Icons.public_rounded, color: Colors.white70),
            onPressed: () {
              final q = _searchCtrl.text.trim();
              if (q.isNotEmpty) {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => PantallaVisorWebCompleto(
                    url   : 'https://www.google.com/search?q=${Uri.encodeComponent(q)}',
                    titulo: 'Google',
                  ),
                ));
              }
            },
          ),
        // Orden
        PopupMenuButton<String>(
          icon : const Icon(Icons.sort_rounded, color: Colors.white70),
          color: ColoresApp.fondoTarjeta,
          onSelected: (v) {
            setState(() => _ajustes.ordenBiblioteca = v);
            _guardarAjustes();
            _aplicarFiltro();
          },
          itemBuilder: (_) => ['Recientes', 'A-Z', 'Z-A']
              .map((o) => PopupMenuItem(
                    value: o,
                    child: Text(o, style: const TextStyle(color: Colors.white)),
                  ))
              .toList(),
        ),

        // Buscar / cerrar búsqueda
        IconButton(
          tooltip  : _buscando ? 'Cerrar búsqueda' : 'Buscar',
          icon     : Icon(
            _buscando ? Icons.close_rounded : Icons.search_rounded,
            color: Colors.white70,
          ),
          onPressed: () {
            setState(() {
              _buscando = !_buscando;
              if (!_buscando) {
                _searchCtrl.clear();
                _aplicarFiltro();
              }
            });
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  String _seccionLabel() {
    final t = TextosIdioma.instancia;
    switch (_seccion) {
      case 'biblioteca' : return t.get('biblioteca');
      case 'leyendo'    : return t.get('leyendo');
      case 'favoritos'  : return t.get('favoritos');
      case 'porLeer'    : return t.get('porLeer');
      case 'leidos'     : return t.get('leidos');
      case 'audiolibros': return t.get('audiolibros');
      case 'videos'     : return t.get('videos');
      case 'documentos' : return t.get('documentos');
      case 'musica'     : return t.get('musica');
      case 'estadisticas': return t.get('estadisticas');
      case 'descargar'  : return t.get('descargar');
      default           : return 'Mi Lector Pro';
    }
  }

  Widget _buildDrawer() {
    final t = TextosIdioma.instancia;
    return Drawer(
      backgroundColor: ColoresApp.fondoDrawer,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [ColoresApp.acentoOscuro, ColoresApp.fondoDrawer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 36),
                const SizedBox(height: 8),
                const Text('Mi Lector Pro',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                const Text('Centro Multimedia',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
                const Spacer(),
                Text('${_libros.length} archivos en biblioteca',
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),

          // ── Mi Biblioteca ───────────────────────────────────────────────
          ExpansionTile(
            initiallyExpanded: true,
            leading: const Icon(Icons.library_books_rounded, color: ColoresApp.acento, size: 22),
            title: Text(t.get('miBibliotecaTitle'),
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            iconColor: ColoresApp.acento,
            collapsedIconColor: Colors.white38,
            children: [
              _drawerItem(Icons.menu_book_rounded,       t.get('biblioteca'),  () => _cambiarSeccion('biblioteca')),
              _drawerItem(Icons.import_contacts_rounded, t.get('leyendo'),     () => _cambiarSeccion('leyendo')),
              _drawerItem(Icons.star_rounded,            t.get('favoritos'),   () => _cambiarSeccion('favoritos')),
              _drawerItem(Icons.bookmark_rounded,        t.get('porLeer'),     () => _cambiarSeccion('porLeer')),
              _drawerItem(Icons.check_circle_rounded,    t.get('leidos'),      () => _cambiarSeccion('leidos')),
            ],
          ),

          const Divider(color: Colors.white12, height: 1),

          // ── Multimedia ──────────────────────────────────────────────────
          ExpansionTile(
            leading: const Icon(Icons.play_circle_rounded, color: ColoresApp.acento, size: 22),
            title: Text(t.get('multimediaTitle'),
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            iconColor: ColoresApp.acento,
            collapsedIconColor: Colors.white38,
            children: [
              _drawerItem(Icons.headphones_rounded,  t.get('audiolibros'), () => _cambiarSeccion('audiolibros')),
              _drawerItem(Icons.videocam_rounded,    t.get('videos'),      () => _cambiarSeccion('videos')),
              _drawerItem(Icons.description_rounded, t.get('documentos'),  () => _cambiarSeccion('documentos')),
              _drawerItem(Icons.music_note_rounded,  t.get('musica'),      () {
                _cambiarSeccion('musica');
              }),
            ],
          ),

          const Divider(color: Colors.white12, height: 1),

          // ── Herramientas ────────────────────────────────────────────────
          ExpansionTile(
            leading: const Icon(Icons.dashboard_rounded, color: ColoresApp.acento, size: 22),
            title: Text(t.get('herramientasTitle'),
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            iconColor: ColoresApp.acento,
            collapsedIconColor: Colors.white38,
            children: [
              _drawerItem(Icons.bar_chart_rounded,  t.get('estadisticas'), () => _cambiarSeccion('estadisticas')),
              _drawerItem(Icons.public_rounded,     t.get('descargar'),    () => _cambiarSeccion('descargar')),
              _drawerItem(Icons.settings_rounded,   t.get('config'),       () {
                Navigator.pop(context);
                _mostrarConfiguracion();
              }),
            ],
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icono, String texto, VoidCallback onTap) {
    final esActual = _seccionLabel() == texto;
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 56, right: 16),
      leading: null,
      title: Row(
        children: [
          Icon(icono, size: 18, color: esActual ? ColoresApp.acento : Colors.white54),
          const SizedBox(width: 12),
          Expanded(
            child: Text(texto,
              style: TextStyle(
                color    : esActual ? ColoresApp.acento : Colors.white70,
                fontSize : 13,
                fontWeight: esActual ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          if (esActual)
            Container(
              width: 4, height: 4,
              decoration: const BoxDecoration(
                color: ColoresApp.acento,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildQuickResumeBanner() {
    final enProgreso = _libros.where((l) => (l.ultimaPagina > 1 || l.posicionMs > 0) && !l.leido).toList();
    if (enProgreso.isEmpty) return const SizedBox.shrink();

    final ultimo = enProgreso.first;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 2.0),
      child: GestureDetector(
        onTap: () => _abrirLibro(ultimo),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [ColoresApp.acentoOscuro, Color(0xFF16333D)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: ColoresApp.acento.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.amberAccent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Reanudar: ${ultimo.titulo}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    // Vistas especiales por sección
    if (_seccion == 'estadisticas') {
      return PantallaEstadisticas(libros: _libros, pistasMusica: _pistas);
    }
    if (_seccion == 'descargar') {
      return const PantallaBibliotecasDirectas();
    }
    if (_seccion == 'musica') {
      return PantallaMusicaGratis(
        pistas         : _pistas,
        onAgregarPista : _importarPista,
        onEliminarPista: _eliminarPista,
      );
    }

    return Column(
      children: [
        // ⚡ 1. Tarjeta Reanudar Rápido compacta (1-Tap Quick Resume)
        if (['biblioteca', 'leyendo'].contains(_seccion) && !_buscando)
          _buildQuickResumeBanner(),

        // 🏷️ 3. Chips de categorías
        if (['biblioteca', 'leyendo', 'favoritos', 'porLeer', 'leidos'].contains(_seccion))
          _buildCategoryChips(),

        // 📚 4. Grilla de libros
        Expanded(
          child: _librosMostrados.isEmpty
              ? _buildEmptyState()
              : _buildGrid(),
        ),
      ],
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          ..._categorias.map((c) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onLongPress: () => _gestionarCategoria(c),
              child: FilterChip(
                label: Text(c,
                  style: TextStyle(
                    color    : _categoriaActual == c ? Colors.white : Colors.white60,
                    fontSize : 12,
                  ),
                ),
                selected      : _categoriaActual == c,
                selectedColor : ColoresApp.acentoOscuro,
                backgroundColor: ColoresApp.fondoTarjeta,
                checkmarkColor: Colors.white,
                side: BorderSide(
                  color: _categoriaActual == c ? ColoresApp.acento : Colors.white12,
                ),
                onSelected: (_) {
                  setState(() => _categoriaActual = c);
                  _aplicarFiltro();
                },
              ),
            ),
          )),
          // Chip para agregar categoría
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: const Text('+', style: TextStyle(color: ColoresApp.acento, fontSize: 16)),
              backgroundColor: ColoresApp.fondoTarjeta,
              side: const BorderSide(color: ColoresApp.acento, width: 1),
              onPressed: _crearCategoria,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    final ancho   = MediaQuery.of(context).size.width;
    final columnas = ancho > 600 ? 5 : 3;

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount   : columnas,
        childAspectRatio : 0.62,
        crossAxisSpacing : 10,
        mainAxisSpacing  : 10,
      ),
      itemCount  : _librosMostrados.length,
      itemBuilder: (_, i) => _buildLibroCard(_librosMostrados[i]),
    );
  }

  Widget _buildLibroCard(Libro libro) {
    return TarjetaLibroGlass(
      libro: libro,
      onTap: () => _abrirLibro(libro),
      onLongPress: () => _opcionesLibro(libro),
      onPortadaGenerada: (ruta) {
        libro.rutaPortadaCache = ruta;
        _repo.guardarLibros(_libros);
      },
    );
  }



  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_books_rounded,
            color: ColoresApp.acento.withAlpha(100), size: 80),
          const SizedBox(height: 20),
          const Text('No hay archivos aquí todavía',
            style: TextStyle(color: Colors.white54, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Toca el botón + para agregar',
            style: TextStyle(color: Colors.white38, fontSize: 13)),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: ColoresApp.acentoOscuro,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon     : const Icon(Icons.add_rounded, color: Colors.white),
            label    : const Text('Agregar archivo', style: TextStyle(color: Colors.white)),
            onPressed: _importarArchivo,
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() => const Center(
    child: CircularProgressIndicator(color: ColoresApp.acento));

  Widget _buildFab() {
    if (['estadisticas', 'descargar'].contains(_seccion)) return const SizedBox();
    return FloatingActionButton.extended(
      backgroundColor: ColoresApp.acentoOscuro,
      elevation      : 4,
      icon  : const Icon(Icons.add_rounded, color: Colors.white),
      label : Text(TextosIdioma.instancia.get('agregar'),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      onPressed: () {
        if (_seccion == 'musica') {
          _importarPista();
        } else {
          _importarArchivo();
        }
      },
    );
  }

  // ─── Paywall ──────────────────────────────────────────────────────────────
  Widget _buildPaywall() {
    return Scaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding    : const EdgeInsets.all(24),
                  decoration : BoxDecoration(
                    color        : ColoresApp.fondoTarjeta,
                    shape        : BoxShape.circle,
                    boxShadow    : [
                      BoxShadow(
                        color     : ColoresApp.acento.withAlpha(80),
                        blurRadius: 40,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.auto_stories_rounded,
                    color: ColoresApp.acento, size: 60),
                ),
                const SizedBox(height: 28),
                const Text('Mi Lector Pro',
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                const Text(
                  'Tu período de prueba gratuito ha terminado.\n'
                  'Adquiere la versión completa para seguir leyendo sin límites.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
                ),
                const SizedBox(height: 32),
                // Beneficios
                ...[
                  '✓ Acceso ilimitado a todos los formatos',
                  '✓ Música de fondo para leer',
                  '✓ Estadísticas de lectura',
                  '✓ Sin anuncios',
                ].map((b) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(b, style: const TextStyle(color: Colors.white60, fontSize: 14)),
                )),
                const SizedBox(height: 32),
                // Precio
                Text(
                  _productos.isNotEmpty ? _productos.first.price : '\$ 20.000 COP',
                  style: const TextStyle(
                    color: ColoresApp.acento,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text('pago único, para siempre',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColoresApp.acento,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _cargandoCompra ? null : _comprarPremium,
                    child: _cargandoCompra
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Comprar ahora',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    setState(() => _cargandoCompra = true);
                    await _iap.restorePurchases();
                    setState(() => _cargandoCompra = false);
                  },
                  child: const Text('Restaurar compra',
                    style: TextStyle(color: Colors.white38, fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _iapSub.cancel();
    _searchCtrl.dispose();
    _debouncer.dispose();
    super.dispose();
  }
}
