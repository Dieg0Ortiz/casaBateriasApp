import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/creditos_remote_data_source.dart';
import '../domain/credito_models.dart';

class CreditosScreen extends StatefulWidget {
  const CreditosScreen({super.key});

  @override
  State<CreditosScreen> createState() => _CreditosScreenState();
}

class _CreditosScreenState extends State<CreditosScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CreditosRemoteDataSource _dataSource = CreditosRemoteDataSource();
  final NumberFormat _moneda = NumberFormat.currency(locale: 'es_MX', symbol: r'$');

  List<EmpresaCredito> _empresas = [];
  List<CreditoVenta> _ventas = [];
  bool _cargando = true;
  String? _error;

  String _busqueda = '';
  String _filtroEstadoVenta = 'todos';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final empresas = await _dataSource.getEmpresas();
      final ventas = await _dataSource.getVentas();
      if (mounted) {
        setState(() {
          _empresas = empresas;
          _ventas = ventas;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al cargar créditos: $e';
          _cargando = false;
        });
      }
    }
  }

  // Filtrado de Empresas
  List<EmpresaCredito> get _empresasFiltradas {
    final q = _busqueda.trim().toLowerCase();
    if (q.isEmpty) return _empresas;
    return _empresas.where((e) {
      return e.nombre.toLowerCase().contains(q) ||
          (e.rfc != null && e.rfc!.toLowerCase().contains(q)) ||
          (e.contactoNombre != null && e.contactoNombre!.toLowerCase().contains(q));
    }).toList();
  }

  // Filtrado de Ventas
  List<CreditoVenta> get _ventasFiltradas {
    final q = _busqueda.trim().toLowerCase();
    return _ventas.where((v) {
      if (_filtroEstadoVenta == 'vencido') {
        if (!v.esVencida) return false;
      } else if (_filtroEstadoVenta != 'todos') {
        if (v.estado != _filtroEstadoVenta) return false;
      }

      if (q.isEmpty) return true;
      final emp = v.empresaNombre?.toLowerCase() ?? '';
      final folio = v.ventaFolio?.toLowerCase() ?? '';
      final chofer = v.recibidoPor?.toLowerCase() ?? '';
      final vale = v.folioVale?.toLowerCase() ?? '';
      return emp.contains(q) || folio.contains(q) || chofer.contains(q) || vale.contains(q);
    }).toList();
  }

  // KPIs
  double get _totalPorCobrar => _empresas.fold(0.0, (sum, e) => sum + e.saldoDeudor);
  int get _totalBateriasDebidas => _empresas.fold(0, (sum, e) => sum + e.totalBateriasDebidas);
  int get _facturasVencidas => _ventas.where((v) => v.esVencida).length;

  // Ver Estado de Cuenta
  Future<void> _verEstadoCuenta(EmpresaCredito empresa) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ModalEstadoCuenta(
        empresaId: empresa.id,
        moneda: _moneda,
        dataSource: _dataSource,
        onAbonoRegistrado: _cargarDatos,
      ),
    );
  }

  // Modal Registrar Abono
  Future<void> _abrirModalAbono(EmpresaCredito empresa, {CreditoVenta? venta}) async {
    final res = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ModalRegistrarAbono(
        empresa: empresa,
        venta: venta,
        moneda: _moneda,
        dataSource: _dataSource,
      ),
    );

    if (res == true) {
      _cargarDatos();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Créditos Empresariales',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
            onPressed: _cargarDatos,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: [
            Tab(
              icon: const Icon(Icons.business_rounded, size: 20),
              text: 'Empresas (${_empresas.length})',
            ),
            Tab(
              icon: const Icon(Icons.receipt_long_rounded, size: 20),
              text: 'Cuentas x Cobrar (${_ventas.where((v) => v.estado != 'pagado').length})',
            ),
          ],
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _cargarDatos,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Banner KPIs
                    _buildKpiBanner(colors),

                    // Barra de Búsqueda
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Buscar por empresa, folio o chofer...',
                                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                suffixIcon: _busqueda.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded, size: 18),
                                        onPressed: () => setState(() => _busqueda = ''),
                                      )
                                    : null,
                              ),
                              onChanged: (val) => setState(() => _busqueda = val),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Contenido de Tabs
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildTabEmpresas(colors),
                          _buildTabVentas(colors),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildKpiBanner(ColorScheme colors) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildKpiItem(
              titulo: 'Por Cobrar',
              valor: _moneda.format(_totalPorCobrar),
              color: colors.primary,
              subtitulo: '${_empresas.where((e) => e.saldoDeudor > 0).length} empresas',
            ),
          ),
          Container(width: 1, height: 40, color: colors.outlineVariant),
          Expanded(
            child: _buildKpiItem(
              titulo: 'Baterías Deuda',
              valor: '$_totalBateriasDebidas uds',
              color: Colors.blueAccent,
              subtitulo: 'Entregadas',
            ),
          ),
          Container(width: 1, height: 40, color: colors.outlineVariant),
          Expanded(
            child: _buildKpiItem(
              titulo: 'Vencidas',
              valor: '$_facturasVencidas',
              color: _facturasVencidas > 0 ? Colors.redAccent : Colors.green,
              subtitulo: 'Cuentas',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiItem({
    required String titulo,
    required String valor,
    required Color color,
    required String subtitulo,
  }) {
    return Column(
      children: [
        Text(
          titulo.toUpperCase(),
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(
          subtitulo,
          style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // TAB 1: LISTADO DE EMPRESAS
  // --------------------------------------------------------------------------
  Widget _buildTabEmpresas(ColorScheme colors) {
    final lista = _empresasFiltradas;
    if (lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.business_rounded, size: 48, color: colors.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 8),
            const Text('No se encontraron empresas con crédito'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: lista.length,
      itemBuilder: (ctx, i) {
        final emp = lista[i];
        final tieneDeuda = emp.saldoDeudor > 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: emp.tieneVencidas
                  ? Colors.redAccent.withValues(alpha: 0.6)
                  : colors.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (tieneDeuda ? colors.primary : Colors.grey).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.business_rounded,
                        color: tieneDeuda ? colors.primary : colors.onSurfaceVariant,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            emp.nombre,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          if (emp.rfc != null && emp.rfc!.isNotEmpty)
                            Text(
                              'RFC: ${emp.rfc}',
                              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                            ),
                          if (emp.contactoNombre != null || emp.telefono != null)
                            Text(
                              '${emp.contactoNombre ?? ''} ${emp.telefono != null ? '· ${emp.telefono}' : ''}',
                              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                    if (emp.tieneVencidas)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.redAccent),
                        ),
                        child: const Text(
                          '⚠️ Vencida',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent),
                        ),
                      ),
                  ],
                ),
                const Divider(height: 20),

                // Resumen de Deuda y Plazo
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SALDO DEUDOR',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colors.onSurfaceVariant),
                        ),
                        Text(
                          _moneda.format(emp.saldoDeudor),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: tieneDeuda ? colors.primary : Colors.green,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'BATERÍAS DEUDA',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colors.onSurfaceVariant),
                        ),
                        Text(
                          '${emp.totalBateriasDebidas} uds',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'PLAZO',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colors.onSurfaceVariant),
                        ),
                        Text(
                          '${emp.diasCredito} días',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueAccent),
                        ),
                      ],
                    ),
                  ],
                ),
                if (emp.bateriasPorModelo.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    emp.bateriasPorModelo
                        .map((m) => '${m.cantidad}× ${m.producto}')
                        .join(' · '),
                    style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 12),

                // Botones de acción
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.history_edu_rounded, size: 18),
                        label: const Text('Estado de Cuenta', style: TextStyle(fontSize: 12)),
                        onPressed: () => _verEstadoCuenta(emp),
                      ),
                    ),
                    if (tieneDeuda) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: colors.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.add_card_rounded, size: 18),
                          label: const Text('Abonar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () => _abrirModalAbono(emp),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // TAB 2: VENTAS A CRÉDITO (CUENTAS POR COBRAR)
  // --------------------------------------------------------------------------
  Widget _buildTabVentas(ColorScheme colors) {
    final lista = _ventasFiltradas;

    return Column(
      children: [
        // Filtros de estado
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              _buildFiltroChip('todos', 'Todas'),
              _buildFiltroChip('pendiente', 'Pendientes'),
              _buildFiltroChip('parcial', 'Con Abonos'),
              _buildFiltroChip('vencido', '⚠️ Vencidas'),
              _buildFiltroChip('pagado', 'Pagadas'),
            ],
          ),
        ),

        Expanded(
          child: lista.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long_rounded, size: 48, color: colors.onSurfaceVariant.withValues(alpha: 0.5)),
                      const SizedBox(height: 8),
                      const Text('No hay cuentas por cobrar con estos filtros'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: lista.length,
                  itemBuilder: (ctx, i) {
                    final item = lista[i];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: item.esVencida
                              ? Colors.redAccent.withValues(alpha: 0.6)
                              : colors.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.ventaFolio ?? 'V-CREDITO',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                        color: colors.primary,
                                      ),
                                    ),
                                    Text(
                                      item.empresaNombre ?? 'Empresa',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: item.estado == 'pagado'
                                        ? Colors.green.withValues(alpha: 0.15)
                                        : item.esVencida
                                            ? Colors.red.withValues(alpha: 0.15)
                                            : Colors.blue.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    item.estado == 'pagado'
                                        ? 'Liquidada'
                                        : item.esVencida
                                            ? '⚠️ Vencida'
                                            : item.estado == 'parcial'
                                                ? 'Abonada'
                                                : 'Pendiente',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: item.estado == 'pagado'
                                          ? Colors.green
                                          : item.esVencida
                                              ? Colors.redAccent
                                              : Colors.blueAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),

                            // Artículos entregados
                            if (item.items.isNotEmpty) ...[
                              Text(
                                'Artículos entregados a crédito:',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.onSurfaceVariant),
                              ),
                              const SizedBox(height: 4),
                              ...item.items.map(
                                (vi) => Padding(
                                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                                  child: Text(
                                    '• ${vi.cantidad}x ${vi.productoModelo ?? 'Batería'} (${vi.productoMarca ?? ''}) ${vi.conCasco ? '· Con casco' : '· Sin casco'}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],

                            // Datos de Chofer / Placas / Vale
                            if (item.recibidoPor != null || item.vehiculoPlacas != null || item.folioVale != null)
                              Container(
                                padding: const EdgeInsets.all(8),
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.badge_rounded, size: 16),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Recibe: ${item.recibidoPor ?? '—'} ${item.vehiculoPlacas != null ? '· Placas: ${item.vehiculoPlacas}' : ''} ${item.folioVale != null ? '· Vale: ${item.folioVale}' : ''}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Totales y Vencimiento
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Vence: ${item.fechaVencimiento}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: item.esVencida ? Colors.redAccent : colors.onSurfaceVariant,
                                      ),
                                    ),
                                    Text(
                                      'Total: ${_moneda.format(item.montoTotal)}',
                                      style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'SALDO PENDIENTE',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colors.onSurfaceVariant),
                                    ),
                                    Text(
                                      _moneda.format(item.saldoPendiente),
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        color: item.saldoPendiente > 0 ? colors.primary : Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            if (item.saldoPendiente > 0 && item.empresaId != null) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colors.primary,
                                    foregroundColor: colors.onPrimary,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.payment_rounded, size: 18),
                                  label: const Text('Abonar / Liquidar Esta Factura'),
                                  onPressed: () {
                                    final emp = _empresas.firstWhere(
                                      (e) => e.id == item.empresaId,
                                      orElse: () => EmpresaCredito(
                                        id: item.empresaId!,
                                        nombre: item.empresaNombre ?? 'Empresa',
                                        saldoDeudor: item.saldoPendiente,
                                      ),
                                    );
                                    _abrirModalAbono(emp, venta: item);
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFiltroChip(String estado, String label) {
    final activo = _filtroEstadoVenta == estado;
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 12, fontWeight: activo ? FontWeight.bold : FontWeight.normal)),
        selected: activo,
        onSelected: (_) => setState(() => _filtroEstadoVenta = estado),
        selectedColor: colors.primary.withValues(alpha: 0.2),
        checkmarkColor: colors.primary,
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// MODAL ESTADO DE CUENTA
// ----------------------------------------------------------------------------
class _ModalEstadoCuenta extends StatefulWidget {
  const _ModalEstadoCuenta({
    required this.empresaId,
    required this.moneda,
    required this.dataSource,
    required this.onAbonoRegistrado,
  });

  final String empresaId;
  final NumberFormat moneda;
  final CreditosRemoteDataSource dataSource;
  final VoidCallback onAbonoRegistrado;

  @override
  State<_ModalEstadoCuenta> createState() => _ModalEstadoCuentaState();
}

class _ModalEstadoCuentaState extends State<_ModalEstadoCuenta> {
  EstadoCuentaEmpresa? _estadoCuenta;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final data = await widget.dataSource.getEstadoCuenta(widget.empresaId);
      if (mounted) {
        setState(() {
          _estadoCuenta = data;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al cargar estado de cuenta: $e';
          _cargando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(20),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      child: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ESTADO DE CUENTA',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                _estadoCuenta!.empresa.nombre,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Resumen
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Saldo Deudor Total', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              Text(
                                widget.moneda.format(_estadoCuenta!.saldoDeudor),
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: colors.primary,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Plazo Autorizado', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              Text(
                                '${_estadoCuenta!.empresa.diasCredito} días',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Lista de Compras y Abonos
                    Expanded(
                      child: DefaultTabController(
                        length: 2,
                        child: Column(
                          children: [
                            const TabBar(
                              tabs: [
                                Tab(text: 'Ventas a Crédito'),
                                Tab(text: 'Historial de Abonos'),
                              ],
                            ),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  _buildVentasList(colors),
                                  _buildAbonosList(colors),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildVentasList(ColorScheme colors) {
    final ventas = _estadoCuenta!.ventas;
    if (ventas.isEmpty) return const Center(child: Text('No hay ventas registradas'));
    return ListView.builder(
      itemCount: ventas.length,
      itemBuilder: (ctx, i) {
        final v = ventas[i];
        return ListTile(
          dense: true,
          title: Text('${v.ventaFolio ?? 'Venta'} · ${widget.moneda.format(v.montoTotal)}'),
          subtitle: Text('Vence: ${v.fechaVencimiento} · Saldo: ${widget.moneda.format(v.saldoPendiente)}'),
          trailing: Text(
            v.estado,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: v.estado == 'pagado' ? Colors.green : Colors.orange,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAbonosList(ColorScheme colors) {
    final abonos = _estadoCuenta!.abonos;
    if (abonos.isEmpty) return const Center(child: Text('No hay abonos registrados'));
    return ListView.builder(
      itemCount: abonos.length,
      itemBuilder: (ctx, i) {
        final a = abonos[i];
        return ListTile(
          dense: true,
          title: Text('+${widget.moneda.format(a.monto)} (${a.metodoPago})'),
          subtitle: Text('${a.createdAt} ${a.referencia != null ? '· Ref: ${a.referencia}' : ''}'),
        );
      },
    );
  }
}

// ----------------------------------------------------------------------------
// MODAL REGISTRAR ABONO
// ----------------------------------------------------------------------------
class _ModalRegistrarAbono extends StatefulWidget {
  const _ModalRegistrarAbono({
    required this.empresa,
    this.venta,
    required this.moneda,
    required this.dataSource,
  });

  final EmpresaCredito empresa;
  final CreditoVenta? venta;
  final NumberFormat moneda;
  final CreditosRemoteDataSource dataSource;

  @override
  State<_ModalRegistrarAbono> createState() => _ModalRegistrarAbonoState();
}

class _ModalRegistrarAbonoState extends State<_ModalRegistrarAbono> {
  final TextEditingController _montoCtrl = TextEditingController();
  final TextEditingController _refCtrl = TextEditingController();
  final TextEditingController _notasCtrl = TextEditingController();
  String _metodoPago = 'transferencia';
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final montoSug = widget.venta != null ? widget.venta!.saldoPendiente : widget.empresa.saldoDeudor;
    if (montoSug > 0) {
      _montoCtrl.text = montoSug.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _refCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    final monto = double.tryParse(_montoCtrl.text.replaceAll(',', '')) ?? 0.0;
    if (monto <= 0) {
      setState(() => _error = 'Ingresa un monto de abono válido');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      await widget.dataSource.registrarAbono(
        empresaId: widget.empresa.id,
        monto: monto,
        metodoPago: _metodoPago,
        creditoVentaId: widget.venta?.id,
        referencia: _refCtrl.text.trim(),
        notas: _notasCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al registrar abono: $e';
          _guardando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: bottomInset + 20,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.venta != null ? 'Abonar a Factura' : 'Registrar Abono a Cuenta',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Text(
                'Empresa: ${widget.empresa.nombre}',
                style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
              ),
              if (widget.venta != null)
                Text(
                  'Factura: ${widget.venta!.ventaFolio} (Pendiente: ${widget.moneda.format(widget.venta!.saldoPendiente)})',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.primary),
                ),
              const SizedBox(height: 16),

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                ),
                const SizedBox(height: 12),
              ],

              TextField(
                controller: _montoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: r'Monto a Abonar (\$ MXN) *',
                  prefixText: r'$ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: _metodoPago,
                decoration: InputDecoration(
                  labelText: 'Forma de Pago *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 'transferencia', child: Text('Transferencia Bancaria')),
                  DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                  DropdownMenuItem(value: 'efectivo', child: Text('Efectivo en Caja')),
                  DropdownMenuItem(value: 'tarjeta', child: Text('Tarjeta Bancaria')),
                ],
                onChanged: (val) => setState(() => _metodoPago = val ?? 'transferencia'),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _refCtrl,
                decoration: InputDecoration(
                  labelText: 'Referencia / Folio / No. Cheque',
                  hintText: 'Ej. SPEI-984214',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _notasCtrl,
                decoration: InputDecoration(
                  labelText: 'Notas o comentarios',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _guardando ? null : _confirmar,
                child: _guardando
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Confirmar y Aplicar Pago', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
