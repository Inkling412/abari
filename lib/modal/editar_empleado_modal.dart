import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> mostrarEditarEmpleado(
  BuildContext context,
  Map<String, dynamic> empleado,
  VoidCallback onSuccess,
) async {
  final nombreController = TextEditingController(text: empleado['nombre_empleado'] ?? '');
  final telefonoController = TextEditingController(text: empleado['telefono'] ?? '');
  int? idCargoSeleccionado = empleado['id_cargo'] as int?;

  // Cargar cargos para el dropdown
  final cargos = await Supabase.instance.client
      .from('cargo_empleado')
      .select('id_cargo, cargo');

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Editar empleado'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: const InputDecoration(labelText: 'Nombre completo'),
              ),
              TextField(
                controller: telefonoController,
                decoration: const InputDecoration(labelText: 'Teléfono'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: idCargoSeleccionado,
                items: cargos.map<DropdownMenuItem<int>>((cargo) {
                  return DropdownMenuItem<int>(
                    value: cargo['id_cargo'] as int,
                    child: Text(cargo['cargo'] as String),
                  );
                }).toList(),
                onChanged: (value) => idCargoSeleccionado = value,
                decoration: const InputDecoration(labelText: 'Cargo'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nombre = nombreController.text.trim();
              final telefono = telefonoController.text.trim();

              if (nombre.isEmpty || idCargoSeleccionado == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nombre y cargo son obligatorios')),
                );
                return;
              }

              await Supabase.instance.client
                  .from('empleado')
                  .update({
                    'nombre_empleado': nombre,
                    'telefono': telefono.isEmpty ? null : telefono,
                    'id_cargo': idCargoSeleccionado,
                  })
                  .eq('id_empleado', empleado['id_empleado']);

              Navigator.pop(context);
              onSuccess();
            },
            child: const Text('Confirmar datos'),
          ),
        ],
      );
    },
  );
}
