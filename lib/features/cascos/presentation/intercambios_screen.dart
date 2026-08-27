import '../../../../core/utils/date_formatters.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'intercambios_viewmodel.dart';
import 'nuevo_intercambio_screen.dart';
import '../domain/intercambio_models.dart';

class IntercambiosScreen extends StatefulWidget {
  const IntercambiosScreen({super.key});

  @override
  State<IntercambiosScreen> createState() => _IntercambiosScreenState();
}

class _IntercambiosScreenState extends State<IntercambiosScreen> {
  final _searchController = TextEditingController();
  final _moneda = NumberFormat.currency(locale: 'es_MX', symbol: r'$');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IntercambiosViewModel>().cargar();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<IntercambiosViewModel>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final lista = vm.intercambiosFiltrados;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Intercambio de Cascos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: vm.cargando ? null : () => vm.cargar(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const NuevoIntercambioScreen(),
            ),
          );
        },
        icon: const Icon(Icons.swap_horiz_rounded),
        label: const Text('Nuevo Intercambio'),
      ),
      body: RefreshIndicator(
        onRefresh: () => vm.cargar(),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Tarjeta KPI
                    Card(
                      elevation: 0,
                      color: colors.primaryContainer.withValues(alpha: 0.35),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: colors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.currency_exchange_rounded, color: colors.primary, size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ganancia Total Trueques',
                                    style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                                  ),
                                  Text(
                                    _moneda.format(vm.totalGanancia),
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: colors.primary,
                                    ),
                                  ),
                                  Text(
                                    '${vm.intercambios.length} intercambios registrados (\$150 c/u)',
                                    style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Buscador
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Buscar folio, cliente, modelo...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  vm.setFiltro('');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: vm.setFiltro,
                    ),
                  ],
                ),
              ),
            ),
            if (vm.cargando && vm.intercambios.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (vm.error != null && vm.intercambios.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: colors.error),
                        const SizedBox(height: 12),
                        Text(vm.error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton.tonal(
                          onPressed: () => vm.cargar(),
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (lista.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swap_horizontal_circle_outlined, size: 64, color: colors.outline),
                      const SizedBox(height: 12),
                      Text(
                        'No hay intercambios registrados',
                        style: TextStyle(color: colors.onSurfaceVariant, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Toca el botón para registrar el primer intercambio',
                        style: TextStyle(color: colors.outline, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = lista[index];
                      final primerItem = item.items.isNotEmpty ? item.items.first : null;
                      final cant = primerItem?.cantidad ?? 1;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _mostrarDetalle(context, item),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: colors.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item.folio,
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: colors.primary,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _moneda.format(item.montoCobrado),
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Color(0xFF16A34A),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // Trueque Visual
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceContainerLowest,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'SE LLEVÓ (Saliente)',
                                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              primerItem?.cascoSalienteModelo ?? 'Casco',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              'Cant: $cant',
                                              style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 8),
                                        child: Icon(Icons.swap_horiz_rounded, color: Colors.grey, size: 22),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'ENTREGÓ (Entrante)',
                                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              primerItem?.cascoEntranteModelo ?? 'Casco',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              'Cant: $cant',
                                              style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      item.sucursalNombre ?? 'Sucursal',
                                      style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                                    ),
                                    Text(
                                      formatFechaHora(item.createdAt),
                                      style: TextStyle(fontSize: 11, color: colors.outline),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: lista.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _mostrarDetalle(BuildContext context, IntercambioCasco item) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Comprobante de Trueque',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.folio,
                    style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: colors.primary),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _ItemInfo(label: 'Fecha y Hora', value: formatFechaHora(item.createdAt)),
            _ItemInfo(label: 'Sucursal', value: item.sucursalNombre ?? '—'),
            _ItemInfo(label: 'Registrado por', value: item.usuarioNombre ?? 'Personal'),
            _ItemInfo(label: 'Método de Pago', value: item.metodoPago.toUpperCase()),
            if (item.clienteNombre != null && item.clienteNombre!.isNotEmpty)
              _ItemInfo(label: 'Cliente', value: '${item.clienteNombre!} ${item.clienteTelefono != null ? "(${item.clienteTelefono})" : ""}'),
            if (item.notas != null && item.notas!.isNotEmpty)
              _ItemInfo(label: 'Notas', value: item.notas!),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Monto Cobrado (Ganancia)', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    _moneda.format(item.montoCobrado),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cerrar'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}

class _ItemInfo extends StatelessWidget {
  const _ItemInfo({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
