import 'package:esc_pos_utils/esc_pos_utils.dart';

import 'print_models.dart';

/// Construye los bytes ESC/POS de un ticket de venta y de una etiqueta de
/// código de barras (Fase 9). No depende de Flutter ni del plugin Bluetooth,
/// por lo que es 100% testeable.
class TicketBuilder {
  /// Papel térmico de 58 mm (ancho estándar de las impresoras portátiles).
  final PaperSize _papel;

  TicketBuilder([this._papel = PaperSize.mm58]);

  static const String _linea = '--------------------------------';
  static const String _lineaDoble = '================================';

  /// Remueve acentos, tildes y caracteres especiales para garantizar compatibilidad
  /// con impresoras térmicas ESC/POS estándar (evita caracteres corruptos como '=' o '?').
  static String sanitizarTexto(String texto) {
    if (texto.isEmpty) return texto;
    const mapa = {
      'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', 'å': 'a',
      'Á': 'A', 'À': 'A', 'Ä': 'A', 'Â': 'A', 'Ã': 'A', 'Å': 'A',
      'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
      'É': 'E', 'È': 'E', 'Ë': 'E', 'Ê': 'E',
      'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
      'Í': 'I', 'Ì': 'I', 'Ï': 'I', 'Î': 'I',
      'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
      'Ó': 'O', 'Ò': 'O', 'Ö': 'O', 'Ô': 'O', 'Õ': 'O',
      'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
      'Ú': 'U', 'Ù': 'U', 'Ü': 'U', 'Û': 'U',
      'ñ': 'n', 'Ñ': 'N',
      'ç': 'c', 'Ç': 'C',
      '¡': '', '¿': '',
      '’': "'", '‘': "'",
      '“': '"', '”': '"',
      '–': '-', '—': '-',
      '…': '...',
    };
    final buffer = StringBuffer();
    for (var i = 0; i < texto.length; i++) {
      final char = texto[i];
      buffer.write(mapa[char] ?? char);
    }
    return buffer.toString();
  }

  /// Formatea un monto como "$1,234.50" sin depender de intl.
  static String moneda(double valor) {
    final fijo = valor.toStringAsFixed(2);
    final partes = fijo.split('.');
    final entero = partes[0];
    final buffer = StringBuffer();
    for (var i = 0; i < entero.length; i++) {
      if (i > 0 && (entero.length - i) % 3 == 0) buffer.write(',');
      buffer.write(entero[i]);
    }
    return '\$$buffer.${partes[1]}';
  }

