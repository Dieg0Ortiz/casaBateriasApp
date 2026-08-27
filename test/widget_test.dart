import 'package:flutter_test/flutter_test.dart';

import 'package:casabateriaserp/features/auth/domain/user_profile.dart';
import 'package:casabateriaserp/features/auth/presentation/auth_viewmodel.dart';
import 'package:casabateriaserp/features/auth/domain/auth_repository.dart';
import 'package:casabateriaserp/features/auth/domain/login_result.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.sesionRestaurada = false});

  final bool sesionRestaurada;

  @override
  Future<LoginResult> login(String email, String password) async {
    return LoginResult(
      accessToken: 'tok',
      refreshToken: 'ref',
      perfil: const UserProfile(
        id: '1',
        rol: Rol.trabajador,
        nombreCompleto: 'Prueba',
        activo: true,
      ),
    );
  }

  @override
  Future<UserProfile?> restaurarSesion() async {
    if (!sesionRestaurada) return null;
    return const UserProfile(
      id: '1',
      rol: Rol.administrador,
      nombreCompleto: 'Prueba',
      activo: true,
    );
  }

  @override
  Future<void> logout() async {}
}

void main() {
  testWidgets('Login exitoso cambia a autenticado', (tester) async {
    final vm = AuthViewModel(_FakeAuthRepository());

    final ok = await vm.login('a@b.com', 'pass');
    expect(ok, isTrue);
    expect(vm.status, AuthStatus.autenticado);
    expect(vm.usuario?.nombreCompleto, 'Prueba');
    expect(vm.usuario?.esAdministrador, isFalse);
  });

  testWidgets('Sin sesión guardada la app queda desconectada', (tester) async {
    final vm = AuthViewModel(_FakeAuthRepository());

    await vm.restaurarSesion();
    expect(vm.status, AuthStatus.desconectado);
    expect(vm.usuario, isNull);
  });

  testWidgets('Con sesión guardada se restaura el perfil', (tester) async {
    final vm = AuthViewModel(_FakeAuthRepository(sesionRestaurada: true));

    await vm.restaurarSesion();
    expect(vm.status, AuthStatus.autenticado);
    expect(vm.usuario?.rol, Rol.administrador);
  });

  testWidgets('Logout vuelve a desconectado', (tester) async {
    final vm = AuthViewModel(_FakeAuthRepository());

    await vm.login('a@b.com', 'pass');
    await vm.logout();
    expect(vm.status, AuthStatus.desconectado);
    expect(vm.usuario, isNull);
  });
}
