import 'package:flutter/material.dart';

class ProductoFactura {
  final int idProducto;
  final double cantidad; // Puede ser decimal para productos a granel
  final String nombre;
  final String presentacion;
  final String medida;
  final String fechaVencimiento;
  final double precio; // Precio de venta
  final double precioCompra; // Precio de compra (costo)
  final double stockMaximo; // Stock total disponible en BD
  final bool esGranel; // Si es producto a granel
  final String? unidadMedida; // Abreviatura de la unidad (ej: "Lb")

  ProductoFactura({
    required this.idProducto,
    required this.cantidad,
    required this.nombre,
    required this.presentacion,
    required this.medida,
    required this.fechaVencimiento,
    required this.precio,
    this.precioCompra = 0.0,
    this.stockMaximo = 0,
    this.esGranel = false,
    this.unidadMedida,
  });

  /// Obtiene la cantidad formateada según el tipo de producto
  String get cantidadFormateada {
    if (esGranel) {
      return cantidad.toStringAsFixed(1);
    }
    return cantidad.toInt().toString();
  }

  /// Obtiene el texto de la unidad
  String get unidadTexto =>
      esGranel ? (unidadMedida ?? 'unidades') : 'unidades';
}

class InvoiceTable extends StatelessWidget {
  final List<ProductoFactura> productos;
  final Function(int index, double nuevaCantidad)? onCantidadChanged;

