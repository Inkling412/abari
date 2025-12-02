import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:abari/router.dart';
import 'package:abari/providers/theme_provider.dart';
import 'package:abari/providers/session_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppInitializer());
}

/// Widget que muestra splash mientras inicializa la app
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _initialized = false;
  bool _savedTheme = false;
  Map<String, dynamic> _savedSession = {};

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Cargar preferencias guardadas
    _savedTheme = await ThemeProvider.loadSavedTheme();
    _savedSession = await SessionProvider.loadSavedSession();

    // Debug: mostrar valores cargados
    debugPrint('🎨 Tema oscuro guardado: $_savedTheme');
    debugPrint('👤 Sesión guardada: $_savedSession');

    // Inicializar Supabase
    await Supabase.initialize(
      url: 'https://gtrviyxzjghufruilesy.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd0cnZpeXh6amdodWZydWlsZXN5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM3MTI4NDcsImV4cCI6MjA3OTI4ODg0N30.5L9LnZt6twnaMj2D_QNlZ75aitA9qrlS6YEsDFClbuo',
    );

    // Mostrar splash por al menos 1.5 segundos para mejor UX
    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      // Pantalla de splash mientras carga - respeta el tema guardado
      final isDark = _savedTheme;
      final backgroundColor = isDark ? const Color(0xFF121212) : Colors.white;
      final textColor = isDark ? const Color(0xFF64B5F6) : Colors.blue;
      final containerColor = isDark
          ? Colors.blue.withValues(alpha: 0.2)
          : Colors.blue.withValues(alpha: 0.1);

      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: isDark ? ThemeData.dark() : ThemeData.light(),
        home: Scaffold(
          backgroundColor: backgroundColor,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: containerColor,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 24),
                // Título
                Text(
                  'Abari',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 32),
                // Indicador de carga
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // App inicializada
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(isDarkMode: _savedTheme),
        ),
        ChangeNotifierProvider(
          create: (_) => SessionProvider(
            empleadoId: _savedSession['empleadoId'],
            empleadoNombre: _savedSession['empleadoNombre'],
          ),
        ),
      ],
      child: const MyApp(),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          themeMode: themeProvider.themeMode,
          // Configuración de localizaciones
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('es', 'ES'), // Español
            Locale('en', 'US'), // Inglés
          ],
          locale: const Locale('es', 'ES'),
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
            appBarTheme: const AppBarTheme(centerTitle: false, elevation: 2),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
            appBarTheme: const AppBarTheme(centerTitle: false, elevation: 2),
          ),
          builder: (context, child) {
            return child ?? const SizedBox.shrink();
          },
        );
      },
    );
  }
}
