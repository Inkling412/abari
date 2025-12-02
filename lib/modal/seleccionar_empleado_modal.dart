import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:abari/models/empleado_db.dart';

Future<void> mostrarSeleccionarEmpleado(
  BuildContext context,
  Function(EmpleadoDB) onEmpleadoSeleccionado,
) async {
  final screenWidth = MediaQuery.of(context).size.width;
  final isMobile = screenWidth < 600;

  if (isMobile) {
    // En móvil usar BottomSheet para mejor UX
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _EmpleadoBottomSheet(onEmpleadoSeleccionado: onEmpleadoSeleccionado),
    );
  } else {
    // En desktop usar Dialog
    showDialog(
      context: context,
      builder: (context) =>
          _EmpleadoDialog(onEmpleadoSeleccionado: onEmpleadoSeleccionado),
    );
  }
}

class _EmpleadoBottomSheet extends StatelessWidget {
  final Function(EmpleadoDB) onEmpleadoSeleccionado;

  const _EmpleadoBottomSheet({required this.onEmpleadoSeleccionado});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Título
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.badge, color: Color(0xFF16A34A), size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Seleccionar Empleado',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Lista de empleados
              Expanded(
                child: FutureBuilder<List<EmpleadoDB>>(
                  future: _cargarEmpleados(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return _buildError(snapshot.error);
                    }

                    final empleados = snapshot.data ?? [];

                    if (empleados.isEmpty) {
                      return _buildEmpty();
                    }

                    return Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: empleados.length,
                        itemBuilder: (context, index) {
                          return _buildEmpleadoTile(
                            context,
                            empleados[index],
                            onEmpleadoSeleccionado,
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmpleadoDialog extends StatelessWidget {
  final Function(EmpleadoDB) onEmpleadoSeleccionado;

  const _EmpleadoDialog({required this.onEmpleadoSeleccionado});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            Row(
              children: [
                const Icon(Icons.badge, color: Color(0xFF16A34A), size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Seleccionar Empleado',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Lista de empleados
            Flexible(
              child: FutureBuilder<List<EmpleadoDB>>(
                future: _cargarEmpleados(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return _buildError(snapshot.error);
                  }

                  final empleados = snapshot.data ?? [];

                  if (empleados.isEmpty) {
                    return _buildEmpty();
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: empleados.length,
                    itemBuilder: (context, index) {
                      return _buildEmpleadoTile(
                        context,
                        empleados[index],
                        onEmpleadoSeleccionado,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildEmpleadoTile(
  BuildContext context,
  EmpleadoDB empleado,
  Function(EmpleadoDB) onSeleccionado,
) {
  return Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF16A34A),
        child: Text(
          empleado.nombreEmpleado.substring(0, 1).toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        empleado.nombreEmpleado,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        empleado.cargoNombre ?? 'Sin cargo',
        style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
      ),
      trailing: empleado.telefono != null
          ? Text(
              empleado.telefono!,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: Colors.grey,
              ),
            )
          : null,
      onTap: () {
        Navigator.of(context).pop();
        onSeleccionado(empleado);
      },
    ),
  );
}

Widget _buildError(Object? error) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.red),
        const SizedBox(height: 16),
        Text(
          'Error al cargar empleados',
          style: TextStyle(fontSize: 16, color: Colors.red[700]),
        ),
        const SizedBox(height: 8),
        Text(
          '$error',
          style: const TextStyle(fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

Widget _buildEmpty() {
  return const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.person_off, size: 48, color: Colors.grey),
        SizedBox(height: 16),
        Text(
          'No hay empleados disponibles',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ],
    ),
  );
}

Future<List<EmpleadoDB>> _cargarEmpleados() async {
  try {
    final response = await Supabase.instance.client
        .from('empleado')
        .select(
          'id_empleado, nombre_empleado, id_cargo, telefono, cargo_empleado!inner(cargo)',
        )
        .order('nombre_empleado', ascending: true);

    return (response as List).map((json) => EmpleadoDB.fromJson(json)).toList();
  } catch (e) {
    throw Exception('Error al cargar empleados: $e');
  }
}
