import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:abari/models/producto_db.dart';

class ProductoService {
  final _client = Supabase.instance.client;

  /// Busca productos por nombre o código en la base de datos
  /// Solo retorna productos disponibles, agrupados por código con stock
  Future<List<ProductoAgrupado>> buscarProductosAgrupados(String query) async {
    if (query.isEmpty) {
      return [];
    }

    try {
      // Hacer JOIN con presentacion y unidad_medida para obtener nombres
      final response = await _client
          .from('producto')
          .select('''
            id_producto, nombre_producto, id_presentacion, id_unidad_medida, 
            fecha_vencimiento, codigo, cantidad, estado, precio_venta, precio_compra,
            presentacion:id_presentacion(descripcion),
            unidad_medida:id_unidad_medida(nombre, abreviatura)
          ''')
          .eq('estado', 'Disponible')
          .or('nombre_producto.ilike.%$query%,codigo.ilike.%$query%')
          .order('nombre_producto', ascending: true);

      final productos = response
          .map((json) => ProductoDB.fromJson(json))
          .toList();

      // Agrupar por código
      final Map<String, List<ProductoDB>> agrupados = {};
      for (var producto in productos) {
        if (!agrupados.containsKey(producto.codigo)) {
          agrupados[producto.codigo] = [];
        }
        agrupados[producto.codigo]!.add(producto);
      }

      // Convertir a lista de ProductoAgrupado
      return agrupados.entries.map((entry) {
        final lista = entry.value;
        final primero = lista.first;

        // Determinar si es producto a granel
        final esGranel =
            primero.nombrePresentacion?.toLowerCase() == 'a granel';

        // Para productos a granel: stock = campo cantidad del producto
        // Para otros productos: stock = cantidad de registros en el grupo
        final double stockCalculado;
        if (esGranel) {
          // Sumar la cantidad de todos los productos a granel con el mismo código
          stockCalculado = lista.fold(0.0, (sum, p) => sum + p.cantidad);
        } else {
          stockCalculado = lista.length.toDouble();
        }

        return ProductoAgrupado(
          codigo: entry.key,
          nombreProducto: primero.nombreProducto,
          cantidad: primero.cantidad,
          nombrePresentacion: primero.nombrePresentacion,
          abreviaturaUnidad: primero.abreviaturaUnidad,
          precioVenta: primero.precioVenta,
          precioCompra: primero.precioCompra,
          stock: stockCalculado,
          productos: lista,
          esGranel: esGranel,
        );
      }).toList();
    } catch (e) {
      print('Error al buscar productos: $e');
      return [];
    }
  }

  /// Busca productos por nombre o código (sin agrupar)
  Future<List<ProductoDB>> buscarProductos(String query) async {
    if (query.isEmpty) {
      return [];
    }

    try {
      final response = await _client
          .from('producto')
          .select(
            'id_producto, nombre_producto, id_presentacion, id_unidad_medida, fecha_vencimiento, codigo, cantidad, estado, precio_venta, precio_compra',
          )
          .eq('estado', 'Disponible')
          .or('nombre_producto.ilike.%$query%,codigo.ilike.%$query%')
          .order('nombre_producto', ascending: true)
          .limit(20);

      return response.map((json) => ProductoDB.fromJson(json)).toList();
    } catch (e) {
      print('Error al buscar productos: $e');
      return [];
    }
  }

  /// Obtiene un producto por su ID
  Future<ProductoDB?> obtenerProductoPorId(int idProducto) async {
    try {
      final response = await _client
          .from('producto')
          .select(
            'id_producto, nombre_producto, id_presentacion, id_unidad_medida, fecha_vencimiento, codigo, cantidad, estado, precio_venta, precio_compra',
          )
          .eq('id_producto', idProducto)
          .single();

      return ProductoDB.fromJson(response);
    } catch (e) {
      print('Error al obtener producto: $e');
      return null;
    }
  }

  /// Obtiene todos los productos disponibles
  Future<List<ProductoDB>> obtenerTodosLosProductos() async {
    try {
      final response = await _client
          .from('producto')
          .select(
            'id_producto, nombre_producto, id_presentacion, id_unidad_medida, fecha_vencimiento, codigo, cantidad, estado, precio_venta, precio_compra',
          )
          .eq('estado', 'Disponible')
          .order('nombre_producto', ascending: true);

      return response.map((json) => ProductoDB.fromJson(json)).toList();
    } catch (e) {
      print('Error al obtener productos: $e');
      return [];
    }
  }
}
