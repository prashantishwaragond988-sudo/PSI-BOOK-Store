import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'services/messaging_service.dart';
import 'providers/auth_provider.dart';
import 'providers/home_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/wishlist_provider.dart';
import 'providers/order_provider.dart';
import 'providers/address_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'utils/app_router.dart';
import 'themes/app_theme.dart';
import 'screens/auth/splash_guard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await MessagingService().init();
  runApp(const OurStoreApp());
}

class OurStoreApp extends StatelessWidget {
  const OurStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => WishlistProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => AddressProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: Consumer2<ThemeProvider, SettingsProvider>(
        builder: (context, theme, settings, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'PSI Book Store',
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: theme.themeMode,
            locale: settings.locale ?? const Locale('en'),
            supportedLocales: const [Locale('en'), Locale('hi'), Locale('kn')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            onGenerateRoute: AppRouter.onGenerateRoute,
            home: const SplashGuard(),
          );
        },
      ),
    );
  }
}
