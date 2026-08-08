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

  AjustesApp({
    this.tipoFondo              = 'defecto',
    this.rutaFondoSeleccionado  = 'assets/images/fondo1.jpg',
    this.colorSolidoId,
    this.modoOscuro             = true,
    this.nivelBrillo            = 1.0,
    this.filtroLuzAzul          = false,
    this.modoSepia              = false,
    this.volumenEfecto          = 0.8,
    this.intensidadFiltro       = 0.2,
    this.velocidadVoz           = 1.0,
    this.sonidoActivado         = true,
    this.nombreSonidoActual     = 'Local Predeterminado',
    this.rutaSonidoPersonalizado,
    this.ordenBiblioteca        = 'Recientes',
    this.idioma                 = 'Español',
  });
}
