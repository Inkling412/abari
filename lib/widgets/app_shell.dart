import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:abari/providers/theme_provider.dart';

/// Shell que contiene el AppBar y Drawer persistentes
class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final currentLocation = GoRouterState.of(context).uri.toString();
    final isHome = currentLocation == '/home';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (isHome) {
          // En home, preguntar si quiere salir
          final shouldExit = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('¿Salir de la aplicación?'),
              content: const Text('¿Estás seguro de que deseas salir?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Salir'),
                ),
              ],
            ),
          );
          if (shouldExit == true) {
            // Cerrar la app correctamente
            SystemNavigator.pop();
          }
        } else {
          // En otras pantallas, volver al home
          context.go('/home');
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('ABARI')),
        drawer: const AppDrawer(),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 0),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Drawer de navegación principal
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          const DrawerHeader(
            //padding: EdgeInsets.zero,
            //margin: EdgeInsets.zero,
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                'Menú Principal',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ),
          ),

          _buildSection("Principal", [
            ('Inicio', '/home', Icons.home),
          ], context),

          const Divider(),

          _buildSection("Inventario", [
            ('Productos', '/productos', Icons.inventory),
          ], context),

          const Divider(),

          _buildSection("Recursos Humanos", [
            ('Proveedores', '/proveedores', Icons.corporate_fare),
            ('Clientes', '/clientes', Icons.people),
            ('Personal', '/empleados', Icons.badge),
          ], context),

          const Divider(),

          _buildSection("Transacciones", [
            // factura a clientes
            ('Factura', '/factura', Icons.point_of_sale),
            // factura a proveedores
            ('Compras', '/compras', Icons.attach_money),
            ('Reporte de ventas', '/reporteVenta', Icons.receipt_long),
            ('Reporte de compras', '/reporteCompra', Icons.receipt_long),
          ], context),

          const Divider(),

          _buildSection("Info", [('Acerca de', '/about', Icons.info)], context),

          const Divider(),

          // Switch de tema
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return SwitchListTile(
                secondary: Icon(
                  themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                ),
                title: const Text('Modo oscuro'),
                value: themeProvider.isDarkMode,
                onChanged: (value) {
                  themeProvider.toggleTheme();
                },
              );
            },
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.pop(context);
                context.go('/login');
              }
            },
          ),
          const SizedBox(width: double.infinity, height: 40),
        ],
      ),
    );
  }

  Widget _buildSection(
    String title,
    List<(String, String, IconData?)> items,
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),

        ...items.map((item) {
          final (label, route, icon) = item;

          return ListTile(
            leading: icon != null ? Icon(icon) : null,
            title: Text(label),
            onTap: () {
              Navigator.pop(context);
              context.go(route);
            },
          );
        }),
      ],
    );
  }
}
