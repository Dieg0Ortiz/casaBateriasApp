import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'intercambios_viewmodel.dart';
import '../domain/intercambio_models.dart';
import '../../auth/presentation/auth_viewmodel.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../catalog/presentation/catalogo_viewmodel.dart';

class NuevoIntercambioScreen extends StatefulWidget {
  const NuevoIntercambioScreen({super.key});

  @override
  State<NuevoIntercambioScreen> createState() => _NuevoIntercambioScreenState();
}

class _NuevoIntercambioScreenState extends State<NuevoIntercambioScreen> {
  Producto? _saliente;
  Producto? _entrante;
  int _cantidad = 1;
  double _tarifa = 150.0;
  String _metodoPago = 'efectivo';
  final _clienteController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _notasController = TextEditingController();
  final _moneda = NumberFormat.currency(locale: 'es_MX', symbol: r'$');
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final catVm = context.read<CatalogoViewModel>();
      if (catVm.productos.isEmpty) catVm.cargar();
    });
  }

  @override
  void dispose() {
    _clienteController.dispose();
    _telefonoController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  double get _total => _cantidad * _tarifa;

  int _stockCascos(Producto? p, String sucursalId) {
    if (p == null || sucursalId.isEmpty) return 0;
    try {
      final ex = p.existencias.firstWhere((e) => e.sucursalId == sucursalId);
      return ex.cascosDisponibles;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final catVm = context.watch<CatalogoViewModel>();
    final sucursalId = authVm.usuario?.sucursalId ?? '';
    final baterias = catVm.productos;
    final stockSaliente = _stockCascos(_saliente, sucursalId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Intercambio'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _enviando || _saliente == null || _entrante == null ? null : _guardar,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _enviando
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    'Confirmar y Cobrar ${_moneda.format(_total)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Selector Casco Saliente
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.arrow_upward_rounded, color: Color(0xFFEF4444), size: 18),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Casco Saliente (Se lleva el cliente)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      if (_saliente != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: stockSaliente >= _cantidad
                                ? const Color(0xFF16A34A).withValues(alpha: 0.15)
                                : const Color(0xFFEF4444).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Stock: $stockSaliente cascos',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: stockSaliente >= _cantidad ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Producto>(
                    initialValue: _saliente,
                    isExpanded: true,
                    decoration: InputDecoration(
                      hintText: 'Seleccionar batería de inventario',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: baterias.map((b) {
                      final stock = _stockCascos(b, sucursalId);
                      return DropdownMenuItem(
                        value: b,
                        child: Text('${b.marcaNombre} ${b.modelo} ($stock cascos)'),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _saliente = val),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Selector Casco Entrante
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.arrow_downward_rounded, color: Color(0xFF16A34A), size: 18),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Casco Entrante (Deja el cliente)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Producto>(
                    initialValue: _entrante,
                    isExpanded: true,
                    decoration: InputDecoration(
                      hintText: 'Seleccionar modelo recibido',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: baterias.map((b) {
                      return DropdownMenuItem(
                        value: b,
                        child: Text('${b.marcaNombre} ${b.modelo}'),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _entrante = val),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Cantidad y Cobro
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Cantidad', style: TextStyle(fontSize: 12)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            IconButton.filledTonal(
                              icon: const Icon(Icons.remove, size: 18),
                              onPressed: _cantidad > 1 ? () => setState(() => _cantidad--) : null,
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  '$_cantidad',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            IconButton.filledTonal(
                              icon: const Icon(Icons.add, size: 18),
                              onPressed: () => setState(() => _cantidad++),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Cobro Unitario', style: TextStyle(fontSize: 12)),
                        const SizedBox(height: 6),
                        TextFormField(
                          initialValue: '150.00',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            prefixText: r'$ ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _tarifa = double.tryParse(val) ?? 150.0;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Método de Pago
          const Text('Método de Pago', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'efectivo', label: Text('Efectivo'), icon: Icon(Icons.money)),
              ButtonSegment(value: 'tarjeta', label: Text('Tarjeta'), icon: Icon(Icons.credit_card)),
              ButtonSegment(value: 'transferencia', label: Text('Transf.'), icon: Icon(Icons.account_balance)),
            ],
            selected: {_metodoPago},
            onSelectionChanged: (set) => setState(() => _metodoPago = set.first),
          ),
          const SizedBox(height: 14),

          // Datos del Cliente (Obligatorios)
          TextField(
            controller: _clienteController,
            decoration: InputDecoration(
              labelText: 'Nombre del Cliente *',
              hintText: 'Ingresa el nombre completo',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              prefixIcon: const Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _telefonoController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Teléfono del Cliente *',
              hintText: 'Ej. 6671234567',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notasController,
            decoration: InputDecoration(
              labelText: 'Observaciones / Notas (Opcional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              prefixIcon: const Icon(Icons.notes_outlined),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _guardar() async {
    final authVm = context.read<AuthViewModel>();
    final sucursalId = authVm.usuario?.sucursalId;

    if (sucursalId == null || sucursalId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay sucursal activa en la sesión')),
      );
      return;
    }

    final nombreCliente = _clienteController.text.trim();
    final telefonoCliente = _telefonoController.text.trim();

    if (nombreCliente.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El nombre del cliente es obligatorio'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (telefonoCliente.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El teléfono del cliente es obligatorio'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _enviando = true);

    final input = RegistrarIntercambioInput(
      sucursalId: sucursalId,
      metodoPago: _metodoPago,
      montoCobrado: _total,
      clienteNombre: nombreCliente,
      clienteTelefono: telefonoCliente,
      notas: _notasController.text.trim().isNotEmpty ? _notasController.text.trim() : null,
      items: [
        {
          'casco_saliente_id': _saliente!.id,
          'casco_entrante_id': _entrante!.id,
          'cantidad': _cantidad,
          'precio_unitario': _tarifa,
        },
      ],
    );

    final ok = await context.read<IntercambiosViewModel>().registrarIntercambio(input);
    setState(() => _enviando = false);

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Intercambio registrado con éxito. Cobro: ${_moneda.format(_total)}'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
      Navigator.of(context).pop();
    } else if (mounted) {
      final error = context.read<IntercambiosViewModel>().error ?? 'Error al registrar intercambio';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }
}
