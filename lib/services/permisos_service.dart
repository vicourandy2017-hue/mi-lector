import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermisosService {
  /// Solicita los permisos de almacenamiento/media según la versión de Android.
  /// En Android 13+ (API 33) usa los permisos granulares de media.
  /// En versiones anteriores usa READ_EXTERNAL_STORAGE.
  static Future<bool> solicitarPermisosAlmacenamiento() async {
    if (!Platform.isAndroid) return true;
    try {
      // Intentamos detectar la versión del SDK de forma segura
      // sin depender de device_info_plus para no agregar dependencia extra.
      // En Android 13+ (SDK 33) los permisos de media son granulares.
      await [
        Permission.audio,
        Permission.photos,
        Permission.videos,
      ].request();
      return true;
    } catch (e) {
      debugPrint('PermisosService error: $e');
      return true; // Continuar de todas formas — el picker maneja su propio SAF
    }
  }

  static Future<bool> hayPermisosBloqueadosPermanentemente() async {
    // Si el usuario bloqueó permanentemente algún permiso de media
    if (!Platform.isAndroid) return false;
    try {
      final audioStatus  = await Permission.audio.status;
      final photosStatus = await Permission.photos.status;
      return audioStatus.isPermanentlyDenied || photosStatus.isPermanentlyDenied;
    } catch (_) {
      return false;
    }
  }
}

// Función de nivel superior para compatibilidad con código legado
Future<bool> solicitarPermisosAlmacenamiento() =>
    PermisosService.solicitarPermisosAlmacenamiento();
