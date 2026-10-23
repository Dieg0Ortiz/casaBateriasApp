import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/date_formatters.dart';
import '../../printing/print_models.dart';
import '../../printing/printer_screen.dart';
import '../../printing/ticket_builder.dart';
import '../data/sales_remote_data_source.dart';

/// Reimpresión de un ticket ya cobrado. No está en el flujo de cobro:
/// pide folio, motivo y la clave de un administrador. El papel sale
/// marcado como reimpresión.
class ReimpresionScreen extends StatefulWidget {
  const ReimpresionScreen({super.key});

  @override
  State<ReimpresionScreen> createState() => _ReimpresionScreenState();
}

class _ReimpresionScreenState extends State<ReimpresionScreen> {
  final _folio = TextEditingController();
  final _motivo = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _ventas = SalesRemoteDataSource();

  bool _autorizando = false;
  String? _error;
  _Reimpresion? _autorizada;

  @override
  void dispose() {
    _folio.dispose();
    _motivo.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _autorizar() async {
    setState(() {
      _autorizando = true;
      _error = null;
      _autorizada = null;
    });
    try {
      final json = await _ventas.autorizarReimpresion(
        folio: _folio.text.trim(),
        motivo: _motivo.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      setState(() => _autorizada = _Reimpresion.fromJson(json));
      _password.clear();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo autorizar la reimpresión.');
    } finally {
      if (mounted) setState(() => _autorizando = false);
    }
  }

  Future<List<int>> _ticket(_Reimpresion datos) {
    return TicketBuilder().ticket(
      DatosTicket(
        encabezado: 'CASA BATERIAS',
        sucursal: datos.sucursal,
        direccionSucursal: datos.direccion,
        propietario: 'Joaquin Gabriel Estrada Marquez',
        rfc: 'EAMJ-760228-E21',
        folio: datos.folio,
        fecha: formatFechaHora(datos.vendidaEn),
        empleado: datos.empleado,
        metodoPago: datos.metodoPago,
        lineas: datos.lineas,
        total: datos.total,
        reimpresionNumero: datos.numero,
        reimpresionAutorizo: datos.autorizo,
        reimpresionMotivo: datos.motivo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final lista = _autorizada;

    return Scaffold(
      appBar: AppBar(title: const Text('Reimprimir ticket')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            'Esto no cobra de nuevo. Hace falta el folio, el motivo y la clave de un administrador. El papel sale marcado como reimpresión.',
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.35),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _folio,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Folio de la venta',
              hintText: 'NV-MAT-000177',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _motivo,
            decoration: const InputDecoration(
              labelText: 'Por qué se reimprime',
              hintText: 'La impresora no sacó el ticket',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Correo del administrador',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Contraseña del administrador',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _autorizando ? null : _autorizar,
            child: Text(_autorizando ? 'Verificando…' : 'Pedir autorización'),
          ),
          if (lista != null) ...[
            const SizedBox(height: 22),
            Text(
              'Reimpresión ${lista.numero} autorizada por ${lista.autorizo}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text('${lista.folio} · ${lista.sucursal}'),
            Text(lista.metodoPago),
            const SizedBox(height: 8),
            for (final linea in lista.lineas)
              Text(
                '${linea.marca ?? ''} ${linea.modelo}  x${linea.cantidad}'.trim(),
              ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => imprimirDocumento(
                context,
                titulo: 'reimpresión ${lista.folio}',
                construir: () => _ticket(lista),
              ),
              icon: const Icon(Icons.print_rounded),
              label: const Text('Imprimir ticket marcado'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Reimpresion {
  _Reimpresion({
    required this.numero,
    required this.autorizo,
    required this.motivo,
    required this.folio,
    required this.total,
    required this.vendidaEn,
    required this.metodoPago,
    required this.sucursal,
    required this.direccion,
    required this.empleado,
    required this.lineas,
  });

  final int numero;
  final String autorizo;
  final String motivo;
  final String folio;
  final double total;
  final DateTime? vendidaEn;
  final String metodoPago;
  final String sucursal;
  final String? direccion;
  final String? empleado;
  final List<LineaTicket> lineas;

  factory _Reimpresion.fromJson(Map<String, dynamic> json) {
    final venta = json['venta'] as Map<String, dynamic>? ?? {};
    final items = (venta['items'] as List<dynamic>? ?? []);
    return _Reimpresion(
      numero: (json['numero'] as num?)?.toInt() ?? 1,
      autorizo: json['autorizo'] as String? ?? '',
      motivo: json['motivo'] as String? ?? '',
      folio: venta['folio'] as String? ?? '',
      total: (venta['total'] as num?)?.toDouble() ?? 0,
      vendidaEn: DateTime.tryParse(venta['created_at'] as String? ?? ''),
      metodoPago: _metodo(venta['metodo_pago'] as String? ?? 'efectivo'),
      sucursal: venta['sucursal'] as String? ?? '',
      direccion: venta['direccion'] as String?,
      empleado: venta['empleado'] as String?,
      lineas: items.map((raw) {
        final item = raw as Map<String, dynamic>;
        return LineaTicket(
          marca: item['marca'] as String?,
          modelo: item['modelo'] as String? ?? 'Producto',
          cantidad: (item['cantidad'] as num?)?.toInt() ?? 1,
          precio: (item['precio_unitario'] as num?)?.toDouble() ?? 0,
          conCasco: item['con_casco'] as bool?,
          tipoPrecio: item['tipo_precio'] as String?,
          comisionCasco: (item['comision_casco'] as num?)?.toDouble(),
        );
      }).toList(),
    );
  }

  static String _metodo(String metodo) {
    switch (metodo) {
      case 'tarjeta_debito':
        return 'Tarjeta Debito';
      case 'tarjeta_credito':
        return 'Tarjeta Credito';
      case 'transferencia':
        return 'Transferencia';
      case 'mixto':
        return 'Pago Mixto';
      case 'credito':
        return 'Credito';
      default:
        return 'Efectivo';
    }
  }
}
