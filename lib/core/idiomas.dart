import 'package:flutter/foundation.dart';

class TextosIdioma extends ChangeNotifier {
  TextosIdioma._internal();
  static final TextosIdioma instancia = TextosIdioma._internal();

  static const Map<String, Map<String, String>> _diccionarios = {
    'Español': {
      'biblioteca'        : 'Libros',
      'audiolibros'       : 'Audiolibros 🎧',
      'videos'            : 'Videos 🎬',
      'documentos'        : 'Documentos Word 📝',
      'estadisticas'      : 'Estadísticas 📊',
      'config'            : 'Configuración',
      'descargar'         : 'Biblioteca Publica',
      'musica'            : 'Música de fondo para leer 🎼',
      'leyendo'           : 'Leyendo ahora',
      'favoritos'         : 'Favoritos',
      'porLeer'           : 'Por leer',
      'leidos'            : 'Leídos',
      'agregar'           : 'Agregar',
      'buscarHint'        : 'Buscar libro o presiona web...',
      'miBibliotecaTitle' : 'Mi Biblioteca',
      'multimediaTitle'   : 'Multimedia',
      'herramientasTitle' : 'Herramientas',
    },
    'English': {
      'biblioteca'        : 'Books',
      'audiolibros'       : 'Audiobooks 🎧',
      'videos'            : 'Videos 🎬',
      'documentos'        : 'Word Documents 📝',
      'estadisticas'      : 'Statistics 📊',
      'config'            : 'Settings',
      'descargar'         : 'Public Library',
      'musica'            : 'Music for Reading 🎼',
      'leyendo'           : 'Reading Now',
      'favoritos'         : 'Favorites',
      'porLeer'           : 'To Read',
      'leidos'            : 'Read',
      'agregar'           : 'Add',
      'buscarHint'        : 'Search book or tap web...',
      'miBibliotecaTitle' : 'My Library',
      'multimediaTitle'   : 'Multimedia',
      'herramientasTitle' : 'Tools',
    },
    'Português': {
      'biblioteca'        : 'Livros',
      'audiolibros'       : 'Audiolivros 🎧',
      'videos'            : 'Vídeos 🎬',
      'documentos'        : 'Documentos Word 📝',
      'estadisticas'      : 'Estatísticas 📊',
      'config'            : 'Configurações',
      'descargar'         : 'Biblioteca Pública',
      'musica'            : 'Música para Leitura 🎼',
      'leyendo'           : 'Lendo Agora',
      'favoritos'         : 'Favoritos',
      'porLeer'           : 'Para Ler',
      'leidos'            : 'Lidos',
      'agregar'           : 'Adicionar',
      'buscarHint'        : 'Buscar livro...',
      'miBibliotecaTitle' : 'Minha Biblioteca',
      'multimediaTitle'   : 'Multimídia',
      'herramientasTitle' : 'Ferramentas',
    },
    'Français': {
      'biblioteca'        : 'Livres',
      'audiolibros'       : 'Livres audio 🎧',
      'videos'            : 'Vidéos 🎬',
      'documentos'        : 'Documents Word 📝',
      'estadisticas'      : 'Statistiques 📊',
      'config'            : 'Paramètres',
      'descargar'         : 'Bibliothèque publique',
      'musica'            : 'Musique de lecture 🎼',
      'leyendo'           : 'Lecture en cours',
      'favoritos'         : 'Favoris',
      'porLeer'           : 'À lire',
      'leidos'            : 'Lus',
      'agregar'           : 'Ajouter',
      'buscarHint'        : 'Rechercher un livre...',
      'miBibliotecaTitle' : 'Ma Bibliothèque',
      'multimediaTitle'   : 'Multimédia',
      'herramientasTitle' : 'Outils',
    },
    'Deutsch': {
      'biblioteca'        : 'Bücher',
      'audiolibros'       : 'Hörbücher 🎧',
      'videos'            : 'Videos 🎬',
      'documentos'        : 'Word-Dokumente 📝',
      'estadisticas'      : 'Statistiken 📊',
      'config'            : 'Einstellungen',
      'descargar'         : 'Öffentliche Bibliothek',
      'musica'            : 'Lesemusik 🎼',
      'leyendo'           : 'Liest gerade',
      'favoritos'         : 'Favoriten',
      'porLeer'           : 'Zu lesen',
      'leidos'            : 'Gelesen',
      'agregar'           : 'Hinzufügen',
      'buscarHint'        : 'Buch suchen...',
      'miBibliotecaTitle' : 'Meine Bibliothek',
      'multimediaTitle'   : 'Multimedia',
      'herramientasTitle' : 'Werkzeuge',
    },
    'Italiano': {
      'biblioteca'        : 'Libri',
      'audiolibros'       : 'Audiolibri 🎧',
      'videos'            : 'Video 🎬',
      'documentos'        : 'Documenti Word 📝',
      'estadisticas'      : 'Statistiche 📊',
      'config'            : 'Impostazioni',
      'descargar'         : 'Biblioteca pubblica',
      'musica'            : 'Musica per leggere 🎼',
      'leyendo'           : 'In lettura',
      'favoritos'         : 'Preferiti',
      'porLeer'           : 'Da leggere',
      'leidos'            : 'Letti',
      'agregar'           : 'Aggiungi',
      'buscarHint'        : 'Cerca libro...',
      'miBibliotecaTitle' : 'La mia biblioteca',
      'multimediaTitle'   : 'Multimedia',
      'herramientasTitle' : 'Strumenti',
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

  String get(String clave) =>
      _diccionarios[_idiomaActual]?[clave] ?? clave;

  static List<String> get idiomasDisponibles =>
      _diccionarios.keys.toList();
}
