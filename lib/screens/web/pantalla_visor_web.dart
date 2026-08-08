import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/colors.dart';

class PantallaVisorWebCompleto extends StatefulWidget {
  final String url;
  final String titulo;

  const PantallaVisorWebCompleto({
    super.key,
    required this.url,
    required this.titulo,
  });

  @override
  State<PantallaVisorWebCompleto> createState() =>
      _PantallaVisorWebCompletoState();
}

class _PantallaVisorWebCompletoState extends State<PantallaVisorWebCompleto> {
  late final WebViewController _ctrl;
  bool   _cargando        = true;
  int    _progreso        = 0;
  String _urlActual       = '';

  @override
  void initState() {
    super.initState();
    _urlActual = widget.url;
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) setState(() { _cargando = true; _urlActual = url; });
          },
          onPageFinished: (_) {
            if (mounted) setState(() { _cargando = false; _progreso = 100; });
          },
          onProgress: (p) {
            if (mounted) setState(() => _progreso = p);
          },
          onNavigationRequest: (req) {
            // Bloquear esquemas externos y abrirlos con el sistema
            final url = req.url;
            if (url.startsWith('intent://') ||
                url.startsWith('market://') ||
                url.startsWith('whatsapp://') ||
                url.startsWith('tel:') ||
                url.startsWith('mailto:')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _intentarRetroceder() async {
    if (await _ctrl.canGoBack()) {
      await _ctrl.goBack();
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      appBar: AppBar(
        backgroundColor: ColoresApp.fondoDrawer,
        elevation      : 0,
        leading: IconButton(
          icon     : const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: _intentarRetroceder,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.titulo,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              _urlActual,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon     : const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: () => _ctrl.reload(),
          ),
          const SizedBox(width: 4),
        ],
        bottom: _cargando
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value           : _progreso / 100,
                  backgroundColor : Colors.white12,
                  valueColor      : const AlwaysStoppedAnimation(ColoresApp.acento),
                ),
              )
            : null,
      ),
      body: SafeArea(
        top: false,
        child: WebViewWidget(controller: _ctrl),
      ),
    );
  }
}
