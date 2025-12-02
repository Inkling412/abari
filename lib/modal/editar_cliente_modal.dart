import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> mostrarEditarCliente(
  BuildContext context,
  Map<String, dynamic> cliente,
  VoidCallback onSuccess,
) async {
  final nombreController = TextEditingController(text: cliente['nombre_cliente']);
  final telefonoController = TextEditingController(text: cliente['numero_telefono'] ?? '');

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Editar cliente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreController,
              decoration: const InputDecoration(labelText: 'Nombre completo'),
            ),
            TextField(
              controller: telefonoController,
              decoration: const InputDecoration(labelText: 'Número de teléfono'),
              keyboardType: TextInputType.phone,
            ),
          ],
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

              if (nombre.isEmpty ) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nombre es obligatorio')),
                );
                return;
              }

              await Supabase.instance.client
                  .from('cliente')
                  .update({
                    'nombre_cliente': nombre,
                    'numero_telefono': telefono.isEmpty ? null : telefono,
                  })
                  .eq('id_cliente', cliente['id_cliente']);

              Navigator.pop(context);
              onSuccess(); // recarga la lista
            },
            child: const Text('Confirmar datos'),
          ),
        ],
      );
    },
  );
}
