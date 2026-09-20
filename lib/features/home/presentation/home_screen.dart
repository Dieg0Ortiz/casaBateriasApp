import '../../creditos/presentation/creditos_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../auth/presentation/auth_viewmodel.dart';
import '../../cash/presentation/cash_screen.dart';
import '../../cash/presentation/cash_viewmodel.dart';
import '../../catalog/presentation/catalog_screen.dart';
import '../../inventory/presentation/inventory_screen.dart';
import '../../sales/presentation/pos_screen.dart';
import '../../purchases/presentation/purchases_screen.dart';
import '../../cascos/presentation/intercambios_screen.dart';
import '../../catalog/data/catalogo_remote_data_source.dart';
import '../../auth/domain/user_profile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabSeleccionado = 0;
  final _moneda = NumberFormat.currency(locale: 'es_MX', symbol: r'$');

  String? _sucursalNombreCargada;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cashVm = context.read<CashViewModel>();
      if (!cashVm.cargando) cashVm.cargar();
      _cargarSucursal();
    });
  }

  Future<void> _cargarSucursal() async {
    final usuario = context.read<AuthViewModel>().usuario;
    if (usuario?.sucursalNombre != null && usuario!.sucursalNombre!.isNotEmpty) {
      if (mounted) setState(() => _sucursalNombreCargada = usuario.sucursalNombre);
      return;
    }
    if (usuario?.sucursalId != null) {
      try {
        final sucs = await CatalogoRemoteDataSource().listarSucursales();
        final match = sucs.where((s) => s.id == usuario!.sucursalId);
        if (match.isNotEmpty && mounted) {
          setState(() => _sucursalNombreCargada = match.first.nombre);
        }
      } catch (_) {}
    }
  }

  String _formatearSucursal(UserProfile? usuario) {
    String nombre = '';
    if (usuario?.sucursalNombre != null && usuario!.sucursalNombre!.isNotEmpty) {
      nombre = usuario.sucursalNombre!;
    } else if (_sucursalNombreCargada != null && _sucursalNombreCargada!.isNotEmpty) {
      nombre = _sucursalNombreCargada!;
    } else if (usuario?.esAdministrador == true) {
      return 'Corporativo';
    } else if (usuario?.sucursalId != null) {
      return 'Cargando...';
    } else {
      return 'Sin Sucursal';
    }

    final trimmed = nombre.trim();
    if (trimmed.toLowerCase().startsWith('sucursal')) {
      return trimmed;
    }
    return 'Sucursal $trimmed';
  }

  void _cambiarTab(int index) {
    setState(() => _tabSeleccionado = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tabSeleccionado,
        children: [
          _buildDashboard(context),
          const PosScreen(),
          const CashScreen(),
          const CatalogScreen(),
          const InventoryScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabSeleccionado,
        height: 64,
        onDestinationSelected: _cambiarTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale_rounded),
            label: 'POS',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments_rounded),
            label: 'Caja',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'Catálogo',
          ),
          NavigationDestination(
            icon: Icon(Icons.warehouse_outlined),
            selectedIcon: Icon(Icons.warehouse_rounded),
            label: 'Stock',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final cashVm = context.watch<CashViewModel>();
    final usuario = authVm.usuario;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final cajaAbierta = cashVm.cajaActiva?.tieneCajaAbierta == true;
    final totalCaja = cashVm.cajaActiva?.montoEsperado ?? 0;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  (usuario?.nombreCompleto.isNotEmpty == true)
                      ? usuario!.nombreCompleto[0].toUpperCase()
                      : 'U',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: colors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Hola, ${usuario?.nombreCompleto.split(' ').first ?? 'Usuario'}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        usuario?.esAdministrador == true ? 'ADMINISTRADOR' : 'TRABAJADOR',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.05,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: cajaAbierta ? colors.primary : Colors.amber,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _formatearSucursal(usuario),
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: colors.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Salir',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => context.read<AuthViewModel>().logout(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          // Bento Hero Action Card: Punto de Venta
          GestureDetector(
            onTap: () => _cambiarTab(1),
            child: Card(
              color: colors.primary.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: colors.primary.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -10,
                    bottom: -15,
                    child: Icon(
                      Icons.point_of_sale_rounded,
                      size: 130,
                      color: colors.primary.withValues(alpha: 0.08),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: cajaAbierta ? colors.primary : Colors.amber.shade700,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                cajaAbierta ? 'CAJA ACTIVA' : 'CAJA SIN ABRIR',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.05,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: colors.surfaceContainerHighest,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: 20,
                                color: colors.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Punto de Venta',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.01,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Escanear código de barras o búsqueda manual',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Bento Row 1: Control de Caja & Catálogo
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _cambiarTab(2),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Control de Caja',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontSize: 13,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              Icon(Icons.payments_outlined, size: 20, color: colors.primary),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _moneda.format(totalCaja),
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'CORTE ACTUAL',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.05,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _cambiarTab(3),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Catálogo & Altas',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontSize: 13,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              Icon(Icons.inventory_2_outlined, size: 20, color: colors.secondary),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Modelos',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: colors.onSurface,
                                    ),
                                  ),
                                  Text(
                                    'Precios & Altas',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: colors.primary.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.add, size: 20, color: colors.primary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Bento Card 3: Existencias Rápidas
          GestureDetector(
            onTap: () => _cambiarTab(4),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Existencias Rápidas',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(Icons.warehouse_outlined, size: 20, color: colors.onSurfaceVariant),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _FilaExistencia(
                      etiqueta: 'Baterías Nuevas',
                      valor: 'Stock Activo',
                      chip: 'Consultar',
                      icono: Icons.battery_full_rounded,
                      color: colors.primary,
                    ),
                    const Divider(height: 18),
                    _FilaExistencia(
                      etiqueta: 'Cascos Almacenados',
                      valor: 'Chatarra Reciclaje',
                      chip: 'Ver Cascos',
                      icono: Icons.recycling_rounded,
                      color: colors.secondary,
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (usuario?.esAdministrador == true) ...[
            const SizedBox(height: 12),
            Card(
              color: colors.primary.withValues(alpha: 0.06),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colors.primary.withValues(alpha: 0.2)),
              ),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.shopping_cart_outlined, color: colors.primary),
                ),
                title: const Text(
                  'Compras de Stock & Reabastecimiento',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: const Text(
                  'Entrada de mercancía, proveedores y cascos',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PurchasesScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.07),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: const Color(0xFF3B82F6).withValues(alpha: 0.25)),
              ),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF3B82F6)),
                ),
                title: const Text(
                  'Intercambio de Cascos (Trueques)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: const Text(
                  'Intercambio de baterías usadas con cobro de \$150',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const IntercambiosScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: const Color(0xFF6366F1).withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: const Color(0xFF6366F1).withValues(alpha: 0.25)),
              ),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.business_rounded, color: Color(0xFF6366F1)),
                ),
                title: const Text(
                  'Créditos Empresariales & Cuentas x Cobrar',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: const Text(
                  'Empresas a crédito (Bimbo, etc.), deudas, plazos y abonos',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreditosScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
              child: ListTile(
                leading: Icon(Icons.admin_panel_settings_outlined, color: colors.primary),
                title: const Text('Administración Global', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Precios, bajas de producto y sucursales', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _cambiarTab(3),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilaExistencia extends StatelessWidget {
  const _FilaExistencia({
    required this.etiqueta,
    required this.valor,
    required this.chip,
    required this.icono,
    required this.color,
  });

  final String etiqueta;
  final String valor;
  final String chip;
  final IconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icono, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                etiqueta,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              Text(
                valor,
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            chip,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
