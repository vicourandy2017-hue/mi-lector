// Test básico de arranque para Mi Lector Pro.
//
// Verifica que la app inicia correctamente y muestra la pantalla principal
// de la biblioteca, sin quedarse "pegada" en un error de construcción.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mi_lector/main.dart';

void main() {
  testWidgets('Mi Lector Pro inicia y muestra la biblioteca', (WidgetTester tester) async {
    // Construye la app y dispara un frame.
    await tester.pumpWidget(const MiLectorApp());

    // Deja que las tareas asíncronas iniciales (cargar SharedPreferences, etc.)
    // terminen antes de verificar la interfaz.
    await tester.pumpAndSettle();

    // Verifica que aparece el título de la sección inicial de la biblioteca.
    expect(find.text('Libros y documentos'), findsOneWidget);

    // Verifica que el botón para agregar libros está presente.
    expect(find.text('Agregar libro'), findsOneWidget);
  });
}