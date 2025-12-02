import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:abari/providers/compra_provider.dart';
import 'package:abari/modal/seleccionar_empleado_modal.dart';
import 'package:abari/modal/agregar_producto_modal.dart';
import 'package:abari/modal/agregar_proveedor_modal.dart';

class ComprasScreen extends StatelessWidget {
  const ComprasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CompraProvider()
        ..cargarMetodosPago()
        ..cargarProveedores(),
      child: const _ComprasScreenContent(),
    );
  }
}

class _ComprasScreenContent extends StatelessWidget {
  const _ComprasScreenContent();

  void _agregarNuevoProducto(BuildContext context) {
    final provider = context.read<CompraProvider>();

    mostrarAgregarProducto(
      context,
      () {}, // onSuccess callback
      onProductoCreado: (productoCreado) {
        // Agregar el producto creado a la lista de compras
        provider.agregarProductoItem(
          ProductoCompraItem(
            idProductoBase: null, // Es un producto nuevo
            idPresentacion: productoCreado.idPresentacion,
            idUnidadMedida: productoCreado.idUnidadMedida,
            nombre: productoCreado.nombre,
            codigo: productoCreado.codigo,
            cantidadProducto: productoCreado.cantidad,
            fechaVencimiento: null,
            precioCompra: productoCreado.precioCompra,
            precioVenta: productoCreado.precioVenta,
            stock: productoCreado.stock,
            idCategoria: productoCreado.idCategoria,
          ),
        );
      },
    );
  }

  Future<void> _duplicarProducto(
    CompraProvider provider,
    ProductoCompraItem item,
  ) async {
    // Cargar presentación y unidad de medida para generar nuevo código
    final presentacionFuture = Supabase.instance.client
        .from('presentacion')
        .select('descripcion')
        .eq('id_presentacion', item.idPresentacion)
        .maybeSingle();

    final unidadMedidaFuture = item.idUnidadMedida != null
        ? Supabase.instance.client
              .from('unidad_medida')
              .select('abreviatura')
              .eq('id', item.idUnidadMedida!)
              .maybeSingle()
        : Future<Map<String, dynamic>?>.value(null);

    final results = await Future.wait([presentacionFuture, unidadMedidaFuture]);

    final presentacion = results[0];
    final unidadMedida = results[1];

    // Generar nuevo código
    final nuevoCodigo = _generarCodigo(
      nombre: item.nombre,
      cantidad: item.cantidadProducto,
      abreviaturaUnidad: unidadMedida?['abreviatura'] as String? ?? '',
      descripcionPresentacion: presentacion?['descripcion'] as String? ?? '',
    );

    // Crear una copia del producto con nuevo código
    provider.agregarProductoItem(
      ProductoCompraItem(
        idProductoBase: null, // Es un nuevo producto
        idPresentacion: item.idPresentacion,
        idUnidadMedida: item.idUnidadMedida,
        nombre: item.nombre,
        codigo: nuevoCodigo,
        cantidadProducto: item.cantidadProducto,
        fechaVencimiento: item.fechaVencimiento,
        precioCompra: item.precioCompra,
        precioVenta: item.precioVenta,
        stock: item.stock,
        idCategoria: item.idCategoria,
      ),
    );
  }

  /// Genera código único usando la misma lógica de agregar_producto_modal
  String _generarCodigo({
    required String nombre,
    required double cantidad,
    required String abreviaturaUnidad,
    required String descripcionPresentacion,
  }) {
    final nombreLimpio = nombre.trim().replaceAll(' ', '');
    final abreviatura = abreviaturaUnidad.replaceAll(' ', '');

    // Si la presentación tiene múltiples palabras, usar solo la última
    final palabras = descripcionPresentacion.trim().split(' ');
    final descripcionPres = palabras.length > 1
        ? palabras.last
        : descripcionPresentacion.replaceAll(' ', '');

    final esAGranel = descripcionPres.toLowerCase() == 'agranel';

    if (esAGranel) {
      // Para productos a granel: nombre + unidad de medida (sin cantidad)
      return '$nombreLimpio$abreviatura$descripcionPres'.toUpperCase();
    } else {
      // Para otros productos: nombre + cantidad + unidad + presentación
      final cantidadFormateada = cantidad == cantidad.toInt()
          ? cantidad.toInt().toString()
          : cantidad.toString();
      return '$nombreLimpio$cantidadFormateada$abreviatura$descripcionPres'
          .toUpperCase();
    }
  }

