import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> mostrarAgregarCliente(BuildContext context, VoidCallback onSuccess) async {
  final nombreController = TextEditingController();
  final telefonoController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Agregar cliente'),
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

              if (nombre.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nombre es obligatorio')),
                );
                return;
              }

              await Supabase.instance.client.from('cliente').insert({
                'nombre_cliente': nombre,
                'numero_telefono': telefono.isEmpty ? null : telefono,
              });

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
