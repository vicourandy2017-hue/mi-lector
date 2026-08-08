import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// MARCADOR
// ---------------------------------------------------------------------------
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
        'pagina'   : pagina,
        'etiqueta' : etiqueta,
        'creadoEn' : creadoEn.toIso8601String(),
      };

  factory Marcador.fromMap(Map<String, dynamic> map) => Marcador(
        pagina    : map['pagina'] ?? 1,
        etiqueta  : map['etiqueta'] ?? 'Marcador',
        creadoEn  : map['creadoEn'] != null
            ? DateTime.tryParse(map['creadoEn']) ?? DateTime.now()
            : DateTime.now(),
      );
}

// ---------------------------------------------------------------------------
// AREA RESALTADA
// ---------------------------------------------------------------------------
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
        'pagina'  : pagina,
        'x'       : x,
        'y'       : y,
        'ancho'   : ancho,
        'alto'    : alto,
        // toARGB32() is the modern API (Flutter ≥ 3.27); replaces deprecated .value
        'color'   : color.toARGB32(),
        'opacidad': opacidad,
      };

  factory AreaResaltada.fromMap(Map<String, dynamic> map) => AreaResaltada(
        pagina   : map['pagina'] ?? 1,
        x        : (map['x'] ?? 0.0).toDouble(),
        y        : (map['y'] ?? 0.0).toDouble(),
        ancho    : (map['ancho'] ?? 0.0).toDouble(),
        alto     : (map['alto'] ?? 0.0).toDouble(),
        color    : Color(map['color'] ?? Colors.yellow.toARGB32()),
        opacidad : (map['opacidad'] ?? 0.3).toDouble(),
      );
}

// ---------------------------------------------------------------------------
// LIBRO
// ---------------------------------------------------------------------------
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
    this.ultimaPagina    = 1,
    this.esFavorito      = false,
    this.porLeer         = true,
    this.leido           = false,
    this.categoria       = 'General',
    this.esAudiolibro    = false,
    this.esEpub          = false,
    this.esVideo         = false,
    this.esDocx          = false,
    this.notasPersonales = '',
    List<Marcador>? marcadores,
    List<AreaResaltada>? resaltados,
    this.posicionMs      = 0,
    this.rutaPortadaCache,
  })  : marcadores = marcadores ?? [],
        resaltados = resaltados ?? [];

  List<AreaResaltada> resaltadosDePagina(int pagina) =>
      resaltados.where((r) => r.pagina == pagina).toList();

  Map<String, dynamic> toMap() => {
        'id'              : id,
        'titulo'          : titulo,
        'rutaLocal'       : rutaLocal,
        'ultimaPagina'    : ultimaPagina,
        'esFavorito'      : esFavorito,
        'porLeer'         : porLeer,
        'leido'           : leido,
        'categoria'       : categoria,
        'esAudiolibro'    : esAudiolibro,
        'esEpub'          : esEpub,
        'esVideo'         : esVideo,
        'esDocx'          : esDocx,
        'notasPersonales' : notasPersonales,
        'marcadores'      : marcadores.map((m) => m.toMap()).toList(),
        'resaltados'      : resaltados.map((r) => r.toMap()).toList(),
        'posicionMs'      : posicionMs,
        'rutaPortadaCache': rutaPortadaCache,
      };

  factory Libro.fromMap(Map<String, dynamic> map) => Libro(
        id              : map['id'],
        titulo          : map['titulo'],
        rutaLocal       : map['rutaLocal'],
        ultimaPagina    : map['ultimaPagina'] ?? 1,
        esFavorito      : map['esFavorito'] ?? false,
        porLeer         : map['porLeer'] ?? true,
        leido           : map['leido'] ?? false,
        categoria       : map['categoria'] ?? 'General',
        esAudiolibro    : map['esAudiolibro'] ?? false,
        esEpub          : map['esEpub'] ?? false,
        esVideo         : map['esVideo'] ?? false,
        esDocx          : map['esDocx'] ?? false,
        notasPersonales : map['notasPersonales'] ?? '',
        marcadores      : (map['marcadores'] as List<dynamic>?)
                ?.map((m) => Marcador.fromMap(m))
                .toList() ??
            [],
        resaltados      : (map['resaltados'] as List<dynamic>?)
                ?.map((r) => AreaResaltada.fromMap(r))
                .toList() ??
            [],
        posicionMs      : map['posicionMs'] ?? 0,
        rutaPortadaCache: map['rutaPortadaCache'],
      );
}
