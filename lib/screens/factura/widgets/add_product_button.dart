import 'package:flutter/material.dart';
import 'package:abari/models/producto_db.dart';
import 'producto_search_dialog.dart';

class AddProductButton extends StatelessWidget {
  final void Function(
    ProductoDB producto,
    double cantidad,
    double stockTotal,
    bool esGranel,
  )?
  onProductSelected;
  final Map<String, int> cantidadesEnCarrito;

  const AddProductButton({
    super.key,
    this.onProductSelected,
    this.cantidadesEnCarrito = const {},
  });

  Future<void> _abrirDialogoBusqueda(BuildContext context) async {
    final resultado = await showDialog<ProductoSeleccionado>(
      context: context,
      builder: (context) =>
          ProductoSearchDialog(cantidadesEnCarrito: cantidadesEnCarrito),
    );

    if (resultado != null) {
      onProductSelected?.call(
        resultado.producto,
        resultado.cantidad,
        resultado.stockTotal,
        resultado.esGranel,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _abrirDialogoBusqueda(context),
      icon: const Icon(Icons.add_circle_outline, size: 24),
      label: const Text(
        'Agregar Producto',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
    );
  }
}
