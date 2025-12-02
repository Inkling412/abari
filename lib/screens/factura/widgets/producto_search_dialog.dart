import 'package:flutter/material.dart';
import 'package:abari/models/producto_db.dart';
import 'package:abari/services/producto_service.dart';
import 'package:abari/core/utils/debouncer.dart';

/// Resultado del diálogo: producto seleccionado, cantidad y stock total
class ProductoSeleccionado {
  final ProductoDB producto;
  final double cantidad; // Puede ser decimal para productos a granel
  final double stockTotal;
  final bool esGranel;

  ProductoSeleccionado({
    required this.producto,
    required this.cantidad,
    required this.stockTotal,
    this.esGranel = false,
  });
}

class ProductoSearchDialog extends StatefulWidget {
  /// Mapa de código -> cantidad ya agregada al carrito
  final Map<String, int> cantidadesEnCarrito;

  const ProductoSearchDialog({super.key, this.cantidadesEnCarrito = const {}});

  @override
  State<ProductoSearchDialog> createState() => _ProductoSearchDialogState();
}

class _ProductoSearchDialogState extends State<ProductoSearchDialog> {
  final _controller = TextEditingController();
  final _debouncer = Debouncer(delay: const Duration(milliseconds: 300));
  final _productoService = ProductoService();

