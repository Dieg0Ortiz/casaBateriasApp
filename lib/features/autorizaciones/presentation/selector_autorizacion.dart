import 'package:flutter/material.dart';

/// Cómo se autoriza: el administrador aprueba desde el panel, o escribe su
/// clave aquí mismo si está en la sucursal.
class SelectorAutorizacion extends StatelessWidget {
  const SelectorAutorizacion({
    super.key,
    required this.aDistancia,
    required this.onCambio,
  });

  final bool aDistancia;
  final ValueChanged<bool> onCambio;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: true,
              icon: Icon(Icons.send_to_mobile_rounded),
              label: Text('Pedir al panel'),
            ),
            ButtonSegment(
              value: false,
              icon: Icon(Icons.key_rounded),
              label: Text('Clave aquí'),
            ),
          ],
          selected: {aDistancia},
          onSelectionChanged: (s) => onCambio(s.first),
        ),
        const SizedBox(height: 6),
        Text(
          aDistancia
              ? 'Un administrador lo aprueba desde el panel; no hace falta su contraseña.'
              : 'El administrador está aquí y escribe su correo y contraseña.',
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}
