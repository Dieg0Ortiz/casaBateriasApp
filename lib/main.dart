import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/network/api_client.dart';
import 'core/network/token_storage.dart';
import 'features/auth/data/auth_repository_impl.dart';
import 'features/auth/presentation/auth_viewmodel.dart';
import 'features/catalog/data/catalogo_repository_impl.dart';
import 'features/catalog/presentation/catalogo_viewmodel.dart';
import 'features/cash/data/cash_repository_impl.dart';
import 'features/cash/presentation/cash_viewmodel.dart';
import 'features/sales/data/sales_repository_impl.dart';
import 'features/sales/presentation/sales_viewmodel.dart';
import 'features/purchases/data/purchases_repository_impl.dart';
import 'features/purchases/presentation/purchases_viewmodel.dart';
import 'features/cascos/data/intercambios_repository_impl.dart';
import 'features/cascos/presentation/intercambios_viewmodel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_MX', null);
  await initializeDateFormatting('es', null);
  Intl.defaultLocale = 'es_MX';
  TokenStorage.instance;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final authVm = AuthViewModel(AuthRepositoryImpl());
            // Si la renovación de sesión falla, la app vuelve al login en vez
            // de quedarse con errores en cada pantalla.
            ApiClient.instance.onSesionExpirada = authVm.sesionExpirada;
            return authVm;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => CatalogoViewModel(CatalogoRepositoryImpl()),
        ),
        ChangeNotifierProvider(
          create: (_) => SalesViewModel(SalesRepositoryImpl()),
        ),
        ChangeNotifierProvider(
          create: (_) => CashViewModel(CashRepositoryImpl()),
        ),
        ChangeNotifierProvider(
          create: (_) => PurchasesViewModel(PurchasesRepositoryImpl()),
        ),
        ChangeNotifierProvider(
          create: (_) => IntercambiosViewModel(IntercambiosRepositoryImpl()),
        ),
      ],
      child: const App(),
    ),
  );
}
