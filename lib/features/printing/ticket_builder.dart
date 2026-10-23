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

  /// Formatea un monto como "$1,234.50" sin depender de intl. Los negativos
  /// (un faltante de caja) salen como "-$123.00".
  static String moneda(double valor) {
    if (valor < 0 && valor.toStringAsFixed(2) != '-0.00') {
      return '-${moneda(-valor)}';
    }
    final fijo = valor.abs().toStringAsFixed(2);
    final partes = fijo.split('.');
    final entero = partes[0];
    final buffer = StringBuffer();
    for (var i = 0; i < entero.length; i++) {
      if (i > 0 && (entero.length - i) % 3 == 0) buffer.write(',');
      buffer.write(entero[i]);
    }
    return '\$$buffer.${partes[1]}';
  }

  /// Con [copia] el ticket lleva al final, en un solo renglón, para quién es
  /// ese papel: CLIENTE o COMERCIO (como los vouchers del banco). Sin [copia]
  /// no lleva leyenda.
  Future<List<int>> ticket(DatosTicket datos, {CopiaTicket? copia}) async {
    final perfil = await CapabilityProfile.load();
    final g = Generator(_papel, perfil);
    final bytes = <int>[...g.reset()];
    final reimpresion = datos.reimpresionNumero != null;

    if (reimpresion) {
      bytes.addAll(_leyendaReimpresion(g, datos));
    }

    bytes.addAll(_encabezadoNegocio(
      g,
      encabezado: datos.encabezado,
      propietario: datos.propietario,
      rfc: datos.rfc,
      sucursal: datos.sucursal,
      direccion: datos.direccionSucursal,
    ));

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
      final desc = nombreArticuloCompleto(linea.modelo, linea.marca);
      final lineasDesc = _dividirTexto(sanitizarTexto(desc), 18);
      final primeraLinea = lineasDesc.isNotEmpty ? lineasDesc.first : '';

      bytes.addAll(g.row([
        PosColumn(
          text: primeraLinea,
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

      // Si el nombre del artículo es largo (>18 caracteres), continuar en renglones siguientes
      if (lineasDesc.length > 1) {
        for (var i = 1; i < lineasDesc.length; i++) {
          bytes.addAll(g.text(
            '   ${lineasDesc[i]}',
            styles: const PosStyles(align: PosAlign.left),
          ));
        }
      }

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
    bytes.addAll(g.feed(1));
    bytes.addAll(g.text(
      sanitizarTexto('Solicitar factura el día de su compra'),
      styles: const PosStyles(bold: true, align: PosAlign.center),
    ));
    if (reimpresion) {
      bytes.addAll(g.feed(1));
      bytes.addAll(_leyendaReimpresion(g, datos));
    } else if (copia != null) {
      bytes.addAll(_leyendaCopia(g, copia));
    }
    bytes.addAll(g.feed(3));
    bytes.addAll(g.cut());

    return bytes;
  }

  /// Nombre del negocio, propietario, R.F.C. y datos de la sucursal.
  List<int> _encabezadoNegocio(
    Generator g, {
    required String encabezado,
    required String sucursal,
    String? propietario,
    String? rfc,
    String? direccion,
  }) {
    final bytes = <int>[];

    // ══════════════════════════════════════════
    // ENCABEZADO — Nombre de la empresa
    // ══════════════════════════════════════════
    bytes.addAll(g.text(
      _lineaDoble,
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(g.text(
      sanitizarTexto(encabezado),
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
    // DATOS DEL PROPIETARIO
    // ══════════════════════════════════════════
    if (propietario != null && propietario.isNotEmpty) {
      bytes.addAll(g.text(
        sanitizarTexto(propietario),
        styles: const PosStyles(align: PosAlign.center),
      ));
    }
    if (rfc != null && rfc.isNotEmpty) {
      bytes.addAll(g.text(
        'R.F.C. ${sanitizarTexto(rfc)}',
        styles: const PosStyles(align: PosAlign.center),
      ));
    }

    // ══════════════════════════════════════════
    // DATOS DE LA SUCURSAL
    // ══════════════════════════════════════════
    bytes.addAll(g.text(_linea, styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(g.text(
      'Sucursal: ${sanitizarTexto(sucursal)}',
      styles: const PosStyles(bold: true, align: PosAlign.center),
    ));
    final dirLimpia = limpiarDireccion(direccion ?? '');
    if (dirLimpia.isNotEmpty) {
      // Dividir dirección larga en líneas de ~32 caracteres para 58mm
      final lineasDir = _dividirTexto(sanitizarTexto(dirLimpia), 32);
      for (final ld in lineasDir) {
        bytes.addAll(g.text(
          ld,
          styles: const PosStyles(align: PosAlign.center),
        ));
      }
    }
    return bytes;
  }

  /// Corte de caja: uno por papel (efectivo, o tarjetas y transferencias).
  Future<List<int>> corte(DatosCorteTicket datos) async {
    final perfil = await CapabilityProfile.load();
    final g = Generator(_papel, perfil);
    final bytes = <int>[...g.reset()];

    bytes.addAll(g.text(_lineaDoble, styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(g.text(
      'CASA BATERIAS',
      styles: const PosStyles(bold: true, align: PosAlign.center),
    ));
    bytes.addAll(g.text(
      sanitizarTexto(datos.titulo),
      styles: const PosStyles(
        bold: true,
        align: PosAlign.center,
        height: PosTextSize.size2,
      ),
    ));
    bytes.addAll(g.text(_lineaDoble, styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(g.text('Sucursal: ${sanitizarTexto(datos.sucursal)}'));
    bytes.addAll(g.text('Apertura: ${sanitizarTexto(datos.apertura)}'));
    if (datos.abrio != null && datos.abrio!.isNotEmpty) {
      bytes.addAll(g.text('Abrio: ${sanitizarTexto(datos.abrio!)}'));
    }
    if (datos.cierre != null) {
      bytes.addAll(g.text('Cierre: ${sanitizarTexto(datos.cierre!)}'));
      if (datos.cerro != null && datos.cerro!.isNotEmpty) {
        bytes.addAll(g.text('Cerro: ${sanitizarTexto(datos.cerro!)}'));
      }
    } else {
      bytes.addAll(g.text(
        'CORTE PARCIAL (caja abierta)',
        styles: const PosStyles(bold: true),
      ));
    }
    bytes.addAll(g.text(_linea));

    for (final r in datos.renglones) {
      if (r.destacado) bytes.addAll(g.text(_linea));
      bytes.addAll(_renglonImporte(g, r.concepto, r.monto, negritas: r.destacado));
    }

    if (datos.operaciones.isNotEmpty) {
      bytes.addAll(g.text(_lineaDoble, styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(g.text(
        'OPERACIONES',
        styles: const PosStyles(bold: true, align: PosAlign.center),
      ));
      for (final o in datos.operaciones) {
        bytes.addAll(_renglonImporte(g, '${o.hora} ${o.descripcion}', o.monto));
      }
    }

    bytes.addAll(g.text(_lineaDoble, styles: const PosStyles(align: PosAlign.center)));
    if (datos.nota != null && datos.nota!.isNotEmpty) {
      for (final l in _dividirTexto(sanitizarTexto(datos.nota!), 32)) {
        bytes.addAll(g.text(l, styles: const PosStyles(align: PosAlign.center)));
      }
    }
    if (datos.conFirmas) {
      bytes.addAll(_renglonFirma(g, 'Entrego'));
      bytes.addAll(_renglonFirma(g, 'Recibio'));
    }
    bytes.addAll(g.feed(3));
    bytes.addAll(g.cut());
    return bytes;
  }

  /// Ticket de una devolución de dinero (folio DEV). La copia del comercio
  /// lleva renglón de firma del cliente: es su acuse de que recibió el dinero.
  Future<List<int>> devolucion(
    DatosDevolucionTicket datos, {
    CopiaTicket? copia,
  }) async {
    final perfil = await CapabilityProfile.load();
    final g = Generator(_papel, perfil);
    final bytes = <int>[...g.reset()];

    bytes.addAll(_encabezadoNegocio(
      g,
      encabezado: datos.encabezado,
      propietario: datos.propietario,
      rfc: datos.rfc,
      sucursal: datos.sucursal,
      direccion: datos.direccionSucursal,
    ));

    bytes.addAll(g.text(_lineaDoble, styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(g.text(
      'DEVOLUCION',
      styles: const PosStyles(
        bold: true,
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    ));
    bytes.addAll(g.text(
      sanitizarTexto(datos.tipo),
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(g.text(_linea));
    bytes.addAll(g.text(
      'Folio: ${sanitizarTexto(datos.folio)}',
      styles: const PosStyles(bold: true),
    ));
    bytes.addAll(g.text('Fecha: ${sanitizarTexto(datos.fecha)}'));
    bytes.addAll(g.text('Venta: ${sanitizarTexto(datos.ventaFolio)}'));
    if (datos.cliente != null && datos.cliente!.isNotEmpty) {
      bytes.addAll(g.text('Cliente: ${sanitizarTexto(datos.cliente!)}'));
    }
    if (datos.atendio != null && datos.atendio!.isNotEmpty) {
      bytes.addAll(g.text('Atendio: ${sanitizarTexto(datos.atendio!)}'));
    }
    if (datos.autorizo != null && datos.autorizo!.isNotEmpty) {
      bytes.addAll(g.text('Autorizo: ${sanitizarTexto(datos.autorizo!)}'));
    }

    if (datos.lineas.isNotEmpty) {
      bytes.addAll(g.text(_lineaDoble, styles: const PosStyles(align: PosAlign.center)));
      for (final l in datos.lineas) {
        bytes.addAll(_renglonImporte(g, '${l.cantidad} ${l.descripcion}', l.monto));
      }
    }

    bytes.addAll(g.text(_lineaDoble, styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(g.row([
      PosColumn(
        text: 'DEVUELTO',
        width: 6,
        styles: const PosStyles(bold: true, height: PosTextSize.size2),
      ),
      PosColumn(
        text: moneda(datos.monto),
        width: 6,
        styles: const PosStyles(
          bold: true,
          align: PosAlign.right,
          height: PosTextSize.size2,
        ),
      ),
    ]));
    bytes.addAll(g.text('Forma: ${sanitizarTexto(datos.metodo)}'));
    for (final l in _dividirTexto('Motivo: ${sanitizarTexto(datos.motivo)}', 32)) {
      bytes.addAll(g.text(l));
    }

    if (copia == CopiaTicket.comercio) {
      bytes.addAll(_renglonFirma(g, 'Recibi de conformidad'));
    }
    bytes.addAll(g.text(_lineaDoble, styles: const PosStyles(align: PosAlign.center)));
    if (copia != null) {
      bytes.addAll(_leyendaCopia(g, copia));
    }
    bytes.addAll(g.feed(3));
    bytes.addAll(g.cut());
    return bytes;
  }

  /// Espacio para firmar, la línea y debajo quién firma.
  List<int> _renglonFirma(Generator g, String leyenda) {
    return [
      ...g.feed(3),
      ...g.text(
        '______________________________',
        styles: const PosStyles(align: PosAlign.center),
      ),
      ...g.text(
        sanitizarTexto(leyenda),
        styles: const PosStyles(align: PosAlign.center),
      ),
    ];
  }

  /// Concepto a la izquierda e importe a la derecha; si el concepto es
  /// largo, sigue en los renglones de abajo.
  List<int> _renglonImporte(
    Generator g,
    String concepto,
    double monto, {
    bool negritas = false,
  }) {
    final partes = _dividirTexto(sanitizarTexto(concepto), 20);
    final bytes = <int>[
      ...g.row([
        PosColumn(
          text: partes.isEmpty ? '' : partes.first,
          width: 8,
          styles: PosStyles(bold: negritas),
        ),
        PosColumn(
          text: moneda(monto),
          width: 4,
          styles: PosStyles(bold: negritas, align: PosAlign.right),
        ),
      ]),
    ];
    for (final resto in partes.skip(1)) {
      bytes.addAll(g.text('  $resto', styles: PosStyles(bold: negritas)));
    }
    return bytes;
  }

  List<int> _leyendaReimpresion(Generator g, DatosTicket datos) {
    final numero = datos.reimpresionNumero ?? 1;
    return [
      ...g.text(_lineaDoble, styles: const PosStyles(align: PosAlign.center)),
      ...g.text(
        '*** REIMPRESION ***',
        styles: const PosStyles(
          bold: true,
          align: PosAlign.center,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
      ...g.text(
        'NO ES UN TICKET NUEVO',
        styles: const PosStyles(bold: true, align: PosAlign.center),
      ),
      ...g.text(
        'Autorizo: ${sanitizarTexto(datos.reimpresionAutorizo ?? '')}',
        styles: const PosStyles(align: PosAlign.center),
      ),
      ...g.text(
        'Motivo: ${sanitizarTexto(datos.reimpresionMotivo ?? '')}',
        styles: const PosStyles(align: PosAlign.center),
      ),
      ...g.text(
        'Reimpresion $numero',
        styles: const PosStyles(bold: true, align: PosAlign.center),
      ),
      ...g.text(_lineaDoble, styles: const PosStyles(align: PosAlign.center)),
    ];
  }

  List<int> _leyendaCopia(Generator g, CopiaTicket copia) {
    return g.text(
      copia.leyenda,
      styles: const PosStyles(bold: true, align: PosAlign.center),
    );
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

  /// Obtiene el nombre completo del artículo combinando marca y modelo sin duplicar si ya la incluye.
  static String nombreArticuloCompleto(String modelo, String? marca) {
    final mod = modelo.trim();
    final mrc = (marca ?? '').trim();
    if (mrc.isEmpty) return mod;
    if (mod.toLowerCase().contains(mrc.toLowerCase())) return mod;
    return '$mrc $mod';
  }

  /// Limpia nombres de dueño y RFC que pudieran estar incrustados accidentalmente en el campo de dirección.
  static String limpiarDireccion(String direccion) {
    var limpia = direccion;
    limpia = limpia.replaceAll(RegExp(r'Joaquin\s+Gabriel\s+Estrada\s+Marquez', caseSensitive: false), '');
    limpia = limpia.replaceAll(RegExp(r'R\.?F\.?C\.?\s*[:\s]*EAMJ-?760228-?E21', caseSensitive: false), '');
    limpia = limpia.trim();
    while (limpia.startsWith(',') || limpia.startsWith('-') || limpia.startsWith('.')) {
      limpia = limpia.substring(1).trim();
    }
    return limpia;
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
