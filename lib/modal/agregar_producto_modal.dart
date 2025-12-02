import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Datos del producto creado para ser usado en compras
class ProductoCreado {
  final String nombre;
  final String codigo;
  final int idPresentacion;
  final int? idUnidadMedida;
  final double cantidad;
  final double precioCompra;
  final double precioVenta;
  final int stock;
  final int? idCategoria;

  ProductoCreado({
    required this.nombre,
    required this.codigo,
    required this.idPresentacion,
    this.idUnidadMedida,
    required this.cantidad,
    required this.precioCompra,
    required this.precioVenta,
    required this.stock,
    this.idCategoria,
  });
}

/// Datos iniciales para editar un producto existente
class ProductoInicial {
  final String? nombre;
  final String? codigo;
  final int? idPresentacion;
  final int? idUnidadMedida;
  final double? cantidad;
  final double? precioCompra;
  final double? precioVenta;
  final int? stock;
  final int? idCategoria;

  const ProductoInicial({
    this.nombre,
    this.codigo,
    this.idPresentacion,
    this.idUnidadMedida,
    this.cantidad,
    this.precioCompra,
    this.precioVenta,
    this.stock,
    this.idCategoria,
  });
}

Future<void> mostrarAgregarProducto(
  BuildContext context,
  VoidCallback onSuccess, {
  void Function(ProductoCreado)? onProductoCreado,
  ProductoInicial? datosIniciales,
}) async {
  try {
    // Cargar datos iniciales
    final presentaciones = await Supabase.instance.client
        .from('presentacion')
        .select('id_presentacion,descripcion')
        .order('descripcion', ascending: true);

    final unidadesMedida = await Supabase.instance.client
        .from('unidad_medida')
        .select('id,nombre,abreviatura')
        .order('nombre', ascending: true);

    final categoriasResponse = await Supabase.instance.client
        .from('categoria')
        .select('id, nombre')
        .order('nombre', ascending: true);

    final List<Map<String, dynamic>> categoriasList = [];
    for (final item in (categoriasResponse as List)) {
      categoriasList.add({
        'id': item['id'],
        'nombre': item['nombre']?.toString() ?? 'Sin categoría',
      });
    }

    if (!context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _AgregarProductoPage(
          listaPresentaciones: presentaciones as List,
          listaUnidadesMedida: unidadesMedida as List,
          listaCategorias: categoriasList,
          onSuccess: onSuccess,
          onProductoCreado: onProductoCreado,
          datosIniciales: datosIniciales,
        ),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    Fluttertoast.showToast(
      msg: 'Error al cargar datos: $e',
      backgroundColor: Colors.red,
      toastLength: Toast.LENGTH_LONG,
    );
  }
}

class _AgregarProductoPage extends StatefulWidget {
  final List<dynamic> listaPresentaciones;
  final List<dynamic> listaUnidadesMedida;
  final List<Map<String, dynamic>> listaCategorias;
  final VoidCallback onSuccess;
  final void Function(ProductoCreado)? onProductoCreado;
  final ProductoInicial? datosIniciales;

  const _AgregarProductoPage({
    required this.listaPresentaciones,
    required this.listaUnidadesMedida,
    required this.listaCategorias,
    required this.onSuccess,
    this.onProductoCreado,
    this.datosIniciales,
  });

  @override
  State<_AgregarProductoPage> createState() => _AgregarProductoPageState();
}

class _AgregarProductoPageState extends State<_AgregarProductoPage> {
  // Controllers
  final nombreController = TextEditingController();
  final cantidadController = TextEditingController();
  final stockController = TextEditingController(text: '1');
  final fechaAgregadoController = TextEditingController();
  final precioCompraController = TextEditingController();
  final precioVentaController = TextEditingController();
  final pageController = PageController();

  // State
  int stock = 1;
  bool usarFechaPersonalizada = false;
  int currentStep = 0;
  static const totalSteps = 3;

  int? presentacionSeleccionada;
  int? unidadMedidaSeleccionada;
  int? categoriaSeleccionada;

  late List<dynamic> listaPresentaciones;
  late List<dynamic> listaUnidadesMedida;

  final stepTitles = ['Básico', 'Presentación', 'Detalles'];
  final stepIcons = [
    Icons.info_outline,
    Icons.inventory_2_outlined,
    Icons.check_circle_outline,
  ];

  @override
  void initState() {
    super.initState();
    listaPresentaciones = List.from(widget.listaPresentaciones);
    listaUnidadesMedida = List.from(widget.listaUnidadesMedida);

    // Inicializar con datos existentes si se proporcionan
    final datos = widget.datosIniciales;
    if (datos != null) {
      if (datos.nombre != null) {
        nombreController.text = datos.nombre!;
      }
      if (datos.cantidad != null) {
        cantidadController.text = datos.cantidad.toString();
      }
      if (datos.stock != null) {
        stock = datos.stock!;
        stockController.text = datos.stock.toString();
      }
      if (datos.precioCompra != null) {
        precioCompraController.text = datos.precioCompra.toString();
      }
      if (datos.precioVenta != null) {
        precioVentaController.text = datos.precioVenta.toString();
      }
      if (datos.idPresentacion != null) {
        presentacionSeleccionada = datos.idPresentacion;
      }
      if (datos.idUnidadMedida != null) {
        unidadMedidaSeleccionada = datos.idUnidadMedida;
      }
      if (datos.idCategoria != null) {
        categoriaSeleccionada = datos.idCategoria;
      }
    }
  }

  @override
  void dispose() {
    nombreController.dispose();
    cantidadController.dispose();
    stockController.dispose();
    fechaAgregadoController.dispose();
    precioCompraController.dispose();
    precioVentaController.dispose();
    pageController.dispose();
    super.dispose();
  }

  String generarCodigo() {
    if (nombreController.text.isEmpty ||
        presentacionSeleccionada == null ||
        unidadMedidaSeleccionada == null) {
      return '';
    }
    final unidad = listaUnidadesMedida.firstWhere(
      (u) => u['id'] == unidadMedidaSeleccionada,
      orElse: () => {'abreviatura': ''},
    );
    final presentacion = listaPresentaciones.firstWhere(
      (p) => p['id_presentacion'] == presentacionSeleccionada,
      orElse: () => {'descripcion': ''},
    );
    final abreviatura = (unidad['abreviatura'] ?? '').toString().replaceAll(
      ' ',
      '',
    );

    // Si la presentación tiene múltiples palabras, usar solo la última
    final descripcionOriginal = (presentacion['descripcion'] ?? '')
        .toString()
        .trim();
    final palabras = descripcionOriginal.split(' ');
    final descripcionPres = palabras.length > 1
        ? palabras.last
        : descripcionOriginal.replaceAll(' ', '');

    final esAGranel = descripcionPres.toLowerCase() == 'agranel';
    final nombre = nombreController.text.trim().replaceAll(' ', '');

    if (esAGranel) {
      // Para productos a granel: nombre + unidad de medida (sin cantidad)
      return '$nombre$abreviatura$descripcionPres'.toUpperCase();
    } else {
      // Para otros productos: nombre + cantidad + unidad + presentación
      if (cantidadController.text.isEmpty) return '';
      final cantidadNum = double.tryParse(cantidadController.text.trim());
      String cantidadFormateada = cantidadController.text.trim().replaceAll(
        ' ',
        '',
      );
      if (cantidadNum != null) {
        cantidadFormateada = cantidadNum == cantidadNum.toInt()
            ? cantidadNum.toInt().toString()
            : cantidadNum.toString();
      }
      return '$nombre$cantidadFormateada$abreviatura$descripcionPres'
          .toUpperCase();
    }
  }

  bool _esAGranel() {
    if (presentacionSeleccionada == null) return false;
    final presentacion = listaPresentaciones.firstWhere(
      (p) => p['id_presentacion'] == presentacionSeleccionada,
      orElse: () => {'descripcion': ''},
    );
    final descripcion = (presentacion['descripcion'] ?? '')
        .toString()
        .toLowerCase();
    return descripcion == 'agranel' || descripcion == 'a granel';
  }

  String _getUnidadAbreviatura() {
    if (unidadMedidaSeleccionada == null) return '';
    final unidad = listaUnidadesMedida.firstWhere(
      (u) => u['id'] == unidadMedidaSeleccionada,
      orElse: () => {'abreviatura': ''},
    );
    return (unidad['abreviatura'] ?? '').toString();
  }

  bool validarPaso(int paso) {
    switch (paso) {
      case 0:
        return nombreController.text.trim().isNotEmpty;
      case 1:
        return presentacionSeleccionada != null &&
            cantidadController.text.trim().isNotEmpty &&
            unidadMedidaSeleccionada != null;
      case 2:
        return precioCompraController.text.trim().isNotEmpty &&
            precioVentaController.text.trim().isNotEmpty;
      default:
        return true;
    }
  }

  void irAPaso(int paso) {
    // Solo permitir ir a pasos anteriores o al siguiente si el actual es válido
    if (paso < currentStep) {
      // Ir hacia atrás siempre permitido
      pageController.animateToPage(
        paso,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => currentStep = paso);
    } else if (paso == currentStep + 1 && validarPaso(currentStep)) {
      // Ir al siguiente solo si el actual es válido
      pageController.animateToPage(
        paso,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => currentStep = paso);
    } else if (paso > currentStep && !validarPaso(currentStep)) {
      // Mostrar mensaje si intenta avanzar sin completar
      _mostrarErrorValidacion();
    }
  }

  void _mostrarErrorValidacion() {
    String mensaje;
    switch (currentStep) {
      case 0:
        mensaje = 'Ingresa el nombre del producto';
        break;
      case 1:
        mensaje = 'Completa la presentación, cantidad y unidad';
        break;
      case 2:
        mensaje = 'Los precios de compra y venta son obligatorios';
        break;
      default:
        mensaje = 'Completa los campos requeridos';
    }
    Fluttertoast.showToast(
      msg: mensaje,
      backgroundColor: Colors.orange,
      toastLength: Toast.LENGTH_SHORT,
    );
  }

  Future<void> _agregarNuevaPresentacion() async {
    final descripcionController = TextEditingController();
    final resultado = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_box_outlined),
            SizedBox(width: 8),
            Text('Nueva Presentación'),
          ],
        ),
        content: TextField(
          controller: descripcionController,
          decoration: const InputDecoration(
            labelText: 'Descripción *',
            border: OutlineInputBorder(),
            hintText: 'Ej: Bolsa, Caja, Botella',
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
              final descripcion = descripcionController.text.trim();
              if (descripcion.isEmpty) {
                Fluttertoast.showToast(
                  msg: 'Descripción requerida',
                  backgroundColor: Colors.orange,
                );
                return;
              }
              Navigator.pop(context, descripcion);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (resultado != null && mounted) {
      try {
        final response = await Supabase.instance.client
            .from('presentacion')
            .insert({'descripcion': resultado})
            .select()
            .single();

        final nuevas = await Supabase.instance.client
            .from('presentacion')
            .select('id_presentacion,descripcion')
            .order('descripcion', ascending: true);

        setState(() {
          listaPresentaciones = nuevas as List;
          presentacionSeleccionada = response['id_presentacion'] as int;
        });

        if (mounted) {
          Fluttertoast.showToast(
            msg: 'Presentación agregada',
            backgroundColor: Colors.green,
          );
        }
      } catch (e) {
        if (mounted) {
          Fluttertoast.showToast(
            msg: 'Error al guardar',
            backgroundColor: Colors.red,
          );
        }
      }
    }
  }

  Future<void> _agregarNuevaUnidadMedida() async {
    final nombreCtrl = TextEditingController();
    final abreviaturaCtrl = TextEditingController();
    final resultado = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.straighten_outlined),
            SizedBox(width: 8),
            Text('Nueva Unidad'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre *',
                border: OutlineInputBorder(),
                hintText: 'Ej: Gramos, Kilogramos',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: abreviaturaCtrl,
              decoration: const InputDecoration(
                labelText: 'Abreviatura *',
                border: OutlineInputBorder(),
                hintText: 'Ej: g, kg, ml',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final nombre = nombreCtrl.text.trim();
              final abreviatura = abreviaturaCtrl.text.trim();
              if (nombre.isEmpty || abreviatura.isEmpty) {
                Fluttertoast.showToast(
                  msg: 'Campos requeridos',
                  backgroundColor: Colors.orange,
                );
                return;
              }
              Navigator.pop(context, {
                'nombre': nombre,
                'abreviatura': abreviatura,
              });
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (resultado != null && mounted) {
      try {
        final response = await Supabase.instance.client
            .from('unidad_medida')
            .insert({
              'nombre': resultado['nombre'],
              'abreviatura': resultado['abreviatura'],
            })
            .select()
            .single();

        final nuevas = await Supabase.instance.client
            .from('unidad_medida')
            .select('id,nombre,abreviatura')
            .order('nombre', ascending: true);

        setState(() {
          listaUnidadesMedida = nuevas as List;
          unidadMedidaSeleccionada = response['id'] as int;
        });

        if (mounted) {
          Fluttertoast.showToast(
            msg: 'Unidad agregada',
            backgroundColor: Colors.green,
          );
        }
      } catch (e) {
        if (mounted) {
          Fluttertoast.showToast(
            msg: 'Error al guardar',
            backgroundColor: Colors.red,
          );
        }
      }
    }
  }

  Future<void> _guardarProducto() async {
    final nombre = nombreController.text.trim();
    final cantidad = cantidadController.text.trim();
    final esGranel = _esAGranel();

    try {
      final codigo = generarCodigo();
      final Map<String, dynamic> datosBase = {
        'nombre_producto': nombre,
        'codigo': codigo,
        'id_presentacion': presentacionSeleccionada,
        'id_unidad_medida': unidadMedidaSeleccionada,
        'cantidad': double.tryParse(cantidad),
      };

      if (precioCompraController.text.isNotEmpty) {
        datosBase['precio_compra'] = double.tryParse(
          precioCompraController.text,
        );
      }
      if (precioVentaController.text.isNotEmpty) {
        datosBase['precio_venta'] = double.tryParse(precioVentaController.text);
      }
      if (usarFechaPersonalizada && fechaAgregadoController.text.isNotEmpty) {
        datosBase['fecha_agregado'] = fechaAgregadoController.text;
      }
      if (categoriaSeleccionada != null) {
        datosBase['id_categoria'] = categoriaSeleccionada;
      }

      // Para productos a granel: solo 1 registro, la cantidad ES el stock
      // Para otros productos: crear N registros según stock seleccionado
      final cantidadRegistros = esGranel ? 1 : stock;

      for (int i = 0; i < cantidadRegistros; i++) {
        await Supabase.instance.client.from('producto').insert(datosBase);
      }

      if (mounted) {
        // Llamar callback con datos del producto creado
        if (widget.onProductoCreado != null) {
          final productoCreado = ProductoCreado(
            nombre: nombre,
            codigo: codigo,
            idPresentacion: presentacionSeleccionada!,
            idUnidadMedida: unidadMedidaSeleccionada,
            cantidad: double.tryParse(cantidad) ?? 0,
            precioCompra: double.tryParse(precioCompraController.text) ?? 0,
            precioVenta: double.tryParse(precioVentaController.text) ?? 0,
            stock: esGranel ? 1 : stock,
            idCategoria: categoriaSeleccionada,
          );
          widget.onProductoCreado!(productoCreado);
        }

        Navigator.pop(context);
        final mensaje = esGranel
            ? 'Producto a granel agregado ($cantidad ${_getUnidadAbreviatura()})'
            : '$stock producto(s) agregado(s)';
        Fluttertoast.showToast(msg: mensaje, backgroundColor: Colors.green);
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Error al agregar',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar producto'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Column(
            children: [
              // Barra de progreso
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (currentStep + 1) / totalSteps,
                    minHeight: 6,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      currentStep == totalSteps - 1
                          ? Colors.green
                          : colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Step indicators
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: List.generate(totalSteps, (index) {
                    final isActive = index == currentStep;
                    final isCompleted = index < currentStep;
                    final canNavigate =
                        index <= currentStep ||
                        (index == currentStep + 1 && validarPaso(currentStep));

                    return Expanded(
                      child: GestureDetector(
                        onTap: canNavigate ? () => irAPaso(index) : null,
                        child: Opacity(
                          opacity: canNavigate ? 1.0 : 0.5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: isActive
                                      ? colorScheme.primary
                                      : isCompleted
                                      ? Colors.green
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isCompleted
                                      ? Icons.check_circle
                                      : stepIcons[index],
                                  size: 18,
                                  color: isActive
                                      ? colorScheme.primary
                                      : isCompleted
                                      ? Colors.green
                                      : colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  stepTitles[index],
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isActive
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: isActive
                                        ? colorScheme.primary
                                        : isCompleted
                                        ? Colors.green
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
      body: PageView(
        controller: pageController,
        physics: const NeverScrollableScrollPhysics(), // Deshabilitar swipe
        onPageChanged: (index) => setState(() => currentStep = index),
        children: [
          _buildStep1(colorScheme),
          _buildStep2(colorScheme),
          _buildStep3(colorScheme),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              children: [
                if (currentStep > 0)
                  TextButton.icon(
                    onPressed: () => irAPaso(currentStep - 1),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Anterior'),
                  )
                else
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                const Spacer(),
                if (currentStep < totalSteps - 1)
                  FilledButton.icon(
                    onPressed: validarPaso(currentStep)
                        ? () => irAPaso(currentStep + 1)
                        : null,
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('Siguiente'),
                  )
                else
                  FilledButton.icon(
                    onPressed: validarPaso(currentStep)
                        ? _guardarProducto
                        : null,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Agregar'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'El código del producto se generará automáticamente',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          Text(
            'Nombre del producto *',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: nombreController,
            decoration: InputDecoration(
              hintText: 'Ej: Arroz, Frijoles, Aceite',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.shopping_bag_outlined),
              filled: true,
            ),
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 28),

          Text(
            'Categoría (opcional)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: categoriaSeleccionada,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: 'Seleccionar categoría',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.category_outlined),
              filled: true,
            ),
            items: [
              const DropdownMenuItem<int>(
                value: null,
                child: Text('Sin categoría'),
              ),
              ...widget.listaCategorias.map<DropdownMenuItem<int>>((cat) {
                return DropdownMenuItem<int>(
                  value: cat['id'] as int?,
                  child: Text(cat['nombre']?.toString() ?? ''),
                );
              }),
            ],
            onChanged: (value) => setState(() => categoriaSeleccionada = value),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tipo de presentación *',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: presentacionSeleccionada,
                  isExpanded: true,
                  decoration: InputDecoration(
                    hintText: 'Seleccionar presentación',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                  items: listaPresentaciones.map<DropdownMenuItem<int>>((p) {
                    return DropdownMenuItem<int>(
                      value: p['id_presentacion'] as int,
                      child: Text(
                        p['descripcion']?.toString() ?? '',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) =>
                      setState(() => presentacionSeleccionada = value),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  onPressed: _agregarNuevaPresentacion,
                  icon: const Icon(Icons.add, size: 20),
                  tooltip: 'Nueva presentación',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.green.withValues(alpha: 0.15),
                    foregroundColor: Colors.green[700],
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          Text(
            'Cantidad y unidad de medida *',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 80,
                child: TextField(
                  controller: cantidadController,
                  decoration: InputDecoration(
                    hintText: '500',
                    labelText: 'Cantidad',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: unidadMedidaSeleccionada,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Unidad',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                  items: listaUnidadesMedida.map<DropdownMenuItem<int>>((u) {
                    return DropdownMenuItem<int>(
                      value: u['id'] as int,
                      child: Text(
                        '${u['nombre']} (${u['abreviatura']})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) =>
                      setState(() => unidadMedidaSeleccionada = value),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  onPressed: _agregarNuevaUnidadMedida,
                  icon: const Icon(Icons.add, size: 20),
                  tooltip: 'Nueva unidad',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue.withValues(alpha: 0.15),
                    foregroundColor: Colors.blue[700],
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          if (generarCodigo().isNotEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.qr_code, color: colorScheme.primary, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Código generado',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          generarCodigo(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStep3(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Precios
          Text(
            'Precios *',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: precioCompraController,
                  decoration: InputDecoration(
                    labelText: 'Precio compra',
                    prefixText: 'C\$ ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: precioVentaController,
                  decoration: InputDecoration(
                    labelText: 'Precio venta',
                    prefixText: 'C\$ ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Stock - Solo mostrar si NO es a granel
          if (!_esAGranel()) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2,
                        color: Colors.green[700],
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Unidades a agregar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: IconButton(
                          onPressed: stock > 1
                              ? () => setState(() {
                                  stock--;
                                  stockController.text = stock.toString();
                                })
                              : null,
                          icon: const Icon(Icons.remove, size: 24),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.green.withValues(
                              alpha: 0.2,
                            ),
                            foregroundColor: Colors.green[700],
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: stockController,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) => setState(() {
                            stock = (int.tryParse(value) ?? 1).clamp(1, 9999);
                          }),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: IconButton(
                          onPressed: stock < 9999
                              ? () => setState(() {
                                  stock++;
                                  stockController.text = stock.toString();
                                })
                              : null,
                          icon: const Icon(Icons.add, size: 24),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.green.withValues(
                              alpha: 0.2,
                            ),
                            foregroundColor: Colors.green[700],
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ] else ...[
            // Mensaje informativo para productos a granel
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Producto a granel: el stock será igual a la cantidad ingresada (${cantidadController.text} ${_getUnidadAbreviatura()})',
                      style: TextStyle(fontSize: 14, color: Colors.blue[800]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Opciones avanzadas
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text(
              'Opciones avanzadas',
              style: TextStyle(fontSize: 15),
            ),
            leading: Icon(Icons.settings, color: colorScheme.onSurfaceVariant),
            children: [
              CheckboxListTile(
                title: const Text('Fecha de agregado personalizada'),
                subtitle: const Text('Por defecto se usa la fecha actual'),
                value: usarFechaPersonalizada,
                onChanged: (value) {
                  setState(() {
                    usarFechaPersonalizada = value ?? false;
                    if (!usarFechaPersonalizada)
                      fechaAgregadoController.clear();
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),
              if (usarFechaPersonalizada) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: fechaAgregadoController,
                  decoration: InputDecoration(
                    labelText: 'Fecha de agregado',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: const Icon(Icons.calendar_today),
                    filled: true,
                  ),
                  readOnly: true,
                  onTap: () async {
                    final fecha = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (fecha != null) {
                      final hora = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (hora != null) {
                        fechaAgregadoController.text = DateTime(
                          fecha.year,
                          fecha.month,
                          fecha.day,
                          hora.hour,
                          hora.minute,
                        ).toIso8601String();
                      }
                    }
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
