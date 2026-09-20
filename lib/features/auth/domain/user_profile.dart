/// Rol del usuario. Fuente de verdad: base de datos (usuarios.rol).
enum Rol { trabajador, administrador }

class UserProfile {
  const UserProfile({
    required this.id,
    required this.rol,
    required this.nombreCompleto,
    required this.activo,
    this.sucursalId,
    this.sucursalNombre,
  });

  final String id;
  final Rol rol;
  final String nombreCompleto;
  final bool activo;
  final String? sucursalId;
  final String? sucursalNombre;

  bool get esAdministrador => rol == Rol.administrador;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    String? nombreSucursal = json['sucursal_nombre'] as String?;
    if (nombreSucursal == null && json['sucursales'] is Map) {
      nombreSucursal = (json['sucursales'] as Map)['nombre'] as String?;
    }

    return UserProfile(
      id: json['id'] as String,
      rol: json['rol'] == 'administrador'
          ? Rol.administrador
          : Rol.trabajador,
      nombreCompleto: (json['nombre_completo'] ?? '') as String,
      activo: (json['activo'] ?? true) as bool,
      sucursalId: json['sucursal_id'] as String?,
      sucursalNombre: nombreSucursal,
    );
  }
}
