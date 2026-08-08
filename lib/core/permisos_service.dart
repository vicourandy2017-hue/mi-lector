import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Servicio centralizado de gestión de permisos para Android 10, 11, 12, 13, 14 y 15.
/// Cumple con las políticas actualizadas de Google Play Console.
class PermisosService {
  /// Solicita los permisos necesarios según la versión de Android.
  static Future<bool> solicitarPermisosAlmacenamientoYMedia() async {
    if (!Platform.isAndroid) return true;

    try {
      // 1. Android 13+ (API level >= 33): Permisos granulares de media
      final statusAudio = await Permission.audio.request();
      final statusVideos = await Permission.videos.request();
      final statusPhotos = await Permission.photos.request();

      // 2. Android 12 o inferior: Permiso tradicional de almacenamiento
      final statusStorage = await Permission.storage.request();

      final concedido = statusAudio.isGranted ||
          statusVideos.isGranted ||
          statusPhotos.isGranted ||
          statusStorage.isGranted ||
          statusStorage.isLimited;

      return concedido;
    } catch (e) {
      debugPrint('PermisosService: aviso al solicitar permisos: $e');
      return true; // En la mayoría de dispositivos, SAF (Storage Access Framework) permite seleccionar archivos sin depender exclusivamente de estos permisos.
    }
  }

  /// Verificación rápida de estado para la UI.
  static Future<bool> tienePermisosMedia() async {
    if (!Platform.isAndroid) return true;

    final isAudioGranted = await Permission.audio.isGranted;
    final isStorageGranted = await Permission.storage.isGranted;

    return isAudioGranted || isStorageGranted;
  }
}
