import 'package:abari/screens/empleados.dart';
import 'package:abari/screens/factura/pages/factura_screen.dart';
import 'package:abari/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:abari/screens/login_screen.dart';
import 'package:abari/screens/productos.dart';
import 'package:abari/screens/proveedores.dart';
import 'package:abari/screens/clientes.dart';
import 'package:abari/screens/reporte_venta_screen.dart';
import 'package:abari/screens/reporte_compra_screen.dart';
import 'package:abari/screens/compras.dart';
import 'package:abari/screens/about.dart';
import 'package:abari/widgets/app_shell.dart';

final GoRouter router = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggedIn = session != null;

    if (!isLoggedIn && state.uri.toString() != '/login') {
      return '/login';
    }
    if (isLoggedIn && state.uri.toString() == '/login') {
      return '/home';
    }
    return null;
  },
  routes: <RouteBase>[
    GoRoute(
      path: '/login',
      builder: (BuildContext context, GoRouterState state) =>
          const LoginScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/productos',
          builder: (context, state) => const ProductosScreen(),
        ),
        GoRoute(
          path: '/empleados',
          builder: (context, state) => const EmpleadosScreen(),
        ),
        GoRoute(
          path: '/proveedores',
          builder: (context, state) => const ProveedoresScreen(),
        ),
        GoRoute(
          path: '/clientes',
          builder: (context, state) => const ClientesScreen(),
        ),
        GoRoute(
          path: '/reporteVenta',
          builder: (context, state) => const ReportesVentasScreen(),
        ),
        GoRoute(
          path: '/reporteCompra',
          builder: (context, state) => const ReportesComprasScreen(),
        ),
        GoRoute(
          path: '/compras',
          name: 'compras',
          builder: (context, state) => const ComprasScreen(),
        ),
        GoRoute(
          path: '/about',
          name: 'about',
          builder: (context, state) => const AboutScreen(),
        ),
        GoRoute(
          path: FacturaScreen.pathName,
          name: FacturaScreen.routeName,
          builder: (context, state) => const FacturaScreen(),
        ),
      ],
    ),
  ],
  //ESTO HACE COSAS QUE SOLO GPT SABE
  errorBuilder: (context, state) {
    // Mostrar SnackBar de manera segura
    Future.microtask(() {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Ruta inválida: ${state.error}'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () => context.go('/home'),
              icon: Icon(Icons.home),
              tooltip: "Inicio",
            ),
            Text(
              'Ha ocurrido un error, parece que la ruta no existe. Presiona el boton para volver al inicio.',
            ),
          ],
        ),
      ),
    );
  },
);
