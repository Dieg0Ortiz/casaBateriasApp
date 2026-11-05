import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:casabateriaserp/features/printing/printer_screen.dart';
import 'package:casabateriaserp/features/printing/printer_service.dart';

import 'support/plugin_impresora_falso.dart';

const _pregunta = 'Corta el ticket del cliente';

// Una sola prueba a propósito: el plugin abre su canal una vez por proceso y
// no sobrevive de un testWidgets a otro.
void main() {
  testWidgets('la copia solo sale cuando el cajero la pide', (tester) async {
    final plugin = PluginFalso()..instalar();
    PrinterService.instance.pedirPermisos = () async => true;
    PrinterService.instance.esperaDeEnvio = (_) => Duration.zero;
    FlutterSecureStorage.setMockInitialValues({
      'impresora_tickets':
          '{"name":"Termica","address":"AA:BB:CC:DD:EE:FF","type":1}',
    });

    Future<void> avanzar() async {
      for (var i = 0; i < 12; i++) {
        // Los mensajes del plugin falso llegan en tiempo real.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> tocarImprimir({required bool conCopia}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => imprimirDocumento(
                  context,
                  titulo: 'el ticket',
                  construir: () async => [1],
                  construirCopia: conCopia ? () async => [2] : null,
                ),
                child: const Text('imprimir'),
              ),
            ),
          ),
        ),
      );
      plugin.escrituras.clear();
      await tester.tap(find.text('imprimir'));
      await avanzar();
    }

    List<int> papeles() => plugin.escrituras.map((e) => e.first).toList();

    // Pide la copia: sale después, en otro envío.
    await tocarImprimir(conCopia: true);
    expect(papeles(), [1]);
    expect(find.text(_pregunta), findsOneWidget);
    await tester.tap(find.text('Imprimir copia'));
    await avanzar();
    expect(papeles(), [1, 2]);
    expect(find.text(_pregunta), findsNothing);

    // No la pide: no sale.
    await tocarImprimir(conCopia: true);
    await tester.tap(find.text('Sin copia'));
    await avanzar();
    expect(papeles(), [1]);

    // Un documento sin copia, como un corte, no pregunta nada.
    await tocarImprimir(conCopia: false);
    expect(papeles(), [1]);
    expect(find.text(_pregunta), findsNothing);

    expect(plugin.cierresDeApp, 0);
  });
}
