class PistaMusica {
  final String id;
  final String titulo;
  final String rutaLocal;

  PistaMusica({
    required this.id,
    required this.titulo,
    required this.rutaLocal,
  });

  Map<String, dynamic> toMap() => {
        'id'       : id,
        'titulo'   : titulo,
        'rutaLocal': rutaLocal,
      };

  factory PistaMusica.fromMap(Map<String, dynamic> map) => PistaMusica(
        id       : map['id'],
        titulo   : map['titulo'],
        rutaLocal: map['rutaLocal'],
      );
}
