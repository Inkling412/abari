class ProductoDB {
  final int idProducto;
  final String nombreProducto;
  final int? idPresentacion;
  final int? idUnidadMedida;
  final String? nombrePresentacion;
  final String? nombreUnidadMedida;
  final String? abreviaturaUnidad;
  final String? fechaVencimiento;
  final String codigo;
  final double cantidad;
  final String estado;
  final double? precioVenta;
  final double? precioCompra;

  ProductoDB({
    required this.idProducto,
    required this.nombreProducto,
    this.idPresentacion,
    this.idUnidadMedida,
    this.nombrePresentacion,
    this.nombreUnidadMedida,
    this.abreviaturaUnidad,
    this.fechaVencimiento,
    required this.codigo,
    required this.cantidad,
    required this.estado,
    this.precioVenta,
    this.precioCompra,
  });

  factory ProductoDB.fromJson(Map<String, dynamic> json) {
    // Extraer nombres de presentación y unidad de medida si vienen anidados
    String? nombrePres;
    String? nombreUnidad;
    String? abrevUnidad;

    if (json['presentacion'] is Map) {
      nombrePres = json['presentacion']['descripcion'] as String?;
    }
    if (json['unidad_medida'] is Map) {
      nombreUnidad = json['unidad_medida']['nombre'] as String?;
      abrevUnidad = json['unidad_medida']['abreviatura'] as String?;
    }

    return ProductoDB(
      idProducto: json['id_producto'] as int,
      nombreProducto: json['nombre_producto'] as String? ?? '',
      idPresentacion: json['id_presentacion'] as int?,
      idUnidadMedida: json['id_unidad_medida'] as int?,
      nombrePresentacion: nombrePres,
      nombreUnidadMedida: nombreUnidad,
      abreviaturaUnidad: abrevUnidad,
      fechaVencimiento: json['fecha_vencimiento'] as String?,
      codigo: json['codigo'] as String? ?? '',
      cantidad: (json['cantidad'] as num?)?.toDouble() ?? 0,
      estado: json['estado'] as String? ?? 'Disponible',
      precioVenta: (json['precio_venta'] as num?)?.toDouble(),
      precioCompra: (json['precio_compra'] as num?)?.toDouble(),
    );
  }

  /// Obtiene la presentación formateada (ej: "2 Lb - Bolsa")
  String get presentacionFormateada {
    final partes = <String>[];
    if (cantidad > 0) {
      final cantidadStr = cantidad == cantidad.toInt()
          ? cantidad.toInt().toString()
          : cantidad.toString();
      partes.add(cantidadStr);
    }
    if (abreviaturaUnidad != null && abreviaturaUnidad!.isNotEmpty) {
      partes.add(abreviaturaUnidad!);
    }
    if (nombrePresentacion != null && nombrePresentacion!.isNotEmpty) {
      if (partes.isNotEmpty) {
        return '${partes.join(' ')} - $nombrePresentacion';
      }
      return nombrePresentacion!;
    }
    return partes.join(' ');
  }

  Map<String, dynamic> toJson() {
    return {
      'id_producto': idProducto,
      'nombre_producto': nombreProducto,
      'id_presentacion': idPresentacion,
      'id_unidad_medida': idUnidadMedida,
      'fecha_vencimiento': fechaVencimiento,
      'codigo': codigo,
      'cantidad': cantidad,
      'estado': estado,
      'precio_venta': precioVenta,
      'precio_compra': precioCompra,
    };
  }

  /// Verifica si el producto está disponible (no Vendido ni Removido)
  bool get estaDisponible => estado != 'Vendido' && estado != 'Removido';
}

/// Representa un grupo de productos con el mismo código
class ProductoAgrupado {
  final String codigo;
  final String nombreProducto;
  final double cantidad;
  final String? nombrePresentacion;
  final String? abreviaturaUnidad;
  final double? precioVenta;
  final double? precioCompra;
  final double stock; // Cantidad disponible (unidades o cantidad a granel)
  final List<ProductoDB> productos; // Lista de productos individuales
  final bool esGranel; // Si es producto a granel

  ProductoAgrupado({
    required this.codigo,
    required this.nombreProducto,
    required this.cantidad,
    this.nombrePresentacion,
    this.abreviaturaUnidad,
    this.precioVenta,
    this.precioCompra,
    required this.stock,
    required this.productos,
    this.esGranel = false,
  });

  /// Obtiene el stock como entero (para productos no a granel)
  int get stockEntero => stock.toInt();

  /// Obtiene el texto de la unidad de stock
  String get unidadStock =>
      esGranel ? (abreviaturaUnidad ?? 'unidades') : 'unidades';

