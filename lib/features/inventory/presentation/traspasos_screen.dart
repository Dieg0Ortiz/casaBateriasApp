import 'package:flutter/material.dart';

import '../../../core/utils/date_formatters.dart';
import '../data/inventory_remote_data_source.dart';
import '../domain/inventory_models.dart';
import 'nuevo_traspaso_screen.dart';

/// Historial de traspasos entre sucursales y acceso a uno nuevo. Solo la ve
/// el administrador (el servidor también lo exige).
class TraspasosScreen extends StatefulWidget {
  const TraspasosScreen({super.key});

  @override
  State<TraspasosScreen> createState() => _TraspasosScreenState();
}

class _TraspasosScreenState extends State<TraspasosScreen> {
  final _ds = InventoryRemoteDataSource();
  List<Traspaso> _traspasos = const [];
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
      final datos = await _ds.listarTraspasos();
      if (!mounted) return;
      setState(() {
        _traspasos = datos;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  Future<void> _nuevo() async {
    final hecho = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const NuevoTraspasoScreen()),
    );
    if (hecho == true) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Traspasos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevo,
        icon: const Icon(Icons.swap_horiz_rounded),
        label: const Text('Nuevo traspaso'),
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
                        Text(_error!, style: TextStyle(color: colors.error), textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton.tonal(onPressed: _cargar, child: const Text('Reintentar')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: _traspasos.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.all(32),
                          children: [
                            Icon(Icons.swap_horiz_rounded, size: 48, color: colors.outline),
                            const SizedBox(height: 12),
                            const Text(
                              'Todavía no hay traspasos',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Usa "Nuevo traspaso" para mover pilas de una sucursal a otra.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                          itemCount: _traspasos.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _TarjetaTraspaso(traspaso: _traspasos[i]),
                        ),
                ),
    );
  }
}

class _TarjetaTraspaso extends StatelessWidget {
  const _TarjetaTraspaso({required this.traspaso});

  final Traspaso traspaso;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final t = traspaso;
    final detalle = [
      formatFechaCorta(t.fecha),
      if (t.autorizo != null && t.autorizo!.isNotEmpty) t.autorizo!,
    ].join(' · ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${t.cantidad}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: colors.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.producto ?? 'Producto',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(child: Text(t.origen ?? '—', overflow: TextOverflow.ellipsis)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward_rounded, size: 16, color: colors.onSurfaceVariant),
                      ),
                      Flexible(
                        child: Text(
                          t.destino ?? '—',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(detalle, style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
                  if (t.nota != null && t.nota!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      t.nota!,
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: colors.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