  void _editarProducto(
    BuildContext context,
    CompraProvider provider,
    int index,
    ProductoCompraItem item,
  ) {
    mostrarEditarProductoCompra(
      context,
      item: item,
      onProductoEditado: (productoEditado) {
        provider.actualizarProducto(index, productoEditado);
      },
    );
  }

  Widget _buildPriceChip(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarLimpiar(
    BuildContext context,
    CompraProvider provider,
  ) async {
    // Si no hay productos, limpiar directamente
    if (provider.productos.isEmpty) {
      provider.limpiarCompra();
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.warning_amber, color: Colors.orange[700], size: 48),
        title: const Text('¿Limpiar compra?'),
        content: const Text(
          'Se eliminarán todos los productos agregados y se reiniciará el formulario. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      provider.limpiarCompra();
    }
  }

  Widget _buildResumenRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color, {
    bool isLarge = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: isLarge ? 22 : 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isLarge ? 15 : 14,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isLarge ? 18 : 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatoFecha = DateFormat('dd/MM/yyyy');

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 800;
            final padding = isMobile ? 16.0 : 32.0;

            if (isMobile) {
              return _buildMobileLayout(context, formatoFecha, padding);
            }
            return _buildDesktopLayout(context, formatoFecha, padding);
          },
        ),
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    DateFormat formatoFecha,
    double padding,
  ) {
    return Consumer<CompraProvider>(
      builder: (context, provider, child) {
        final errorValidacion = provider.validarCompra();
        final isValid = errorValidacion == null;

        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Compras',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Proveedor
              Row(
                children: [
                  Expanded(
                    child: Autocomplete<String>(
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return provider.proveedores.map(
                            (p) => p.nombreProveedor,
                          );
                        }
                        return provider.proveedores
                            .where(
                              (p) => p.nombreProveedor.toLowerCase().contains(
                                textEditingValue.text.toLowerCase(),
                              ),
                            )
                            .map((p) => p.nombreProveedor);
                      },
                      onSelected: (value) => provider.setProveedor(value),
                      initialValue: TextEditingValue(text: provider.proveedor),
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText: 'Proveedor',
                                border: const OutlineInputBorder(),
                                isDense: true,
                                suffixIcon: controller.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          controller.clear();
                                          provider.setProveedor('');
                                        },
                                      )
                                    : null,
                              ),
                              onChanged: (value) {
                                // Actualizar proveedor si coincide exactamente
                                final match = provider.proveedores.where(
                                  (p) =>
                                      p.nombreProveedor.toLowerCase() ==
                                      value.toLowerCase(),
                                );
                                if (match.isNotEmpty) {
                                  provider.setProveedor(
                                    match.first.nombreProveedor,
                                  );
                                }
                              },
                            );
                          },
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Nuevo proveedor',
                    icon: const Icon(Icons.add_business),
                    onPressed: () {
                      mostrarAgregarProveedor(context, () {
                        context.read<CompraProvider>().cargarProveedores();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Método de pago
              DropdownButtonFormField<String>(
                value: provider.metodoPago.isEmpty ? null : provider.metodoPago,
                decoration: const InputDecoration(
                  labelText: 'Método de pago',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: provider.metodosPago
                    .map(
                      (m) => DropdownMenuItem<String>(
                        value: m.name,
                        child: Text(m.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) provider.setMetodoPago(value);
                },
              ),
              const SizedBox(height: 12),

              // Empleado y Fecha en fila
              Row(
                children: [
                  Expanded(
                    child: provider.empleado.isEmpty
                        ? OutlinedButton.icon(
                            onPressed: () {
                              mostrarSeleccionarEmpleado(context, (empleado) {
                                provider.setEmpleado(
                                  empleado.nombreEmpleado,
                                  empleadoId: empleado.idEmpleado,
                                );
                              });
                            },
                            icon: const Icon(Icons.badge, size: 18),
                            label: const Text(
                              'Empleado',
                              overflow: TextOverflow.ellipsis,
                            ),
                          )
                        : Chip(
                            avatar: const Icon(Icons.badge, size: 16),
                            label: Text(
                              provider.empleado,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onDeleted: () => provider.setEmpleado(''),
                            deleteIconColor: Colors.red,
                          ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: provider.fecha,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) provider.setFecha(picked);
                    },
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(formatoFecha.format(provider.fecha)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Lista de productos
              if (provider.productos.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No hay productos',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Agrega productos a la compra',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: provider.productos.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final subtotalCompra = item.precioCompra * item.stock;
                    final subtotalVenta = item.precioVenta * item.stock;
                    final ganancia = subtotalVenta - subtotalCompra;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        color: Theme.of(context).colorScheme.surface,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${item.stock}x',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item.nombre,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.edit_outlined,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    size: 20,
                                  ),
                                  onPressed: () => _editarProducto(
                                    context,
                                    provider,
                                    index,
                                    item,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Editar',
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.copy_outlined,
                                    color: Colors.orange[600],
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      _duplicarProducto(provider, item),
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Duplicar',
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: Colors.red[400],
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      provider.eliminarProducto(index),
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Eliminar',
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildPriceChip(
                                    context,
                                    'Compra',
                                    'C\$${subtotalCompra.toStringAsFixed(2)}',
                                    Colors.red,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildPriceChip(
                                    context,
                                    'Venta',
                                    'C\$${subtotalVenta.toStringAsFixed(2)}',
                                    Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildPriceChip(
                                    context,
                                    'Ganancia',
                                    'C\$${ganancia.toStringAsFixed(2)}',
                                    Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 12),

              // Botón de nuevo producto
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _agregarNuevoProducto(context),
                  icon: const Icon(Icons.add_box_outlined, size: 20),
                  label: const Text(
                    'Nuevo producto',
                    style: TextStyle(fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Resumen mejorado
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.5),
                      Theme.of(
                        context,
                      ).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                    ],
                  ),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.receipt_long,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Resumen de compra',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildResumenRow(
                      context,
                      'Total invertido',
                      'C\$${provider.totalCosto.toStringAsFixed(2)}',
                      Icons.shopping_bag_outlined,
                      Colors.red,
                      isLarge: true,
                    ),
                    const SizedBox(height: 12),
                    _buildResumenRow(
                      context,
                      'Venta esperable',
                      'C\$${provider.totalVentaEsperable.toStringAsFixed(2)}',
                      Icons.sell_outlined,
                      Colors.green,
                    ),
                    const SizedBox(height: 12),
                    _buildResumenRow(
                      context,
                      'Ganancia esperada',
                      'C\$${provider.gananciaEsperable.toStringAsFixed(2)}',
                      Icons.trending_up,
                      Colors.blue,
                    ),
                    if (!isValid && errorValidacion != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber,
                              color: Colors.red[400],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorValidacion,
                                style: TextStyle(
                                  color: Colors.red[400],
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Botones de acción
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmarLimpiar(context, provider),
                      icon: const Icon(Icons.clear_all, size: 20),
                      label: const Text('Limpiar'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: !isValid
                          ? null
                          : () => _guardarCompra(context, provider),
                      icon: const Icon(Icons.save, size: 20),
                      label: const Text(
                        'Guardar compra',
                        style: TextStyle(fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _guardarCompra(
    BuildContext context,
    CompraProvider provider,
  ) async {
    final error = await provider.guardarCompra();
    if (!context.mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red[700]),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('¡Compra guardada exitosamente!'),
          backgroundColor: Colors.green[700],
        ),
      );
      provider.limpiarCompra();
    }
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    DateFormat formatoFecha,
    double padding,
  ) {
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Columna izquierda: formulario principal
          Expanded(
            flex: 2,
            child: Consumer<CompraProvider>(
              builder: (context, provider, child) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Compras',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Proveedor y método de pago
                    Row(
                      children: [
                        Expanded(
                          child: Autocomplete<String>(
                            optionsBuilder: (textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                return provider.proveedores.map(
                                  (p) => p.nombreProveedor,
                                );
                              }
                              return provider.proveedores
                                  .where(
                                    (p) => p.nombreProveedor
                                        .toLowerCase()
                                        .contains(
                                          textEditingValue.text.toLowerCase(),
                                        ),
                                  )
                                  .map((p) => p.nombreProveedor);
                            },
                            onSelected: (value) => provider.setProveedor(value),
                            initialValue: TextEditingValue(
                              text: provider.proveedor,
                            ),
                            fieldViewBuilder:
                                (
                                  context,
                                  controller,
                                  focusNode,
                                  onFieldSubmitted,
                                ) {
                                  return TextField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    decoration: InputDecoration(
                                      labelText: 'Proveedor',
                                      border: const OutlineInputBorder(),
                                      suffixIcon: controller.text.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(
                                                Icons.clear,
                                                size: 18,
                                              ),
                                              onPressed: () {
                                                controller.clear();
                                                provider.setProveedor('');
                                              },
                                            )
                                          : null,
                                    ),
                                    onChanged: (value) {
                                      final match = provider.proveedores.where(
                                        (p) =>
                                            p.nombreProveedor.toLowerCase() ==
                                            value.toLowerCase(),
                                      );
                                      if (match.isNotEmpty) {
                                        provider.setProveedor(
                                          match.first.nombreProveedor,
                                        );
                                      }
                                    },
                                  );
                                },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Nuevo proveedor',
                          icon: const Icon(Icons.add_business),
                          onPressed: () {
                            mostrarAgregarProveedor(context, () {
                              context
                                  .read<CompraProvider>()
                                  .cargarProveedores();
                            });
                          },
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: provider.metodoPago.isEmpty
                                ? null
                                : provider.metodoPago,
                            decoration: const InputDecoration(
                              labelText: 'Método de pago',
                              border: OutlineInputBorder(),
                            ),
                            items: provider.metodosPago
                                .map(
                                  (m) => DropdownMenuItem<String>(
                                    value: m.name,
                                    child: Text(m.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                provider.setMetodoPago(value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Tabla sencilla de productos de compra
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade700),
                          color: Theme.of(context).colorScheme.surface,
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Producto',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                          ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Cant.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                          ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'P. Compra',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                          ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'P. Venta',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                          ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Vence',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 40),
                                ],
                              ),
                            ),
                            Expanded(
                              child: provider.productos.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No hay productos en la compra',
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: provider.productos.length,
                                      itemBuilder: (context, index) {
                                        final item = provider.productos[index];
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              top: BorderSide(
                                                color: Colors.grey.shade300,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 2,
                                                child: Text(item.nombre),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  item.stock.toString(),
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  'C\$${item.precioCompra.toStringAsFixed(2)}',
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  'C\$${item.precioVenta.toStringAsFixed(2)}',
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  item.fechaVencimiento ?? '-',
                                                ),
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: Icon(
                                                      Icons.edit_outlined,
                                                      color: Theme.of(
                                                        context,
                                                      ).colorScheme.primary,
                                                      size: 20,
                                                    ),
                                                    onPressed: () =>
                                                        _editarProducto(
                                                          context,
                                                          provider,
                                                          index,
                                                          item,
                                                        ),
                                                    tooltip: 'Editar',
                                                  ),
                                                  IconButton(
                                                    icon: Icon(
                                                      Icons.copy_outlined,
                                                      color: Colors.orange[600],
                                                      size: 20,
                                                    ),
                                                    onPressed: () =>
                                                        _duplicarProducto(
                                                          provider,
                                                          item,
                                                        ),
                                                    tooltip: 'Duplicar',
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.delete_outline,
                                                      color: Colors.red,
                                                      size: 20,
                                                    ),
                                                    onPressed: () {
                                                      provider.eliminarProducto(
                                                        index,
                                                      );
                                                    },
                                                    tooltip: 'Eliminar',
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _agregarNuevoProducto(context),
                        icon: const Icon(Icons.add_box_outlined),
                        label: const Text('Nuevo producto'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(width: 24),

          // Columna derecha: resumen y empleado/fecha
          SizedBox(
            width: 360,
            child: Consumer<CompraProvider>(
              builder: (context, provider, child) {
                final errorValidacion = provider.validarCompra();
                final isValid = errorValidacion == null;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Resumen de compra',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Total invertido: C\$${provider.totalCosto.toStringAsFixed(2)}',
                            ),
                            Text(
                              'Venta esperable: C\$${provider.totalVentaEsperable.toStringAsFixed(2)}',
                            ),
                            Text(
                              'Ganancia esperable: C\$${provider.gananciaEsperable.toStringAsFixed(2)}',
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      provider.limpiarCompra();
                                    },
                                    child: const Text('Limpiar'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: !isValid
                                        ? null
                                        : () async {
                                            final error = await provider
                                                .guardarCompra();

                                            if (!context.mounted) return;

                                            if (error != null) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(error),
                                                  backgroundColor:
                                                      Colors.red[700],
                                                ),
                                              );
                                            } else {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: const Text(
                                                    '¡Compra guardada exitosamente!',
                                                  ),
                                                  backgroundColor:
                                                      Colors.green[700],
                                                ),
                                              );
                                              provider.limpiarCompra();
                                            }
                                          },
                                    icon: const Icon(Icons.save),
                                    label: const Text('Guardar'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (!isValid && provider.productos.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  errorValidacion!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Empleado',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            provider.empleado.isEmpty
                                ? OutlinedButton.icon(
                                    onPressed: () {
                                      mostrarSeleccionarEmpleado(context, (
                                        empleado,
                                      ) {
                                        provider.setEmpleado(
                                          empleado.nombreEmpleado,
                                          empleadoId: empleado.idEmpleado,
                                        );
                                      });
                                    },
                                    icon: const Icon(Icons.badge),
                                    label: const Text('Seleccionar empleado'),
                                  )
                                : Row(
                                    children: [
                                      const Icon(Icons.badge, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(provider.empleado)),
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 18),
                                        onPressed: () {
                                          provider.setEmpleado('');
                                        },
                                      ),
                                    ],
                                  ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Fecha de compra',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: provider.fecha,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  provider.setFecha(picked);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 18),
                                    const SizedBox(width: 8),
                                    Text(formatoFecha.format(provider.fecha)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal para editar un producto de la lista de compras
Future<void> mostrarEditarProductoCompra(
  BuildContext context, {
  required ProductoCompraItem item,
  required void Function(ProductoCompraItem) onProductoEditado,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _EditarProductoCompraSheet(
      item: item,
      onProductoEditado: onProductoEditado,
    ),
  );
}

class _EditarProductoCompraSheet extends StatefulWidget {
  final ProductoCompraItem item;
  final void Function(ProductoCompraItem) onProductoEditado;

  const _EditarProductoCompraSheet({
    required this.item,
    required this.onProductoEditado,
  });

  @override
  State<_EditarProductoCompraSheet> createState() =>
      _EditarProductoCompraSheetState();
}

class _EditarProductoCompraSheetState
    extends State<_EditarProductoCompraSheet> {
  late TextEditingController _nombreController;
  late TextEditingController _codigoController;
  late TextEditingController _cantidadController;
  late TextEditingController _precioCompraController;
  late TextEditingController _precioVentaController;
  late TextEditingController _stockController;

  // Variables de estado para opciones avanzadas
  late int _idPresentacion;
  late int? _idUnidadMedida;

  // Para generación de código
  String _descripcionPresentacion = '';
  String _abreviaturaUnidad = '';

  // Categorías
  List<Map<String, dynamic>> _categorias = [];
  int? _categoriaSeleccionada;
  bool _cargandoCategorias = true;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.item.nombre);
    _codigoController = TextEditingController(text: widget.item.codigo);
    _cantidadController = TextEditingController(
      text: widget.item.cantidadProducto.toString(),
    );
    _precioCompraController = TextEditingController(
      text: widget.item.precioCompra.toString(),
    );
    _precioVentaController = TextEditingController(
      text: widget.item.precioVenta.toString(),
    );
    _stockController = TextEditingController(
      text: widget.item.stock.toString(),
    );

    // Inicializar opciones avanzadas
    _idPresentacion = widget.item.idPresentacion;
    _idUnidadMedida = widget.item.idUnidadMedida;
    _categoriaSeleccionada = widget.item.idCategoria;

    // Listeners para regenerar código
    _nombreController.addListener(_actualizarCodigo);
    _cantidadController.addListener(_actualizarCodigo);

    _cargarDatosIniciales();
  }

  Future<void> _cargarDatosIniciales() async {
    await Future.wait([_cargarPresentacionYUnidad(), _cargarCategorias()]);
  }

  Future<void> _cargarPresentacionYUnidad() async {
    try {
      final presentacion = await Supabase.instance.client
          .from('presentacion')
          .select('descripcion')
          .eq('id_presentacion', _idPresentacion)
          .maybeSingle();

      Map<String, dynamic>? unidad;
      if (_idUnidadMedida != null) {
        unidad = await Supabase.instance.client
            .from('unidad_medida')
            .select('abreviatura')
            .eq('id', _idUnidadMedida!)
            .maybeSingle();
      }

      if (mounted) {
        setState(() {
          _descripcionPresentacion =
              presentacion?['descripcion'] as String? ?? '';
          _abreviaturaUnidad = unidad?['abreviatura'] as String? ?? '';
        });
        _actualizarCodigo();
      }
    } catch (e) {
      // Ignorar errores
    }
  }

  void _actualizarCodigo() {
    if (_descripcionPresentacion.isEmpty) return;

    final nombre = _nombreController.text.trim();
    final cantidad = double.tryParse(_cantidadController.text) ?? 0;

    if (nombre.isEmpty) return;

    final nuevoCodigo = _generarCodigoLocal(
      nombre: nombre,
      cantidad: cantidad,
      abreviaturaUnidad: _abreviaturaUnidad,
      descripcionPresentacion: _descripcionPresentacion,
    );

    if (_codigoController.text != nuevoCodigo) {
      _codigoController.text = nuevoCodigo;
    }
  }

  String _generarCodigoLocal({
    required String nombre,
    required double cantidad,
    required String abreviaturaUnidad,
    required String descripcionPresentacion,
  }) {
    final nombreLimpio = nombre.replaceAll(' ', '');
    final abreviatura = abreviaturaUnidad.replaceAll(' ', '');

    final palabras = descripcionPresentacion.trim().split(' ');
    final descripcionPres = palabras.length > 1
        ? palabras.last
        : descripcionPresentacion.replaceAll(' ', '');

    final esAGranel = descripcionPres.toLowerCase() == 'agranel';

    if (esAGranel) {
      return '$nombreLimpio$abreviatura$descripcionPres'.toUpperCase();
    } else {
      final cantidadFormateada = cantidad == cantidad.toInt()
          ? cantidad.toInt().toString()
          : cantidad.toString();
      return '$nombreLimpio$cantidadFormateada$abreviatura$descripcionPres'
          .toUpperCase();
    }
  }

  Future<void> _cargarCategorias() async {
    try {
      final response = await Supabase.instance.client
          .from('categoria')
          .select('id, nombre')
          .order('nombre', ascending: true);

      if (mounted) {
        setState(() {
          _categorias = (response as List)
              .map(
                (item) => {
                  'id': item['id'],
                  'nombre': item['nombre']?.toString() ?? 'Sin categoría',
                },
              )
              .toList();
          _cargandoCategorias = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargandoCategorias = false);
      }
    }
  }

  @override
  void dispose() {
    _nombreController.removeListener(_actualizarCodigo);
    _cantidadController.removeListener(_actualizarCodigo);
    _nombreController.dispose();
    _codigoController.dispose();
    _cantidadController.dispose();
    _precioCompraController.dispose();
    _precioVentaController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  void _guardar() {
    final nombre = _nombreController.text.trim();
    final codigo = _codigoController.text.trim();
    final cantidad = double.tryParse(_cantidadController.text) ?? 0;
    final precioCompra = double.tryParse(_precioCompraController.text) ?? 0;
    final precioVenta = double.tryParse(_precioVentaController.text) ?? 0;
    final stock = int.tryParse(_stockController.text) ?? 1;
    final idCategoria = _categoriaSeleccionada;

    if (nombre.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('El nombre es requerido')));
      return;
    }

    final productoEditado = ProductoCompraItem(
      idProductoBase: widget.item.idProductoBase,
      idPresentacion: _idPresentacion,
      idUnidadMedida: _idUnidadMedida,
      nombre: nombre,
      codigo: codigo,
      cantidadProducto: cantidad,
      fechaVencimiento: widget.item.fechaVencimiento,
      precioCompra: precioCompra,
      precioVenta: precioVenta,
      stock: stock,
      idCategoria: idCategoria,
    );

    widget.onProductoEditado(productoEditado);
    Navigator.pop(context);
  }

  void _abrirOpcionesAvanzadas() async {
    final resultado = await showModalBottomSheet<Map<String, int?>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OpcionesAvanzadasSheet(
        idPresentacionActual: _idPresentacion,
        idUnidadMedidaActual: _idUnidadMedida,
      ),
    );

    if (resultado != null && mounted) {
      // Actualizar las variables de estado locales
      setState(() {
        _idPresentacion = resultado['idPresentacion'] ?? _idPresentacion;
        _idUnidadMedida = resultado['idUnidadMedida'];
      });
      // Recargar datos de presentación/unidad para regenerar código
      _cargarPresentacionYUnidad();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
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
            Row(
              children: [
                Icon(Icons.edit, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Editar producto',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Nombre
            TextField(
              controller: _nombreController,
              decoration: const InputDecoration(
                labelText: 'Nombre del producto',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
            ),
            const SizedBox(height: 12),

            // Código y Cantidad en fila
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codigoController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Código (auto)',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.qr_code),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest
                          .withOpacity(0.5),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _cantidadController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad (g/ml)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.scale),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Precios en fila
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _precioCompraController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Precio compra',
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(Icons.money_off, color: Colors.red[400]),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _precioVentaController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Precio venta',
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(
                        Icons.attach_money,
                        color: Colors.green[600],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Stock y Categoría en fila
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Unidades',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.numbers),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _cargandoCategorias
                      ? const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : DropdownButtonFormField<int>(
                          value: _categoriaSeleccionada,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Categoría',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          items: [
                            const DropdownMenuItem<int>(
                              value: null,
                              child: Text('Sin categoría'),
                            ),
                            ..._categorias.map(
                              (cat) => DropdownMenuItem<int>(
                                value: cat['id'] as int?,
                                child: Text(
                                  cat['nombre']?.toString() ?? '',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => _categoriaSeleccionada = value);
                          },
                        ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Botón de opciones avanzadas
            TextButton.icon(
              onPressed: _abrirOpcionesAvanzadas,
              icon: Icon(Icons.tune, size: 18, color: colorScheme.secondary),
              label: Text(
                'Opciones avanzadas (presentación, unidad de medida...)',
                style: TextStyle(color: colorScheme.secondary, fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),

            // Botones
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _guardar,
                    icon: const Icon(Icons.check),
                    label: const Text('Guardar cambios'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Modal pequeño para opciones avanzadas (presentación y unidad de medida)
class _OpcionesAvanzadasSheet extends StatefulWidget {
  final int idPresentacionActual;
  final int? idUnidadMedidaActual;

  const _OpcionesAvanzadasSheet({
    required this.idPresentacionActual,
    this.idUnidadMedidaActual,
  });

  @override
  State<_OpcionesAvanzadasSheet> createState() =>
      _OpcionesAvanzadasSheetState();
}

class _OpcionesAvanzadasSheetState extends State<_OpcionesAvanzadasSheet> {
  List<dynamic> presentaciones = [];
  List<dynamic> unidadesMedida = [];
  bool cargando = true;

  int? presentacionSeleccionada;
  int? unidadMedidaSeleccionada;

  @override
  void initState() {
    super.initState();
    presentacionSeleccionada = widget.idPresentacionActual;
    unidadMedidaSeleccionada = widget.idUnidadMedidaActual;
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final futures = await Future.wait([
        Supabase.instance.client
            .from('presentacion')
            .select('id_presentacion,descripcion')
            .order('descripcion', ascending: true),
        Supabase.instance.client
            .from('unidad_medida')
            .select('id,nombre,abreviatura')
            .order('nombre', ascending: true),
      ]);

      if (mounted) {
        setState(() {
          presentaciones = futures[0] as List;
          unidadesMedida = futures[1] as List;
          cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => cargando = false);
      }
    }
  }

  void _guardar() {
    Navigator.pop(context, {
      'idPresentacion': presentacionSeleccionada,
      'idUnidadMedida': unidadMedidaSeleccionada,
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
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
            Row(
              children: [
                Icon(Icons.tune, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Opciones avanzadas',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (cargando)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              // Presentación
              Text(
                'Presentación',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: presentacionSeleccionada,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                  hintText: 'Seleccionar presentación',
                ),
                items: presentaciones.map((p) {
                  return DropdownMenuItem<int>(
                    value: p['id_presentacion'] as int,
                    child: Text(p['descripcion'] as String),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => presentacionSeleccionada = value);
                },
              ),
              const SizedBox(height: 16),

              // Unidad de medida
              Text(
                'Unidad de medida',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: unidadMedidaSeleccionada,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.straighten),
                  hintText: 'Seleccionar unidad',
                ),
                items: unidadesMedida.map((u) {
                  final nombre = u['nombre'] as String;
                  final abrev = u['abreviatura'] as String?;
                  return DropdownMenuItem<int>(
                    value: u['id'] as int,
                    child: Text(abrev != null ? '$nombre ($abrev)' : nombre),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => unidadMedidaSeleccionada = value);
                },
              ),
              const SizedBox(height: 24),

              // Botones
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: presentacionSeleccionada != null
                          ? _guardar
                          : null,
                      icon: const Icon(Icons.check),
                      label: const Text('Aplicar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
