import 'package:flutter/foundation.dart';
import 'package:abari/models/producto_db.dart';
import 'package:abari/models/payment_method.dart';
import 'package:abari/models/cliente.dart';
import 'package:abari/screens/factura/widgets/invoice_table.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FacturaProvider extends ChangeNotifier {
  DateTime _fecha = DateTime.now();
  String _metodoPago = '';
  int? _metodoPagoId;
  String _cliente = '';
  int? _clienteId;
  String _empleado = '';
  int? _empleadoId;
  int _formKey = 0; // Key para forzar reconstrucción de widgets

  final List<ProductoFactura> _productos = [];
  List<PaymentMethod> _metodosPago = [];
  bool _isLoadingMetodosPago = false;
  bool _metodosPagoCargados = false;

  List<Cliente> _clientes = [];
  bool _isLoadingClientes = false;
  bool _clientesCargados = false;

  DateTime get fecha => _fecha;
  String get metodoPago => _metodoPago;
  int? get metodoPagoId => _metodoPagoId;
  String get cliente => _cliente;
  int? get clienteId => _clienteId;
  String get empleado => _empleado;
  int? get empleadoId => _empleadoId;
  List<ProductoFactura> get productos => List.unmodifiable(_productos);
  List<PaymentMethod> get metodosPago => List.unmodifiable(_metodosPago);
  bool get isLoadingMetodosPago => _isLoadingMetodosPago;
  bool get metodosPagoCargados => _metodosPagoCargados;
  List<Cliente> get clientes => List.unmodifiable(_clientes);
  bool get isLoadingClientes => _isLoadingClientes;
  bool get clientesCargados => _clientesCargados;
  int get formKey => _formKey;

  /// Obtiene un mapa de código -> cantidad en carrito
  Map<String, int> get cantidadesPorCodigo {
    final Map<String, int> cantidades = {};
    for (var producto in _productos) {
      // Para productos a granel, convertir a int (se usa solo para mostrar en UI)
      cantidades[producto.presentacion] =
          (cantidades[producto.presentacion] ?? 0) + producto.cantidad.toInt();
    }
    return cantidades;
  }

  double get total {
    return _productos.fold(
      0.0,
      (sum, item) => sum + (item.precio * item.cantidad),
    );
  }

  void setFecha(DateTime fecha) {
    _fecha = fecha;
    notifyListeners();
  }

  void setMetodoPago(String metodoPago) {
    _metodoPago = metodoPago;
    // Buscar el ID del método de pago
    if (_metodosPago.isNotEmpty) {
      final metodo = _metodosPago.firstWhere(
        (m) => m.name == metodoPago,
        orElse: () => _metodosPago.first,
      );
      _metodoPagoId = metodo.id;
    }
    notifyListeners();
  }

  void setCliente(String cliente, {int? clienteId}) {
    _cliente = cliente;
    if (clienteId != null) {
      _clienteId = clienteId;
    } else if (_clientes.isNotEmpty) {
      // Buscar el ID del cliente si existe
      try {
        final clienteObj = _clientes.firstWhere(
          (c) => c.nombreCliente == cliente,
        );
        _clienteId = clienteObj.idCliente;
      } catch (_) {
        // Cliente no encontrado, será creado al guardar
        _clienteId = null;
      }
    }
    notifyListeners();
  }

  // Datos del cliente nuevo (si aplica)
  String? _telefonoClienteNuevo;
  String? get telefonoClienteNuevo => _telefonoClienteNuevo;

  void setDatosClienteNuevo({String? telefono}) {
    _telefonoClienteNuevo = telefono;
    notifyListeners();
  }

  void setEmpleado(String empleado, {int? empleadoId}) {
    _empleado = empleado;
    _empleadoId = empleadoId;
    notifyListeners();
  }

  // Métodos para productos
  void agregarProducto(
    ProductoDB producto, {
    double cantidad = 1,
    double stockMaximo = 0,
    bool esGranel = false,
  }) {
    // Buscar si ya existe un producto con el mismo código
    final indexExistente = _productos.indexWhere(
      (p) => p.presentacion == producto.codigo,
    );

    if (indexExistente != -1) {
      // Si existe, actualizar la cantidad
      final existente = _productos[indexExistente];
      _productos[indexExistente] = ProductoFactura(
        idProducto: existente.idProducto,
        cantidad: existente.cantidad + cantidad,
        nombre: existente.nombre,
        presentacion: existente.presentacion,
        medida: existente.medida,
        fechaVencimiento: existente.fechaVencimiento,
        precio: existente.precio,
        precioCompra: existente.precioCompra,
        stockMaximo: existente.stockMaximo,
        esGranel: existente.esGranel,
        unidadMedida: existente.unidadMedida,
      );
    } else {
      // Si no existe, agregar nuevo
      _productos.add(
        ProductoFactura(
          idProducto: producto.idProducto,
          cantidad: cantidad,
          nombre: producto.nombreProducto,
          presentacion: producto.codigo,
          medida: producto.cantidad.toString(),
          fechaVencimiento: producto.fechaVencimiento ?? '',
          precio: producto.precioVenta ?? 0.0,
          precioCompra: producto.precioCompra ?? 0.0,
          stockMaximo: stockMaximo,
          esGranel: esGranel,
          unidadMedida: producto.abreviaturaUnidad,
        ),
      );
    }
    notifyListeners();
  }

  void eliminarProducto(int index) {
    if (index >= 0 && index < _productos.length) {
      _productos.removeAt(index);
      notifyListeners();
    }
  }

  /// Actualiza la cantidad de un producto por su código
  void actualizarCantidadPorCodigo(String codigo, double nuevaCantidad) {
    final index = _productos.indexWhere((p) => p.presentacion == codigo);
    if (index != -1) {
      if (nuevaCantidad <= 0) {
        _productos.removeAt(index);
      } else {
        final producto = _productos[index];
        _productos[index] = ProductoFactura(
          idProducto: producto.idProducto,
          cantidad: nuevaCantidad,
          nombre: producto.nombre,
          presentacion: producto.presentacion,
          medida: producto.medida,
          fechaVencimiento: producto.fechaVencimiento,
          precio: producto.precio,
          precioCompra: producto.precioCompra,
          stockMaximo: producto.stockMaximo,
          esGranel: producto.esGranel,
          unidadMedida: producto.unidadMedida,
        );
      }
      notifyListeners();
    }
  }

  void actualizarCantidad(int index, double cantidad) {
    if (index >= 0 && index < _productos.length && cantidad > 0) {
      final producto = _productos[index];
      _productos[index] = ProductoFactura(
        idProducto: producto.idProducto,
        cantidad: cantidad,
        nombre: producto.nombre,
        presentacion: producto.presentacion,
        medida: producto.medida,
        fechaVencimiento: producto.fechaVencimiento,
        precio: producto.precio,
        precioCompra: producto.precioCompra,
        stockMaximo: producto.stockMaximo,
        esGranel: producto.esGranel,
        unidadMedida: producto.unidadMedida,
      );
      notifyListeners();
    }
  }

  void limpiarFactura() {
    _fecha = DateTime.now();
    //_metodoPago = '';
    //_metodoPagoId = null;
    _cliente = '';
    _clienteId = null;
    _telefonoClienteNuevo = null;
    // _empleado = '';
    // _empleadoId = null;
    _productos.clear();
    _formKey++; // Incrementar key para forzar reconstrucción
    notifyListeners();
  }

  // Cargar métodos de pago desde la base de datos
  Future<void> cargarMetodosPago() async {
    print('============================================');
    print('cargarMetodosPago INICIADO');
    print('_isLoadingMetodosPago: $_isLoadingMetodosPago');
    print('_metodosPagoCargados: $_metodosPagoCargados');
    print('============================================');

    if (_isLoadingMetodosPago || _metodosPagoCargados) {
      print('⚠️ SALIENDO - Ya está cargando o ya fue cargado');
      return;
    }

    print('✅ Iniciando carga...');
    _isLoadingMetodosPago = true;
    notifyListeners();

    try {
      print('📡 Consultando Supabase tabla: payment_method');

      final response = await Supabase.instance.client
          .from('payment_method')
          .select('id, name, provider, created_at')
          .order('name');

      print('📦 Respuesta recibida: $response');
      print('📦 Tipo de respuesta: ${response.runtimeType}');

      _metodosPago = (response as List)
          .map((json) => PaymentMethod.fromJson(json))
          .toList();

      print('✅ ${_metodosPago.length} métodos cargados exitosamente');
      for (var metodo in _metodosPago) {
        print('   • ${metodo.name} (provider: ${metodo.provider})');
      }

      // Sincronizar el método de pago ANTES de marcar como cargado
      // Solo si hay un método seleccionado que ya no existe
      if (_metodosPago.isNotEmpty && _metodoPago.isNotEmpty) {
        if (!_metodosPago.any((m) => m.name == _metodoPago)) {
          final viejoMetodo = _metodoPago;
          _metodoPago = _metodosPago.first.name;
          print('🔄 Método actualizado de "$viejoMetodo" a "$_metodoPago"');
        }
      }

      _metodosPagoCargados = true;
      print('✅ Marcado como cargado');
    } catch (e, stackTrace) {
      print('❌ ERROR cargando métodos de pago:');
      print('   Error: $e');
      print('   Stack: $stackTrace');
      _metodosPago = [];
    } finally {
      _isLoadingMetodosPago = false;
      print('🏁 Finalizando carga, notificando listeners...');
      notifyListeners();
      print('============================================');
    }
  }

  // Cargar clientes desde la base de datos
  Future<void> cargarClientes({bool forzar = false}) async {
    print('============================================');
    print('cargarClientes INICIADO');
    print('_isLoadingClientes: $_isLoadingClientes');
    print('_clientesCargados: $_clientesCargados');
    print('============================================');

    if (_isLoadingClientes || (_clientesCargados && !forzar)) {
      print('⚠️ SALIENDO - Ya está cargando o ya fue cargado');
      return;
    }

    print('✅ Iniciando carga...');
    _isLoadingClientes = true;
    notifyListeners();

    try {
      print('📡 Consultando Supabase tabla: cliente');

      final response = await Supabase.instance.client
          .from('cliente')
          .select('id_cliente, nombre_cliente, numero_telefono')
          .order('nombre_cliente');

      print('📦 Respuesta recibida: $response');
      print('📦 Tipo de respuesta: ${response.runtimeType}');

      _clientes = (response as List)
          .map((json) => Cliente.fromJson(json))
          .toList();

      print('✅ ${_clientes.length} clientes cargados exitosamente');
      for (var cliente in _clientes) {
        print(
          '   • ${cliente.nombreCliente} (tel: ${cliente.numeroTelefono ?? "N/A"})',
        );
      }

      _clientesCargados = true;
      print('✅ Marcado como cargado');
    } catch (e, stackTrace) {
      print('❌ ERROR cargando clientes:');
      print('   Error: $e');
      print('   Stack: $stackTrace');
      _clientes = [];
    } finally {
      _isLoadingClientes = false;
      print('🏁 Finalizando carga, notificando listeners...');
      notifyListeners();
      print('============================================');
    }
  }

  // Validar que todos los campos requeridos estén completos
  String? validarFactura() {
    if (_cliente.isEmpty) {
      return 'Debe seleccionar un cliente';
    }
    if (_empleado.isEmpty) {
      return 'Debe seleccionar un empleado';
    }
    if (_metodoPago.isEmpty) {
      return 'Debe seleccionar un método de pago';
    }
    if (_productos.isEmpty) {
      return 'Debe agregar al menos un producto';
    }
    // La fecha siempre tendrá un valor (DateTime.now() por defecto)
    return null; // Todo válido
  }

  // Guardar venta en la base de datos
  Future<String?> guardarVenta({String? telefonoClienteNuevo}) async {
    print('============================================');
    print('GUARDANDO VENTA');
    print('============================================');

    try {
      // 1. Si el cliente no existe, crearlo primero
      int? clienteIdFinal = _clienteId;

      if (clienteIdFinal == null && _cliente.isNotEmpty) {
        print('👤 Creando nuevo cliente: $_cliente');
        final nuevoCliente = await Supabase.instance.client
            .from('cliente')
            .insert({
              'nombre_cliente': _cliente,
              'numero_telefono': telefonoClienteNuevo ?? _telefonoClienteNuevo,
            })
            .select('id_cliente')
            .single();

        clienteIdFinal = nuevoCliente['id_cliente'] as int;
        _clienteId = clienteIdFinal;
        print('✅ Cliente creado con ID: $clienteIdFinal');
      }

      // 2. Verificar que tenemos todos los IDs necesarios
      if (clienteIdFinal == null) {
        return 'Error: ID de cliente no encontrado';
      }
      if (_empleadoId == null) {
        return 'Error: ID de empleado no encontrado';
      }
      if (_metodoPagoId == null) {
        return 'Error: ID de método de pago no encontrado';
      }

      // 2. Verificar stock disponible para cada tipo de producto
      print('📦 Verificando stock disponible...');
      for (var producto in _productos) {
        if (producto.esGranel) {
          // Para productos a granel: verificar campo cantidad
          final stockResponse = await Supabase.instance.client
              .from('producto')
              .select('cantidad')
              .eq('codigo', producto.presentacion)
              .eq('estado', 'Disponible');

          final stockTotal = (stockResponse as List).fold<double>(
            0.0,
            (sum, p) => sum + ((p['cantidad'] as num?)?.toDouble() ?? 0.0),
          );

          print(
            '   • ${producto.presentacion} (granel): ${producto.cantidad} ${producto.unidadMedida} requeridos, $stockTotal disponibles',
          );

          if (stockTotal < producto.cantidad) {
            return 'Stock insuficiente para ${producto.presentacion}. Disponibles: ${stockTotal.toStringAsFixed(1)} ${producto.unidadMedida}, Requeridos: ${producto.cantidad.toStringAsFixed(1)} ${producto.unidadMedida}';
          }
        } else {
          // Para productos regulares: contar registros
          final stockDisponible = await Supabase.instance.client
              .from('producto')
              .select('id_producto')
              .eq('codigo', producto.presentacion)
              .eq('estado', 'Disponible')
              .count(CountOption.exact);

          final count = stockDisponible.count;
          print(
            '   • ${producto.presentacion}: ${producto.cantidad.toInt()} requeridos, $count disponibles',
          );

          if (count < producto.cantidad.toInt()) {
            return 'Stock insuficiente para ${producto.presentacion}. Disponibles: $count, Requeridos: ${producto.cantidad.toInt()}';
          }
        }
      }

      print('✅ Stock verificado correctamente');

      // 3. Insertar en tabla venta
      print('💾 Insertando venta...');
      final datosVenta = {
        'fecha': _fecha.toIso8601String().split('T')[0],
        'total': total,
        'id_cliente': clienteIdFinal,
        'id_empleado': _empleadoId,
        'payment_method_id': _metodoPagoId,
      };
      print('📋 Datos a insertar: $datosVenta');

      final ventaResponse = await Supabase.instance.client
          .from('venta')
          .insert(datosVenta)
          .select('id_venta, fecha, total, id_cliente, id_empleado')
          .single();

      print('📋 Respuesta de inserción: $ventaResponse');

      final idVenta = ventaResponse['id_venta'] as int;
      print('✅ Venta creada con ID: $idVenta');

      // Esperar un momento para asegurar que la BD se sincronice
      await Future.delayed(const Duration(milliseconds: 500));

      // Verificar que la venta existe
      final verificacion = await Supabase.instance.client
          .from('venta')
          .select('id_venta, fecha, total')
          .eq('id_venta', idVenta)
          .maybeSingle();
      print('🔍 Verificación de venta existente: $verificacion');

      if (verificacion == null) {
        print(
          '❌ ERROR CRÍTICO: La venta con ID $idVenta NO existe después de insertarla',
        );
        print('❌ Esto indica un problema con la base de datos o permisos');
        return 'Error: La venta no se guardó correctamente en la base de datos';
      }

      print('✅ Venta verificada correctamente en la base de datos');

      // 4. Para cada tipo de producto, procesar según si es a granel o no
      print('🔄 Procesando productos...');
      for (var producto in _productos) {
        print(
          '   📦 Procesando: ${producto.presentacion} x${producto.cantidadFormateada} ${producto.unidadTexto}',
        );

        if (producto.esGranel) {
          // PRODUCTOS A GRANEL: Reducir el campo cantidad
          var cantidadRestante = producto.cantidad;

          // Obtener productos a granel ordenados por fecha de vencimiento
          final productosGranel = await Supabase.instance.client
              .from('producto')
              .select('id_producto, cantidad')
              .eq('codigo', producto.presentacion)
              .eq('estado', 'Disponible')
              .order('fecha_vencimiento', ascending: true);

          final List<int> idsProductosAfectados = [];

          for (var p in productosGranel) {
            if (cantidadRestante <= 0) break;

            final idProducto = p['id_producto'] as int;
            final cantidadActual = (p['cantidad'] as num?)?.toDouble() ?? 0.0;

            if (cantidadActual <= cantidadRestante) {
              // Consumir todo este producto y marcarlo como vendido
              await Supabase.instance.client
                  .from('producto')
                  .update({'estado': 'Vendido', 'cantidad': 0})
                  .eq('id_producto', idProducto);

              cantidadRestante -= cantidadActual;
              idsProductosAfectados.add(idProducto);
              print(
                '      • Producto $idProducto: consumido completamente (${cantidadActual.toStringAsFixed(1)} ${producto.unidadMedida})',
              );
            } else {
              // Reducir parcialmente este producto
              final nuevaCantidad = cantidadActual - cantidadRestante;
              await Supabase.instance.client
                  .from('producto')
                  .update({'cantidad': nuevaCantidad})
                  .eq('id_producto', idProducto);

              idsProductosAfectados.add(idProducto);
              print(
                '      • Producto $idProducto: reducido de ${cantidadActual.toStringAsFixed(1)} a ${nuevaCantidad.toStringAsFixed(1)} ${producto.unidadMedida}',
              );
              cantidadRestante = 0;
            }
          }

          // Insertar en producto_en_venta (solo los productos afectados) con precios históricos
          print(
            '      📊 Precios granel: venta=${producto.precio}, compra=${producto.precioCompra}',
          );
          final productosEnVenta = idsProductosAfectados
              .map(
                (idProducto) => {
                  'id_producto': idProducto,
                  'id_venta': idVenta,
                  'precio_historico': producto.precio,
                  'costo_historico': producto.precioCompra,
                },
              )
              .toList();

          if (productosEnVenta.isNotEmpty) {
            print('      📦 Insertando granel: $productosEnVenta');
            await Supabase.instance.client
                .from('producto_en_venta')
                .insert(productosEnVenta);
          }

          print('      ✅ Producto a granel procesado con precios históricos');
        } else {
          // PRODUCTOS REGULARES: Marcar N productos como vendidos
          final productosDisponibles = await Supabase.instance.client
              .from('producto')
              .select('id_producto')
              .eq('codigo', producto.presentacion)
              .eq('estado', 'Disponible')
              .order('fecha_vencimiento', ascending: true)
              .limit(producto.cantidad.toInt());

          final idsProductos = (productosDisponibles as List)
              .map((p) => p['id_producto'] as int)
              .toList();

          print('      • IDs seleccionados: $idsProductos');

          if (idsProductos.isNotEmpty) {
            // Actualizar estado a 'Vendido'
            await Supabase.instance.client
                .from('producto')
                .update({'estado': 'Vendido'})
                .inFilter('id_producto', idsProductos);

            print(
              '      ✅ ${idsProductos.length} productos marcados como Vendidos',
            );

            // Insertar en producto_en_venta con precios históricos
            print(
              '      📊 Precios: venta=${producto.precio}, compra=${producto.precioCompra}',
            );
            final productosEnVenta = idsProductos
                .map(
                  (idProducto) => {
                    'id_producto': idProducto,
                    'id_venta': idVenta,
                    'precio_historico': producto.precio,
                    'costo_historico': producto.precioCompra,
                  },
                )
                .toList();

            print('      📦 Insertando: $productosEnVenta');
            await Supabase.instance.client
                .from('producto_en_venta')
                .insert(productosEnVenta);

            print(
              '      ✅ Relaciones creadas en producto_en_venta con precios históricos',
            );
          } else {
            print('      ⚠️ No se encontraron productos disponibles');
          }
        }
      }

      print('============================================');
      print('✅ VENTA GUARDADA EXITOSAMENTE - ID: $idVenta');
      print('============================================');

      return null; // Sin errores
    } catch (e, stackTrace) {
      print('❌ ERROR guardando venta:');
      print('   Error: $e');
      print('   Stack: $stackTrace');
      return 'Error al guardar la venta: $e';
    }
  }
}