  /// Obtiene el primer producto disponible del grupo
  ProductoDB? get primerProducto =>
      productos.isNotEmpty ? productos.first : null;

  /// Obtiene la presentación formateada (ej: "2 Lb - Bolsa")
  String get presentacionFormateada {
    final partes = <String>[];
    if (cantidad > 0) {
      final cantidadStr = cantidad == cantidad.toInt()
          ? cantidad.toInt().toString()
          : cantidad.toString();
      partes.add(cantidadStr);
    }
    if (abreviaturaUnidad != null && abreviaturaUnidad!.isNotEmpty) {
      partes.add(abreviaturaUnidad!);
    }
    if (nombrePresentacion != null && nombrePresentacion!.isNotEmpty) {
      if (partes.isNotEmpty) {
        return '${partes.join(' ')} - $nombrePresentacion';
      }
      return nombrePresentacion!;
    }
    return partes.join(' ');
  }
}

/// Producto agrupado desde la función RPC get_productos_agrupados
/// Usar cuando se necesiten datos ya agrupados por código desde el servidor
class ProductoGrupo {
  final String codigo;
  final String nombreProducto;
  final String estado;
  final double stock;
  final double? precioVenta;
  final double? precioCompra;
  final DateTime? fechaVencimiento;
  final DateTime? fechaAgregado;
  final int? categoriaId;
  final String? categoriaNombre;
  final int? idPresentacion;
  final String? presentacionDescripcion;
  final int? idUnidadMedida;
  final String? unidadMedidaNombre;
  final String? unidadMedidaAbreviatura;

  ProductoGrupo({
    required this.codigo,
    required this.nombreProducto,
    required this.estado,
    required this.stock,
    this.precioVenta,
    this.precioCompra,
    this.fechaVencimiento,
    this.fechaAgregado,
    this.categoriaId,
    this.categoriaNombre,
    this.idPresentacion,
    this.presentacionDescripcion,
    this.idUnidadMedida,
    this.unidadMedidaNombre,
    this.unidadMedidaAbreviatura,
  });

  factory ProductoGrupo.fromJson(Map<String, dynamic> json) {
    return ProductoGrupo(
      codigo: json['codigo'] as String? ?? '',
      nombreProducto: json['nombre_producto'] as String? ?? '',
      estado: json['estado'] as String? ?? 'Disponible',
      stock: (json['stock'] as num?)?.toDouble() ?? 0,
      precioVenta: (json['precio_venta'] as num?)?.toDouble(),
      precioCompra: (json['precio_compra'] as num?)?.toDouble(),
      fechaVencimiento: json['fecha_vencimiento'] != null
          ? DateTime.tryParse(json['fecha_vencimiento'].toString())
          : null,
      fechaAgregado: json['fecha_agregado'] != null
          ? DateTime.tryParse(json['fecha_agregado'].toString())
          : null,
      categoriaId: json['id_categoria'] as int?,
      categoriaNombre: json['categoria_nombre'] as String?,
      idPresentacion: json['id_presentacion'] as int?,
      presentacionDescripcion: json['presentacion_descripcion'] as String?,
      idUnidadMedida: json['id_unidad_medida'] as int?,
      unidadMedidaNombre: json['unidad_medida_nombre'] as String?,
      unidadMedidaAbreviatura: json['unidad_medida_abreviatura'] as String?,
    );
  }

  /// Días restantes hasta vencimiento
  int get diasParaVencer {
    if (fechaVencimiento == null) return 999;
    return fechaVencimiento!.difference(DateTime.now()).inDays;
  }

  /// Stock formateado con unidad si es a granel
  String get stockTexto {
    final redondeado = (stock * 2).round() / 2;
    final stockStr = redondeado == redondeado.toInt()
        ? redondeado.toInt().toString()
        : redondeado.toStringAsFixed(1);
    if (esGranel && unidadMedidaAbreviatura != null) {
      return '$stockStr ${unidadMedidaAbreviatura!}';
    }
    return stockStr;
  }

  /// Categoría para mostrar
  String get categoria => categoriaNombre ?? 'Sin categoría';

  /// Si es producto a granel
  bool get esGranel =>
      presentacionDescripcion?.toLowerCase() == 'a granel';

  /// Descripción de presentación formateada
  String get presentacionFormateada {
    if (presentacionDescripcion == null) return '';
    final partes = <String>[];
    partes.add(presentacionDescripcion!);
    if (stock > 0 && unidadMedidaAbreviatura != null && !esGranel) {
      partes.add('${stock.toStringAsFixed(0)} ${unidadMedidaAbreviatura!}');
    }
    return partes.join(' - ');
  }
}