  List<ProductoAgrupado> _resultados = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _controller.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  void _buscarProductos(String query) {
    if (query.isEmpty) {
      setState(() {
        _resultados = [];
      });
      return;
    }

    _debouncer.run(() async {
      setState(() => _isSearching = true);

      final productosAgrupados = await _productoService
          .buscarProductosAgrupados(query);

      setState(() {
        _resultados = productosAgrupados;
        _isSearching = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        height: 500,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            Row(
              children: [
                const Text(
                  'Buscar Producto',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Campo de búsqueda
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _buscarProductos,
              decoration: InputDecoration(
                hintText: 'Escribe el nombre del producto...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Resultados
            Expanded(child: _buildResultados()),
          ],
        ),
      ),
    );
  }

  Widget _buildResultados() {
    if (_controller.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Escribe para buscar productos',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_resultados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No se encontraron productos',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _resultados.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final grupo = _resultados[index];
        final enCarritoNum = widget.cantidadesEnCarrito[grupo.codigo] ?? 0;
        final enCarrito = enCarritoNum.toDouble();
        final stockDisponible = grupo.stock - enCarrito;
        final colorScheme = Theme.of(context).colorScheme;
        final sinStock = stockDisponible <= 0;

        return Material(
          color: sinStock
              ? colorScheme.surfaceContainerLow
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: sinStock
                ? null
                : () =>
                      _mostrarSelectorCantidad(context, grupo, stockDisponible),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fila superior: Nombre y precio
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre del producto (expandido)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              grupo.nombreProducto,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: sinStock
                                    ? colorScheme.onSurface.withValues(
                                        alpha: 0.5,
                                      )
                                    : colorScheme.onSurface,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              grupo.codigo,
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Precio
                      if (grupo.precioVenta != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: sinStock
                                ? Colors.grey[300]
                                : colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'C\$${grupo.precioVenta!.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: sinStock
                                  ? Colors.grey[600]
                                  : colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Fila inferior: Badges de stock
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      // Badge de stock disponible
                      _buildBadge(
                        text: sinStock
                            ? 'Sin stock'
                            : 'Disponible: ${grupo.esGranel ? stockDisponible.toStringAsFixed(1) : stockDisponible.toInt()} ${grupo.unidadStock}',
                        backgroundColor: sinStock
                            ? Colors.red.withValues(alpha: 0.1)
                            : stockDisponible > 5
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                        textColor: sinStock
                            ? Colors.red[700]!
                            : stockDisponible > 5
                            ? Colors.green[700]!
                            : Colors.orange[700]!,
                        borderColor: sinStock
                            ? Colors.red[300]!
                            : stockDisponible > 5
                            ? Colors.green[300]!
                            : Colors.orange[300]!,
                        icon: sinStock
                            ? Icons.remove_shopping_cart_outlined
                            : Icons.inventory_2_outlined,
                      ),
                      // Badge de en carrito
                      if (enCarrito > 0)
                        _buildBadge(
                          text:
                              'En carrito: ${grupo.esGranel ? enCarrito.toStringAsFixed(1) : enCarrito.toInt()} ${grupo.unidadStock}',
                          backgroundColor: Colors.blue.withValues(alpha: 0.1),
                          textColor: Colors.blue[700]!,
                          borderColor: Colors.blue[300]!,
                          icon: Icons.shopping_cart_outlined,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBadge({
    required String text,
    required Color backgroundColor,
    required Color textColor,
    required Color borderColor,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarSelectorCantidad(
    BuildContext context,
    ProductoAgrupado grupo,
    double stockDisponible,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    // Para productos a granel usar double, para otros usar int
    double cantidadSeleccionada = grupo.esGranel ? 0.5 : 1.0;
    final incremento = grupo.esGranel ? 0.5 : 1.0;
    final cantidadController = TextEditingController(
      text: grupo.esGranel
          ? cantidadSeleccionada.toStringAsFixed(1)
          : cantidadSeleccionada.toInt().toString(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Formatear cantidad para mostrar
            String formatearCantidad(double cantidad) {
              if (grupo.esGranel) {
                return cantidad.toStringAsFixed(1);
              }
              return cantidad.toInt().toString();
            }

            return Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 16,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom +
                    MediaQuery.of(context).viewPadding.bottom +
                    24,
              ),
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
                  const SizedBox(height: 20),

                  // Título del producto
                  Text(
                    grupo.nombreProducto,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Presentación (cantidad + unidad + tipo)
                  if (grupo.presentacionFormateada.isNotEmpty)
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          grupo.presentacionFormateada,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  if (grupo.presentacionFormateada.isNotEmpty)
                    const SizedBox(height: 4),
                  Text(
                    grupo.codigo,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Info de stock y precio
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: stockDisponible > 5
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: stockDisponible > 5
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                        child: Text(
                          'Disponible: ${formatearCantidad(stockDisponible)} ${grupo.unidadStock}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: stockDisponible > 5
                                ? Colors.green[700]
                                : Colors.orange[700],
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (grupo.precioVenta != null)
                        Text(
                          grupo.esGranel
                              ? 'C\$${grupo.precioVenta!.toStringAsFixed(2)} / ${grupo.abreviaturaUnidad ?? 'unidad'}'
                              : 'C\$${grupo.precioVenta!.toStringAsFixed(2)} c/u',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Selector de cantidad
                  Text(
                    grupo.esGranel
                        ? 'Cantidad a agregar (${grupo.abreviaturaUnidad ?? 'unidades'})'
                        : 'Cantidad a agregar',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Botón decrementar
                      IconButton.filled(
                        onPressed: cantidadSeleccionada > incremento
                            ? () => setModalState(() {
                                cantidadSeleccionada -= incremento;
                                cantidadController.text = formatearCantidad(
                                  cantidadSeleccionada,
                                );
                              })
                            : null,
                        icon: const Icon(Icons.remove),
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          foregroundColor: colorScheme.onSurface,
                          disabledBackgroundColor:
                              colorScheme.surfaceContainerLow,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Campo de cantidad (editable para productos a granel)
                      Expanded(
                        child: grupo.esGranel
                            ? TextField(
                                controller: cantidadController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                onChanged: (value) {
                                  final parsed = double.tryParse(value);
                                  if (parsed != null &&
                                      parsed > 0 &&
                                      parsed <= stockDisponible) {
                                    setModalState(() {
                                      cantidadSeleccionada = parsed;
                                    });
                                  }
                                },
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: colorScheme.outline,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  formatearCantidad(cantidadSeleccionada),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(width: 16),
                      // Botón incrementar
                      IconButton.filled(
                        onPressed:
                            cantidadSeleccionada + incremento <= stockDisponible
                            ? () => setModalState(() {
                                cantidadSeleccionada += incremento;
                                cantidadController.text = formatearCantidad(
                                  cantidadSeleccionada,
                                );
                              })
                            : null,
                        icon: const Icon(Icons.add),
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          disabledBackgroundColor:
                              colorScheme.surfaceContainerLow,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Subtotal
                  if (grupo.precioVenta != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Subtotal: C\$${(grupo.precioVenta! * cantidadSeleccionada).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Botón agregar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          grupo.primerProducto != null &&
                              cantidadSeleccionada > 0 &&
                              cantidadSeleccionada <= stockDisponible
                          ? () {
                              Navigator.pop(
                                bottomContext,
                              ); // Cerrar bottom sheet
                              Navigator.pop(
                                this.context,
                                ProductoSeleccionado(
                                  producto: grupo.primerProducto!,
                                  cantidad: cantidadSeleccionada,
                                  stockTotal: grupo.stock,
                                  esGranel: grupo.esGranel,
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.add_shopping_cart),
                      label: Text(
                        'Agregar ${formatearCantidad(cantidadSeleccionada)} ${grupo.unidadStock}',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