  const InvoiceTable({
    super.key,
    required this.productos,
    this.onCantidadChanged,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    if (isMobile) {
      return _buildMobileView(context);
    }
    return _buildDesktopView(context);
  }

  Widget _buildMobileView(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (productos.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      children: productos.asMap().entries.map((entry) {
        final index = entry.key;
        final producto = entry.value;
        return GestureDetector(
          onTap: () => _showProductoDetails(context, producto, index),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                // Info principal
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        producto.nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${producto.cantidadFormateada} ${producto.esGranel ? producto.unidadMedida ?? '' : ''} x C\$${producto.precio.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (producto.stockMaximo > 0)
                        Text(
                          'Stock: ${producto.esGranel ? producto.stockMaximo.toStringAsFixed(1) : producto.stockMaximo.toInt()} ${producto.unidadTexto}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                // Controles de cantidad
                _buildCantidadControls(context, producto, index),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCantidadControls(
    BuildContext context,
    ProductoFactura producto,
    int index,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Botón decrementar
        IconButton(
          icon: Icon(
            Icons.remove_circle_outline,
            color: producto.cantidad > (producto.esGranel ? 0.5 : 1)
                ? colorScheme.error
                : colorScheme.outline,
          ),
          onPressed: producto.cantidad > (producto.esGranel ? 0.5 : 1)
              ? () => onCantidadChanged?.call(
                  index,
                  producto.cantidad - (producto.esGranel ? 0.5 : 1),
                )
              : null,
          tooltip: producto.cantidad > (producto.esGranel ? 0.5 : 1)
              ? 'Reducir cantidad'
              : 'Cantidad mínima',
          iconSize: 28,
        ),
        // Cantidad actual
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${producto.cantidadFormateada} ${producto.esGranel ? producto.unidadMedida ?? '' : ''}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        // Botón incrementar
        IconButton(
          icon: Icon(
            Icons.add_circle_outline,
            color: producto.cantidad < producto.stockMaximo
                ? colorScheme.primary
                : colorScheme.outline,
          ),
          onPressed: producto.cantidad < producto.stockMaximo
              ? () => onCantidadChanged?.call(
                  index,
                  producto.cantidad + (producto.esGranel ? 0.5 : 1),
                )
              : null,
          tooltip: producto.cantidad < producto.stockMaximo
              ? 'Aumentar cantidad'
              : 'Stock máximo alcanzado',
          iconSize: 28,
        ),
      ],
    );
  }

  void _showProductoDetails(
    BuildContext context,
    ProductoFactura producto,
    int index,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Título
                Text(
                  producto.nombre,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Detalles
                _buildDetailRow(
                  context,
                  'Cantidad',
                  producto.cantidad.toString(),
                ),
                _buildDetailRow(context, 'Presentación', producto.presentacion),
                _buildDetailRow(context, 'Medida', producto.medida),
                _buildDetailRow(
                  context,
                  'Vencimiento',
                  producto.fechaVencimiento,
                ),
                _buildDetailRow(
                  context,
                  'Precio Unitario',
                  'C\$${producto.precio.toStringAsFixed(2)}',
                  isPrimary: true,
                ),
                const Divider(height: 24),
                _buildDetailRow(
                  context,
                  'Subtotal',
                  'C\$${(producto.precio * producto.cantidad).toStringAsFixed(2)}',
                  isPrimary: true,
                  isLarge: true,
                ),

                const SizedBox(height: 16),

                // Botón cerrar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cerrar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    bool isPrimary = false,
    bool isLarge = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isLarge ? 16 : 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isLarge ? 20 : 16,
              fontWeight: isPrimary ? FontWeight.bold : FontWeight.w500,
              color: isPrimary ? colorScheme.primary : colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopView(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              border: Border(
                bottom: BorderSide(color: colorScheme.outlineVariant, width: 2),
              ),
            ),
            child: Row(
              children: [
                _buildHeaderCell(context, 'Cant.', flex: 1),
                _buildHeaderCell(context, 'Producto', flex: 2),
                _buildHeaderCell(context, 'Presentación', flex: 2),
                _buildHeaderCell(context, 'Medida', flex: 2),
                _buildHeaderCell(context, 'Vencimiento', flex: 2),
                _buildHeaderCell(context, 'Precio Ind.', flex: 2),
                _buildHeaderCell(context, 'Acciones', flex: 2),
              ],
            ),
          ),
          // Rows
          if (productos.isEmpty)
            _buildEmptyState(context)
          else
            ...productos.asMap().entries.map((entry) {
              final index = entry.key;
              final producto = entry.value;
              return _buildRow(context, producto, index.isEven, index);
            }),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_basket_outlined,
            size: 64,
            color: colorScheme.outline.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No hay productos en la factura',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega productos usando el botón de abajo',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(BuildContext context, String text, {int flex = 1}) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Text(
          text,
          style: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    ProductoFactura producto,
    bool isEven,
    int index,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: isEven ? colorScheme.surfaceContainerLow : colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          _buildCell(context, producto.cantidad.toString(), flex: 1),
          _buildCell(context, producto.nombre, flex: 2),
          _buildCell(context, producto.presentacion, flex: 2),
          _buildCell(context, producto.medida, flex: 2),
          _buildCell(context, producto.fechaVencimiento, flex: 2),
          _buildCell(
            context,
            'C\$${producto.precio.toStringAsFixed(2)}',
            flex: 2,
            isMoney: true,
          ),
          _buildActionCell(context, producto, index),
        ],
      ),
    );
  }

  Widget _buildCell(
    BuildContext context,
    String text, {
    int flex = 1,
    bool isMoney = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Text(
          text,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: isMoney ? FontWeight.w600 : FontWeight.w400,
            color: isMoney ? colorScheme.primary : colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildActionCell(
    BuildContext context,
    ProductoFactura producto,
    int index,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      flex: 2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Botón decrementar
            IconButton(
              icon: Icon(
                Icons.remove_circle_outline,
                color: producto.cantidad > (producto.esGranel ? 0.5 : 1)
                    ? colorScheme.error
                    : colorScheme.outline,
                size: 22,
              ),
              onPressed: producto.cantidad > (producto.esGranel ? 0.5 : 1)
                  ? () => onCantidadChanged?.call(
                      index,
                      producto.cantidad - (producto.esGranel ? 0.5 : 1),
                    )
                  : null,
              tooltip: producto.cantidad > (producto.esGranel ? 0.5 : 1)
                  ? 'Reducir cantidad'
                  : 'Cantidad mínima',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
            ),
            // Cantidad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '${producto.cantidadFormateada} ${producto.esGranel ? producto.unidadMedida ?? '' : ''}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            // Botón incrementar
            IconButton(
              icon: Icon(
                Icons.add_circle_outline,
                color: producto.cantidad < producto.stockMaximo
                    ? colorScheme.primary
                    : colorScheme.outline,
                size: 22,
              ),
              onPressed: producto.cantidad < producto.stockMaximo
                  ? () => onCantidadChanged?.call(
                      index,
                      producto.cantidad + (producto.esGranel ? 0.5 : 1),
                    )
                  : null,
              tooltip: producto.cantidad < producto.stockMaximo
                  ? 'Aumentar cantidad'
                  : 'Stock máximo',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
