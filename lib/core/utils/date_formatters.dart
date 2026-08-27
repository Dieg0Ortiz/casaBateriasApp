const _meses = [
  'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
  'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
];

/// Formato estándar: 22/08/2026 10:56 (sin depender de locale intl asíncrono)
String formatFechaHora(DateTime? dt) {
  if (dt == null) return '—';
  final d = dt.toLocal();
  final dia = d.day.toString().padLeft(2, '0');
  final mes = d.month.toString().padLeft(2, '0');
  final anio = d.year.toString();
  final hora = d.hour.toString().padLeft(2, '0');
  final min = d.minute.toString().padLeft(2, '0');
  return '$dia/$mes/$anio $hora:$min';
}

/// Formato corto: 22 Ago, 10:56
String formatFechaCorta(DateTime? dt) {
  if (dt == null) return '—';
  final d = dt.toLocal();
  final dia = d.day.toString().padLeft(2, '0');
  final mesStr = _meses[d.month - 1];
  final hora = d.hour.toString().padLeft(2, '0');
  final min = d.minute.toString().padLeft(2, '0');
  return '$dia $mesStr, $hora:$min';
}

/// Formato hora: 10:56
String formatHora(DateTime? dt) {
  if (dt == null) return '—';
  final d = dt.toLocal();
  final hora = d.hour.toString().padLeft(2, '0');
  final min = d.minute.toString().padLeft(2, '0');
  return '$hora:$min';
}
