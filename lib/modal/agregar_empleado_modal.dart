import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> mostrarAgregarEmpleado(
  BuildContext context,
  VoidCallback onSuccess,
) async {
  final nombreController = TextEditingController();
  final telefonoController = TextEditingController();
  int? idCargoSeleccionado;

  final cargosResponse = await Supabase.instance.client
      .from('cargo_empleado')
      .select('id_cargo, cargo')
      .order('cargo', ascending: true);

  List<dynamic> listaCargos = cargosResponse as List;

  // Función para agregar nuevo cargo
  Future<void> agregarNuevoCargo(
    BuildContext context,
    StateSetter setState,
  ) async {
    final cargoController = TextEditingController();

    final resultado = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.work_outline),
              SizedBox(width: 8),
              Text('Nuevo Cargo'),
            ],
          ),
          content: TextField(
            controller: cargoController,
            decoration: const InputDecoration(
              labelText: 'Nombre del cargo *',
              border: OutlineInputBorder(),
              hintText: 'Ej: Vendedor, Cajero, Gerente',
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final cargo = cargoController.text.trim();
                if (cargo.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('El nombre del cargo es obligatorio'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                Navigator.pop(context, cargo);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (resultado != null && resultado.isNotEmpty) {
      try {
        // Insertar nuevo cargo
        final nuevoCargoResponse = await Supabase.instance.client
            .from('cargo_empleado')
            .insert({'cargo': resultado})
            .select()
            .single();

        // Recargar lista de cargos
        final cargosActualizados = await Supabase.instance.client
            .from('cargo_empleado')
            .select('id_cargo, cargo')
            .order('cargo', ascending: true);

        setState(() {
          listaCargos = cargosActualizados as List;
          idCargoSeleccionado = nuevoCargoResponse['id_cargo'] as int;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cargo "$resultado" agregado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al agregar cargo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.person_add),
                SizedBox(width: 8),
                Text('Agregar empleado'),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nombreController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo *',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: telefonoController,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      border: OutlineInputBorder(),
                      hintText: 'Opcional',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: idCargoSeleccionado,
                          items: listaCargos.map<DropdownMenuItem<int>>((
                            cargo,
                          ) {
                            return DropdownMenuItem<int>(
                              value: cargo['id_cargo'] as int,
                              child: Text(cargo['cargo']?.toString() ?? ''),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              idCargoSeleccionado = value;
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: 'Cargo *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Agregar nuevo cargo',
                        child: IconButton(
                          onPressed: () => agregarNuevoCargo(context, setState),
                          icon: const Icon(Icons.add_circle),
                          color: Colors.green[700],
                          iconSize: 32,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.green.withOpacity(0.1),
                          ),
                        ),
                      ),
                    ],
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

                  if (nombre.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('El nombre es obligatorio')),
                    );
                    return;
                  }

                  if (idCargoSeleccionado == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Debe seleccionar un cargo'),
                      ),
                    );
                    return;
                  }

                  try {
                    await Supabase.instance.client.from('empleado').insert({
                      'nombre_empleado': nombre,
                      'telefono': telefono.isEmpty ? null : telefono,
                      'id_cargo': idCargoSeleccionado,
                    });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Empleado "$nombre" agregado correctamente',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                    onSuccess();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al agregar empleado: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text('Confirmar datos'),
              ),
            ],
          );
        },
      );
    },
  );
}
