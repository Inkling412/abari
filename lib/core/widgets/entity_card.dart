import 'package:flutter/material.dart';

/// Widget card reutilizable para mostrar entidades (empleados, clientes, proveedores, etc.)
class EntityCard extends StatelessWidget {
  /// Nombre principal de la entidad
  final String nombre;

  /// Icono a mostrar en el avatar
  final IconData icon;

  /// Lista de subtítulos opcionales (ej: teléfono, cargo, RUC)
  final List<String> subtitulos;

  /// Callback cuando se presiona el botón de editar
  final VoidCallback onEdit;

  const EntityCard({
    super.key,
    required this.nombre,
    required this.icon,
    this.subtitulos = const [],
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      child: Stack(
        children: [
          Positioned(
            top: 2,
            right: 2,
            child: IconButton(
              icon: const Icon(Icons.edit, size: 16),
              onPressed: onEdit,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 14, child: Icon(icon, size: 14)),
                  const SizedBox(height: 2),
                  Text(
                    nombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitulos.isNotEmpty)
                    Text(
                      subtitulos.first,
                      style: const TextStyle(fontSize: 9),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
