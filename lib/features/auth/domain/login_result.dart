import 'user_profile.dart';

class LoginResult {
  const LoginResult({
    required this.accessToken,
    required this.refreshToken,
    required this.perfil,
  });

  final String accessToken;
  final String refreshToken;
  final UserProfile perfil;
}
