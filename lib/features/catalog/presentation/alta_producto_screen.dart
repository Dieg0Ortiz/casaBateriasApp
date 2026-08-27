import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/presentation/auth_viewmodel.dart';
import '../../printing/print_models.dart';
import '../../printing/printer_screen.dart';
import '../../printing/ticket_builder.dart';
import '../domain/catalog_models.dart';
import 'catalogo_viewmodel.dart';

class AltaProductoScreen extends StatefulWidget {
  const AltaProductoScreen({super.key});

  @override
  State<AltaProductoScreen> createState() => _AltaProductoScreenState();
}

class _AltaProductoScreenState extends State<AltaProductoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _modelo = TextEditingController();
  final _descripcion = TextEditingController();
  final _precio = TextEditingController();
  final _precio2 = TextEditingController();
  final _precio3 = TextEditingController();
  final _codigoFabrica = TextEditingController();
  final _cantidadInicial = TextEditingController();

  String? _marcaId;
  String? _sucursalId;
  bool _requiereCasco = true;
  bool _usarCodigoFabrica = false;
  Producto? _creado;

  @override
  void dispose() {
    _modelo.dispose();
    _descripcion.dispose();
    _precio.dispose();
    _precio2.dispose();
    _precio3.dispose();
    _codigoFabrica.dispose();
    _cantidadInicial.dispose();
    super.dispose();
  }

  bool get _esAdmin =>
      context.read<AuthViewModel>().usuario?.esAdministrador == true;

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final p2 = _precio2.text.trim().isNotEmpty
        ? double.tryParse(_precio2.text.trim())
        : null;
    final p3 = _precio3.text.trim().isNotEmpty
        ? double.tryParse(_precio3.text.trim())
        : null;

    final vm = context.read<CatalogoViewModel>();
    final creado = await vm.crearProducto(
      NuevoProducto(
        marcaId: _marcaId!,
        modelo: _modelo.text.trim(),
        descripcion: _descripcion.text.trim(),
        precio: double.parse(_precio.text),
        precio2: p2,
        precio3: p3,
        requiereCasco: _requiereCasco,
        codigoBarrasFabrica: _usarCodigoFabrica
            ? _codigoFabrica.text.trim()
            : null,
        sucursalId: _esAdmin ? _sucursalId : null,
        cantidadInicial: _cantidadInicial.text.trim().isEmpty
            ? null
            : int.parse(_cantidadInicial.text.trim()),
      ),
    );

    if (creado != null) {
      setState(() => _creado = creado);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CatalogoViewModel>();
    final creado = _creado;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (creado != null) return _AltaExitosa(producto: creado);

    return Scaffold(
      appBar: AppBar(title: const Text('Alta de Producto')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.add_box_rounded, color: colors.primary),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Datos de la Batería',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Especificaciones técnicas y de cobro',
                              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: _marcaId,
                      decoration: const InputDecoration(
                        labelText: 'Marca',
                        prefixIcon: Icon(Icons.branding_watermark_outlined),
                      ),
                      items: vm.marcas
                          .map((m) => DropdownMenuItem(
                                value: m.id,
                                child: Text(m.nombre),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _marcaId = v),
                      validator: (v) => v == null ? 'Selecciona una marca' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _modelo,
                      decoration: const InputDecoration(
                        labelText: 'Modelo',
                        hintText: 'Ej. RedTop 34/78, NS60LS',
                        prefixIcon: Icon(Icons.electric_bolt_outlined),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Escribe el modelo' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descripcion,
                      decoration: const InputDecoration(
                        labelText: 'Descripción (opcional)',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _precio,
                      decoration: const InputDecoration(
                        labelText: 'Precio 1 (Default / Público) *',
                        prefixText: r'$ ',
                        prefixStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        prefixIcon: Icon(Icons.attach_money_rounded),
                      ),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        final valor = double.tryParse(v ?? '');
                        if (valor == null || valor <= 0) {
                          return 'Precio inválido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _precio2,
                            decoration: const InputDecoration(
                              labelText: 'Precio 2 (Opcional)',
                              hintText: 'Mayoreo',
                              prefixText: r'$ ',
                              prefixIcon: Icon(Icons.sell_outlined),
                            ),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              final valor = double.tryParse(v.trim());
                              if (valor == null || valor < 0) {
                                return 'Inválido';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _precio3,
                            decoration: const InputDecoration(
                              labelText: 'Precio 3 (Opcional)',
                              hintText: 'Especial',
                              prefixText: r'$ ',
                              prefixIcon: Icon(Icons.sell_outlined),
                            ),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              final valor = double.tryParse(v.trim());
                              if (valor == null || valor < 0) {
                                return 'Inválido';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Settings Bento Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Políticas & Código de Barras',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Requiere casco a cambio', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('Se cobrará el casco junto con la batería si el cliente no entrega el usado', style: TextStyle(fontSize: 12)),
                      value: _requiereCasco,
                      onChanged: (v) => setState(() => _requiereCasco = v),
                    ),
                    const Divider(height: 24),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Código de fábrica pre-impreso', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('Si se desactiva, el ERP generará un código único automáticamente', style: TextStyle(fontSize: 12)),
                      value: _usarCodigoFabrica,
                      onChanged: (v) => setState(() => _usarCodigoFabrica = v),
                    ),
                    if (_usarCodigoFabrica) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _codigoFabrica,
                        style: const TextStyle(fontFamily: 'monospace'),
                        decoration: const InputDecoration(
                          labelText: 'Código de fábrica',
                          hintText: 'CB…',
                          prefixIcon: Icon(Icons.qr_code_2_rounded),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Escribe el código de fábrica'
                            : null,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Inventory Bento Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Existencias Iniciales',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _cantidadInicial,
                      style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        labelText: 'Cantidad inicial (opcional)',
                        suffixText: 'uds',
                        prefixIcon: Icon(Icons.warehouse_outlined),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final n = int.tryParse(v);
                        if (n == null || n < 0) return 'Cantidad inválida';
                        return null;
                      },
                    ),
                    if (_esAdmin) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _sucursalId,
                        decoration: const InputDecoration(
                          labelText: 'Sucursal destino',
                          prefixIcon: Icon(Icons.storefront_outlined),
                        ),
                        items: vm.sucursales
                            .map((s) => DropdownMenuItem(
                                  value: s.id,
                                  child: Text(s.nombre),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _sucursalId = v),
                        validator: (v) =>
                            v == null ? 'Selecciona la sucursal' : null,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                minimumSize: const Size(double.infinity, 56),
              ),
              onPressed: vm.creando ? null : _guardar,
              icon: vm.creando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(vm.creando ? 'Guardando producto…' : 'Guardar Producto en Catálogo'),
            ),
            if (vm.mensajeError != null) ...[
              const SizedBox(height: 12),
              Text(
                vm.mensajeError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.error, fontWeight: FontWeight.w500),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _AltaExitosa extends StatelessWidget {
  const _AltaExitosa({required this.producto});

  final Producto producto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colores = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Producto Registrado')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, size: 48, color: Color(0xFF10B981)),
            ),
            const SizedBox(height: 16),
            Text(
              'Producto Dado de Alta',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              '${producto.marcaNombre} · ${producto.modelo}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: colores.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'CÓDIGO DE BARRAS',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.05,
                        color: colores.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      producto.codigoBarras,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: colores.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colores.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        producto.codigoDeFabrica
                            ? 'CÓDIGO DE FÁBRICA'
                            : 'GENERADO AUTOMÁTICAMENTE',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: colores.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
              ),
              icon: const Icon(Icons.print_rounded),
              label: const Text('Imprimir Etiqueta Térmica'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ImpresoraScreen(
                      titulo: 'etiqueta',
                      construir: () {
                        final etiqueta = EtiquetaBateria(
                          marca: producto.marcaNombre,
                          modelo: producto.modelo,
                          precio: producto.precio,
                          codigoBarras: producto.codigoBarras,
                        );
                        return TicketBuilder().etiqueta(etiqueta);
                      },
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Volver al Catálogo'),
            ),
          ],
        ),
      ),
    );
  }
}