  Future<List<int>> ticket(DatosTicket datos) async {
    final perfil = await CapabilityProfile.load();
    final g = Generator(_papel, perfil);
    final bytes = <int>[...g.reset()];

    // ══════════════════════════════════════════
    // ENCABEZADO — Nombre de la empresa
    // ══════════════════════════════════════════
    bytes.addAll(g.text(
      _lineaDoble,
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(g.text(
      sanitizarTexto(datos.encabezado),
      styles: const PosStyles(
        bold: true,
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    ));
    bytes.addAll(g.text(
      _lineaDoble,
      styles: const PosStyles(align: PosAlign.center),
    ));

    // ══════════════════════════════════════════
    // DATOS DEL PROPIETARIO (condicional)
    // ══════════════════════════════════════════
    final direccion = datos.direccionSucursal ?? '';
    final dirLower = direccion.toLowerCase();
    // Si la dirección ya contiene datos del dueño, no los duplicamos.
    final yaTieneDueno = dirLower.contains('joaquin') ||
        dirLower.contains('eamj');

    if (!yaTieneDueno &&
        datos.propietario != null &&
        datos.propietario!.isNotEmpty) {
      bytes.addAll(g.text(
        sanitizarTexto(datos.propietario!),
        styles: const PosStyles(align: PosAlign.center),
      ));
    }
    if (!yaTieneDueno && datos.rfc != null && datos.rfc!.isNotEmpty) {
      bytes.addAll(g.text(
        'R.F.C. ${sanitizarTexto(datos.rfc!)}',
        styles: const PosStyles(align: PosAlign.center),
      ));
    }

    // ══════════════════════════════════════════
    // DATOS DE LA SUCURSAL
    // ══════════════════════════════════════════
    bytes.addAll(g.text(_linea, styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(g.text(
      'Sucursal: ${sanitizarTexto(datos.sucursal)}',
      styles: const PosStyles(bold: true, align: PosAlign.center),
    ));
    if (direccion.isNotEmpty) {
      // Dividir dirección larga en líneas de ~32 caracteres para 58mm
      final lineasDir = _dividirTexto(sanitizarTexto(direccion), 32);
      for (final ld in lineasDir) {
        bytes.addAll(g.text(
          ld,
          styles: const PosStyles(align: PosAlign.center),
        ));
      }
    }

    // ══════════════════════════════════════════
    // DATOS DE LA VENTA
    // ══════════════════════════════════════════
    bytes.addAll(g.text(_linea, styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(g.text('Folio: ${sanitizarTexto(datos.folio)}'));
    bytes.addAll(g.text('Fecha: ${sanitizarTexto(datos.fecha)}'));
    if (datos.empleado != null && datos.empleado!.isNotEmpty) {
      bytes.addAll(g.text('Atendio: ${sanitizarTexto(datos.empleado!)}'));
    }
    if (datos.metodoPago != null && datos.metodoPago!.isNotEmpty) {
      bytes.addAll(g.text('Pago: ${sanitizarTexto(datos.metodoPago!)}'));
    }

    // ══════════════════════════════════════════
    // TABLA DE PRODUCTOS
    // ══════════════════════════════════════════
    bytes.addAll(g.text(_lineaDoble, styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(g.row([
      PosColumn(
        text: 'Articulo',
        width: 7,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: 'Cant',
        width: 2,
        styles: const PosStyles(bold: true, align: PosAlign.right),
      ),
      PosColumn(
        text: 'Importe',
        width: 3,
        styles: const PosStyles(bold: true, align: PosAlign.right),
      ),
    ]));
    bytes.addAll(g.text(_linea));

    for (final linea in datos.lineas) {
      bytes.addAll(g.row([
        PosColumn(
          text: _recortar(linea.modelo, 20),
          width: 7,
        ),
        PosColumn(
          text: '${linea.cantidad}',
          width: 2,
          styles: const PosStyles(align: PosAlign.right),
        ),
        PosColumn(
          text: moneda(linea.importe),
          width: 3,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));
      if (linea.tipoPrecio != null && linea.tipoPrecio != 'default') {
        final optNombre = linea.tipoPrecio == 'precio_especial'
            ? 'Precio Especial'
            : linea.tipoPrecio == 'precio_2'
                ? 'Precio 2'
                : 'Precio 3';
        bytes.addAll(g.text(
          '   ($optNombre)',
          styles: const PosStyles(align: PosAlign.left),
        ));
      }
      if (linea.conCasco != null) {
        if (linea.conCasco!) {
          bytes.addAll(g.text(
            '   (con casco / a cambio)',
            styles: const PosStyles(align: PosAlign.left),
          ));
        } else {
          final comisionStr = (linea.comisionCasco != null && linea.comisionCasco! > 0)
              ? ' (+${moneda(linea.comisionCasco!)} dep)'
              : '';
          bytes.addAll(g.text(
            '   (sin casco$comisionStr)',
            styles: const PosStyles(align: PosAlign.left),
          ));
          bytes.addAll(g.text(
            '   * 15 dias para devolucion',
            styles: const PosStyles(align: PosAlign.left),
          ));
        }
      }
    }

    // ══════════════════════════════════════════
    // TOTAL
    // ══════════════════════════════════════════
    bytes.addAll(g.text(_lineaDoble, styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(g.row([
      PosColumn(
        text: 'TOTAL',
        width: 6,
        styles: const PosStyles(bold: true, height: PosTextSize.size2),
      ),
      PosColumn(
        text: moneda(datos.total),
        width: 6,
        styles: const PosStyles(
          bold: true,
          align: PosAlign.right,
          height: PosTextSize.size2,
        ),
      ),
    ]));
    bytes.addAll(g.text(
      'Importe en Pesos M.N.',
      styles: const PosStyles(align: PosAlign.center),
    ));

    // ══════════════════════════════════════════
    // PIE DE TICKET
    // ══════════════════════════════════════════
    bytes.addAll(g.text(_lineaDoble, styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(g.feed(1));
    bytes.addAll(g.text(
      'Gracias por su compra!',
      styles: const PosStyles(bold: true, align: PosAlign.center),
    ));
    bytes.addAll(g.text(
      'Casa Baterias',
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(g.text(
      'Conserve su ticket',
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(g.feed(3));
    bytes.addAll(g.cut());

    return bytes;
  }

  Future<List<int>> etiqueta(EtiquetaBateria etiqueta) async {
    final perfil = await CapabilityProfile.load();
    final g = Generator(_papel, perfil);
    final bytes = <int>[...g.reset()];

    bytes.addAll(g.text(
      sanitizarTexto(etiqueta.marca),
      styles: const PosStyles(bold: true, align: PosAlign.center),
    ));
    bytes.addAll(g.text(
      sanitizarTexto(etiqueta.modelo),
      styles: const PosStyles(
        bold: true,
        align: PosAlign.center,
        height: PosTextSize.size2,
      ),
    ));
    bytes.addAll(g.text(
      moneda(etiqueta.precio),
      styles: const PosStyles(
        bold: true,
        align: PosAlign.center,
        height: PosTextSize.size2,
      ),
    ));
    bytes.addAll(g.text(_linea, styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(g.feed(1));
    bytes.addAll(g.barcode(
      Barcode.code128('{B${sanitizarTexto(etiqueta.codigoBarras)}'.split('')),
      width: 2,
      height: 90,
      font: BarcodeFont.fontB,
      textPos: BarcodeText.below,
      align: PosAlign.center,
    ));
    bytes.addAll(g.text(
      sanitizarTexto(etiqueta.codigoBarras),
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(g.feed(2));
    bytes.addAll(g.cut());

    return bytes;
  }

  /// Limita el texto a [max] caracteres y sanitiza tildes/caracteres especiales.
  static String _recortar(String texto, int max) {
    final limpio = sanitizarTexto(texto);
    if (limpio.length <= max) return limpio;
    return limpio.substring(0, max);
  }

  /// Divide un texto largo en líneas de máximo [ancho] caracteres,
  /// cortando por espacios para no romper palabras.
  static List<String> _dividirTexto(String texto, int ancho) {
    if (texto.length <= ancho) return [texto];
    final palabras = texto.split(' ');
    final lineas = <String>[];
    var actual = StringBuffer();
    for (final palabra in palabras) {
      if (actual.isEmpty) {
        actual.write(palabra);
      } else if (actual.length + 1 + palabra.length <= ancho) {
        actual.write(' $palabra');
      } else {
        lineas.add(actual.toString());
        actual = StringBuffer(palabra);
      }
    }
    if (actual.isNotEmpty) lineas.add(actual.toString());
    return lineas;
  }
}
