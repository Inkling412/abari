import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:abari/providers/theme_provider.dart';
import 'package:abari/models/producto_db.dart';

class ProductosScreen extends StatefulWidget {
  const ProductosScreen({super.key});
  @override
  State<ProductosScreen> createState() => _InventarioPageState();
}

class _InventarioPageState extends State<ProductosScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  int _selectedTabIndex = 0;
  List<ProductoGrupo> productos = [];
  List<String> categorias = []; // Lista de nombres de categorías únicas
  Map<String, int> categoriasMap = {}; // Mapa nombre -> id de categorías
  Map<int, String> presentaciones = {}; // id_presentacion -> descripcion
  Map<int, String> unidadesAbrev = {}; // id_unidad_medida -> abreviatura
  String busqueda = '';
  bool cargando = true;
  bool cargandoMas = false;
  bool hayMasProductos = true;
  bool mostrarEliminados = false;

  // Paginación por cursor
  static const int _pageSize = 50;
  String? _cursor;
  final ScrollController _scrollController = ScrollController();

  // Debounce para búsqueda
  Timer? _debounceTimer;
  String _ultimaBusqueda = '';

  // Filtros
  List<int> filtrosCategoriaIds = []; // IDs de categorías seleccionadas
  String ordenarPor = 'nombre'; // nombre, vencimiento

  // Contador de filtros activos
  int get filtrosActivos {
    int count = filtrosCategoriaIds.length;
    if (ordenarPor != 'nombre') count++;
    return count;
  }

  // Helper para obtener nombre legible del orden
  String _getNombreOrden(String orden) {
    switch (orden) {
      case 'nombre':
        return 'Nombre';
      case 'vencimiento':
        return 'Vencimiento';
      case 'stock':
        return 'Stock';
      case 'agregado_reciente':
        return 'Más reciente';
      case 'agregado_antiguo':
        return 'Más antiguo';
      default:
        return orden;
    }
  }

  // Mostrar modal de filtros
  void _mostrarFiltros(BuildContext context) {
    // Variables temporales para los filtros
    List<int> tempFiltrosCategoriaIds = List.from(filtrosCategoriaIds);
    String tempOrdenarPor = ordenarPor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header fijo
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filtros',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            tempFiltrosCategoriaIds.clear();
                            tempOrdenarPor = 'nombre';
                          });
                        },
                        child: const Text('Limpiar todo'),
                      ),
                    ],
                  ),
                ),

                // Contenido scrolleable
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Filtro por Categoría (múltiple)
                        if (categorias.isNotEmpty) ...[
                          const Text(
                            'Categoría',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: categorias.map((cat) {
                              final catId = categoriasMap[cat];
                              final isSelected =
                                  catId != null &&
                                  tempFiltrosCategoriaIds.contains(catId);
                              return FilterChip(
                                label: Text(cat),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setModalState(() {
                                    if (catId != null) {
                                      if (selected) {
                                        tempFiltrosCategoriaIds.add(catId);
                                      } else {
                                        tempFiltrosCategoriaIds.remove(catId);
                                      }
                                    }
                                  });
                                },
                                selectedColor: Theme.of(
                                  context,
                                ).colorScheme.secondaryContainer,
                                checkmarkColor: Theme.of(
                                  context,
                                ).colorScheme.secondary,
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Ordenar por
                        const Text(
                          'Ordenar por',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilterChip(
                              label: const Text('Nombre'),
                              selected: tempOrdenarPor == 'nombre',
                              onSelected: (selected) {
                                setModalState(() => tempOrdenarPor = 'nombre');
                              },
                              selectedColor: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              checkmarkColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                            ),
                            FilterChip(
                              label: const Text('Vencimiento'),
                              selected: tempOrdenarPor == 'vencimiento',
                              onSelected: (selected) {
                                setModalState(
                                  () => tempOrdenarPor = 'vencimiento',
                                );
                              },
                              selectedColor: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              checkmarkColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Botones de acción
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                child: const Text('Cerrar'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: () {
                                  final cambioFiltros =
                                      !_listEquals(
                                        filtrosCategoriaIds,
                                        tempFiltrosCategoriaIds,
                                      ) ||
                                      ordenarPor != tempOrdenarPor;
                                  setState(() {
                                    filtrosCategoriaIds =
                                        tempFiltrosCategoriaIds;
                                    ordenarPor = tempOrdenarPor;
                                  });
                                  Navigator.pop(context);
                                  if (cambioFiltros) {
                                    _resetYCargar();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                ),
                                child: const Text('Aplicar filtros'),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: MediaQuery.of(context).viewInsets.bottom,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _initTabController() {
    _tabController?.dispose();
    // +1 para la tab "Todos"
    _tabController = TabController(
      length: categorias.length + 1,
      vsync: this,
      initialIndex: _selectedTabIndex,
    );
    _tabController!.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController!.indexIsChanging) return;
    final newIndex = _tabController!.index;
    if (newIndex != _selectedTabIndex) {
      setState(() {
        _selectedTabIndex = newIndex;
        // El filtro se aplica en build() basado en _selectedTabIndex
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _cargarDatosIniciales();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _scrollController.dispose();
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !cargandoMas &&
        hayMasProductos &&
        !cargando) {
      _cargarMasProductos();
    }
  }

  void _onBusquedaChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (value != _ultimaBusqueda) {
        _ultimaBusqueda = value;
        setState(() => busqueda = value);
        _resetYCargar();
      }
    });
  }

  void _resetYCargar() {
    setState(() {
      productos = [];
      _cursor = null;
      hayMasProductos = true;
    });
    cargarDatos();
  }

  Future<void> _cargarDatosIniciales() async {
    await _cargarCategorias();
    await cargarDatos();
  }

  Future<void> _cargarCategorias() async {
    final client = Supabase.instance.client;
    try {
      // Cargar presentaciones, unidades y categorías
      final results = await Future.wait([
        client.from('presentacion').select('id_presentacion, descripcion'),
        client.from('unidad_medida').select('id, abreviatura'),
        client
            .from('categoria')
            .select('id, nombre')
            .order('nombre', ascending: true),
      ]);

      // Procesar presentaciones
      final Map<int, String> presMap = {};
      for (final item in (results[0] as List)) {
        final id = item['id_presentacion'] as int?;
        final desc = item['descripcion'] as String?;
        if (id != null) {
          presMap[id] = desc ?? '';
        }
      }

      // Procesar unidades
      final Map<int, String> unidMap = {};
      for (final item in (results[1] as List)) {
        final id = item['id'] as int?;
        final abrev = item['abreviatura'] as String?;
        if (id != null) {
          unidMap[id] = abrev ?? '';
        }
      }

      // Procesar categorías
      final List<String> catList = [];
      final Map<String, int> catMap = {};
      for (final item in (results[2] as List)) {
        final id = item['id'] as int?;
        final nombre = item['nombre'] as String?;
        if (id != null && nombre != null && nombre.isNotEmpty) {
          catList.add(nombre);
          catMap[nombre] = id;
        }
      }

      if (mounted) {
        setState(() {
          presentaciones = presMap;
          unidadesAbrev = unidMap;
          categorias = catList;
          categoriasMap = catMap;
        });
        _initTabController();
      }
    } catch (e) {
      debugPrint('Error al cargar catálogos: $e');
    }
  }

  Future<void> _cargarMasProductos() async {
    if (cargandoMas || !hayMasProductos) return;
    setState(() => cargandoMas = true);
    await cargarDatos(append: true);
    setState(() => cargandoMas = false);
  }

  Future<void> cargarDatos({bool append = false}) async {
    if (!append) {
      setState(() => cargando = true);
    }
    final client = Supabase.instance.client;

    try {
      // Usar la función RPC get_productos_agrupados
      final String? estado = mostrarEliminados ? 'Vendido' : 'Disponible';

      final data = await client.rpc(
        'get_productos_agrupados',
        params: {
          'p_limit': _pageSize,
          'p_cursor': append ? _cursor : null,
          'p_estado': estado,
          'p_categoria_ids': filtrosCategoriaIds.isNotEmpty
              ? filtrosCategoriaIds
              : null,
          'p_busqueda': busqueda.isNotEmpty ? busqueda : null,
        },
      );

      final List<ProductoGrupo> nuevosProductos = (data as List)
          .map((json) => ProductoGrupo.fromJson(json))
          .toList();

      // Actualizar cursor para siguiente página
      if (nuevosProductos.isNotEmpty) {
        _cursor = nuevosProductos.last.codigo;
      }

      // Verificar si hay más productos
      if (nuevosProductos.length < _pageSize) {
        hayMasProductos = false;
      }

      if (mounted) {
        setState(() {
          if (append) {
            productos.addAll(nuevosProductos);
          } else {
            productos = nuevosProductos;
          }
          cargando = false;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar datos: $e');
      if (mounted) {
        setState(() => cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar productos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> eliminarProducto(
    BuildContext context,
    ProductoGrupo producto,
  ) async {
    final nombre = producto.nombreProducto;
    final codigo = producto.codigo;
    final presentacion = producto.presentacionDescripcion ?? '—';
    final stockTexto = producto.stockTexto;
    final fecha = producto.fechaVencimiento;
    String estadoSeleccionado = 'Vendido';

    final resultado = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Confirmar eliminación'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '¿Está seguro que desea eliminar este producto?',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    _buildInfoRow('Nombre:', nombre),
                    _buildInfoRow('Código:', codigo),
                    _buildInfoRow('Presentación:', presentacion),
                    _buildInfoRow('Stock:', stockTexto),
                    _buildInfoRow(
                      'Vencimiento:',
                      fecha?.toIso8601String().split('T').first ?? 'Sin fecha',
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    // Selector de motivo
                    const Text(
                      'Motivo de eliminación:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RadioListTile<String>(
                      title: const Text(
                        'Vendido',
                        style: TextStyle(fontSize: 13),
                      ),
                      subtitle: const Text(
                        'El producto fue vendido',
                        style: TextStyle(fontSize: 11),
                      ),
                      value: 'Vendido',
                      groupValue: estadoSeleccionado,
                      onChanged: (value) =>
                          setDialogState(() => estadoSeleccionado = value!),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    RadioListTile<String>(
                      title: const Text(
                        'Removido',
                        style: TextStyle(fontSize: 13),
                      ),
                      subtitle: const Text(
                        'El producto fue descartado',
                        style: TextStyle(fontSize: 11),
                      ),
                      value: 'Removido',
                      groupValue: estadoSeleccionado,
                      onChanged: (value) =>
                          setDialogState(() => estadoSeleccionado = value!),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Se eliminarán todos los productos con código: $codigo',
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, {
                    'confirmar': true,
                    'estado': estadoSeleccionado,
                  }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Eliminar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (resultado != null && resultado['confirmar'] == true) {
      final estadoFinal = resultado['estado'] as String;

      try {
        // Actualizar estado de todos los productos con este código
        await Supabase.instance.client
            .from('producto')
            .update({'estado': estadoFinal})
            .eq('codigo', codigo)
            .eq('estado', 'Disponible');

        await cargarDatos();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Producto "$nombre" eliminado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> editarProducto(
    BuildContext context,
    ProductoGrupo producto,
  ) async {
    final nombreController = TextEditingController(
      text: producto.nombreProducto,
    );
    final precioVentaController = TextEditingController(
      text: producto.precioVenta?.toStringAsFixed(2) ?? '',
    );
    final precioCompraController = TextEditingController(
      text: producto.precioCompra?.toStringAsFixed(2) ?? '',
    );
    String? categoriaSeleccionada = producto.categoriaNombre;
    int? presentacionSeleccionada = producto.idPresentacion;

    final resultado = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Editar producto'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Código: ${producto.codigo}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    // Nombre
                    TextField(
                      controller: nombreController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del producto',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Precios en fila
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: precioCompraController,
                            decoration: const InputDecoration(
                              labelText: 'Precio compra',
                              prefixText: 'C\$ ',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: precioVentaController,
                            decoration: const InputDecoration(
                              labelText: 'Precio venta',
                              prefixText: 'C\$ ',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Categoría
                    DropdownButtonFormField<String>(
                      value: categoriaSeleccionada,
                      decoration: const InputDecoration(
                        labelText: 'Categoría',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: categorias
                          .map(
                            (cat) =>
                                DropdownMenuItem(value: cat, child: Text(cat)),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => categoriaSeleccionada = value),
                    ),
                    const SizedBox(height: 12),
                    // Presentación
                    DropdownButtonFormField<int>(
                      value: presentacionSeleccionada,
                      decoration: const InputDecoration(
                        labelText: 'Presentación',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: presentaciones.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setDialogState(
                        () => presentacionSeleccionada = value,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Los cambios se aplicarán a todos los productos con este código.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, {
                    'confirmar': true,
                    'nombre': nombreController.text.trim(),
                    'precioVenta': double.tryParse(precioVentaController.text),
                    'precioCompra': double.tryParse(
                      precioCompraController.text,
                    ),
                    'categoriaId': categoriaSeleccionada,
                    'presentacionId': presentacionSeleccionada,
                  }),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (resultado != null && resultado['confirmar'] == true) {
      try {
        final updates = <String, dynamic>{};

        if (resultado['nombre'] != null &&
            resultado['nombre'].toString().isNotEmpty) {
          updates['nombre_producto'] = resultado['nombre'];
        }
        if (resultado['precioVenta'] != null) {
          updates['precio_venta'] = resultado['precioVenta'];
        }
        if (resultado['precioCompra'] != null) {
          updates['precio_compra'] = resultado['precioCompra'];
        }
        if (resultado['categoria'] != null) {
          updates['categoria'] = resultado['categoria'];
        }
        if (resultado['presentacionId'] != null) {
          updates['id_presentacion'] = resultado['presentacionId'];
        }

        if (updates.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No hay cambios para guardar'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        await Supabase.instance.client
            .from('producto')
            .update(updates)
            .eq('codigo', producto.codigo);

        await cargarDatos();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Producto actualizado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al actualizar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filtrar productos según la tab seleccionada
    List<ProductoGrupo> productosFiltrados = productos;
    if (_selectedTabIndex > 0 && categorias.isNotEmpty) {
      final categoriaSeleccionada = categorias[_selectedTabIndex - 1];
      productosFiltrados = productos
          .where((p) => p.categoriaNombre == categoriaSeleccionada)
          .toList();
    }

    // Agrupar por categoría para mostrar
    final Map<String, List<ProductoGrupo>> productosPorCategoria = {};
    for (final p in productosFiltrados) {
      final cat = p.categoria;
      if (!productosPorCategoria.containsKey(cat)) {
        productosPorCategoria[cat] = [];
      }
      productosPorCategoria[cat]!.add(p);
    }

    // Ordenar categorías alfabéticamente
    final categoriasOrdenadas = productosPorCategoria.keys.toList()..sort();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            children: [
              // Barra de búsqueda y filtros
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Barra de búsqueda con botón de filtros
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: 'Buscar producto',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            onChanged: _onBusquedaChanged,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Botón de filtros con badge
                        Stack(
                          children: [
                            IconButton(
                              onPressed: () => _mostrarFiltros(context),
                              icon: const Icon(Icons.filter_list),
                              style: IconButton.styleFrom(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                padding: const EdgeInsets.all(16),
                              ),
                            ),
                            if (filtrosActivos > 0)
                              Positioned(
                                right: 4,
                                top: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 18,
                                    minHeight: 18,
                                  ),
                                  child: Text(
                                    '$filtrosActivos',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    // Chips de filtros activos
                    if (filtrosCategoriaIds.isNotEmpty ||
                        ordenarPor != 'nombre') ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...filtrosCategoriaIds.map((catId) {
                            // Buscar el nombre de la categoría por su ID
                            final catName = categoriasMap.entries
                                .firstWhere(
                                  (e) => e.value == catId,
                                  orElse: () =>
                                      MapEntry('Categoría $catId', catId),
                                )
                                .key;
                            return Chip(
                              label: Text(catName),
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.secondaryContainer,
                              onDeleted: () {
                                setState(() {
                                  filtrosCategoriaIds.remove(catId);
                                });
                                _resetYCargar();
                              },
                              deleteIcon: const Icon(Icons.close, size: 18),
                            );
                          }),
                          if (ordenarPor != 'nombre')
                            Chip(
                              label: Text(
                                'Orden: ${_getNombreOrden(ordenarPor)}',
                              ),
                              onDeleted: () {
                                setState(() => ordenarPor = 'nombre');
                                _resetYCargar();
                              },
                              deleteIcon: const Icon(Icons.close, size: 18),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // TabBar de categorías
              if (_tabController != null && categorias.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1,
                      ),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 13,
                    ),
                    tabs: [
                      const Tab(text: 'Todos'),
                      ...categorias.map((cat) => Tab(text: cat)),
                    ],
                  ),
                ),
              // Botones de acción
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    // Botón de agregar producto - navega a compras
                    ElevatedButton.icon(
                      onPressed: () {
                        context.pushNamed('compras');
                      },
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      label: const Text('Agregar producto'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Switch
                    SwitchListTile(
                      title: Text(
                        mostrarEliminados
                            ? 'Mostrar solo productos inactivos'
                            : 'Mostrar solo productos activos',
                        style: const TextStyle(fontSize: 13),
                      ),
                      value: mostrarEliminados,
                      onChanged: (value) {
                        setState(() {
                          mostrarEliminados = value;
                        });
                        _resetYCargar();
                      },
                      secondary: Icon(
                        mostrarEliminados
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 20,
                      ),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              // Lista de productos
              Expanded(
                child: cargando
                    ? const Center(child: CircularProgressIndicator())
                    : Consumer<ThemeProvider>(
                        builder: (context, themeProvider, child) {
                          final colorScheme = Theme.of(context).colorScheme;
                          final isDark = themeProvider.isDarkMode;

                          // Si hay una categoría seleccionada (no "Todos"), mostrar lista plana
                          if (_selectedTabIndex > 0) {
                            return ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.only(
                                bottom: 16,
                                top: 8,
                              ),
                              itemCount:
                                  productosFiltrados.length +
                                  (cargandoMas ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index >= productosFiltrados.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }
                                return _buildProductoCard(
                                  context,
                                  productosFiltrados[index],
                                  colorScheme,
                                  isDark,
                                );
                              },
                            );
                          }

                          // Tab "Todos" - mostrar agrupado por categoría
                          return ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount:
                                categoriasOrdenadas.length +
                                (cargandoMas ? 1 : 0),
                            itemBuilder: (context, catIndex) {
                              // Mostrar indicador de carga al final
                              if (catIndex >= categoriasOrdenadas.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              final categoria = categoriasOrdenadas[catIndex];
                              final productosCategoria =
                                  productosPorCategoria[categoria]!;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Separador de categoría
                                  Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.fromLTRB(
                                      12,
                                      8,
                                      12,
                                      4,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.secondaryContainer
                                          .withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.category,
                                          size: 18,
                                          color: colorScheme.secondary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          categoria,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.secondary,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '${productosCategoria.length} items',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colorScheme
                                                .onSecondaryContainer,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Productos de esta categoría
                                  ...productosCategoria.map(
                                    (p) => _buildProductoCard(
                                      context,
                                      p,
                                      colorScheme,
                                      isDark,
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductoCard(
    BuildContext context,
    ProductoGrupo p,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final nombre = p.nombreProducto;
    final codigo = p.codigo;
    final fecha = p.fechaVencimiento;
    final diasRestantes = p.diasParaVencer;
    final stock = p.stock;
    final estado = p.estado;
    final precioCompra = p.precioCompra;
    final precioVenta = p.precioVenta;
    final stockTexto = p.stockTexto;
    final presentacion = p.presentacionFormateada;
    final esGranel = p.esGranel;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (fecha != null && diasRestantes < 30)
              ? Colors.red.withOpacity(0.5)
              : (fecha != null && diasRestantes < 60)
              ? Colors.orange.withOpacity(0.5)
              : colorScheme.outlineVariant,
          width: (fecha != null && diasRestantes < 60) ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila 1: Nombre + Precio
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  nombre,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Badge de Stock (estilo similar a Precio)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: stock > 5
                      ? Colors.blue[600]
                      : stock > 0
                      ? Colors.orange[600]
                      : Colors.red[600],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  children: [
                    Text(
                      'Stock',
                      style: TextStyle(fontSize: 9, color: Colors.white70),
                    ),
                    Text(
                      stockTexto,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Badge de Precio
              if (precioVenta != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[600],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Precio',
                        style: TextStyle(fontSize: 9, color: Colors.green[100]),
                      ),
                      Text(
                        'C\$${precioVenta.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Fila 2: Presentación (si existe)
          if (presentacion.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  esGranel ? Icons.scale : Icons.inventory_2_outlined,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    presentacion,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          // Fila 3: Código del producto
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.qr_code,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Código: $codigo',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Fila 4: Precio compra (si existe) + Estado (si eliminado)
          if (precioCompra != null || mostrarEliminados) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (precioCompra != null) ...[
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 12,
                    color: Colors.blue[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Costo: C\$${precioCompra.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 11, color: Colors.blue[600]),
                  ),
                ],
                const Spacer(),
                if (mostrarEliminados)
                  _buildBadge(
                    icon: estado == 'Vendido'
                        ? Icons.sell
                        : Icons.delete_outline,
                    label: estado,
                    color: estado == 'Vendido' ? Colors.green : Colors.red,
                    isDark: isDark,
                  ),
              ],
            ),
          ],

          // Fila 4 (Footer): Vencimiento + Acciones
          const SizedBox(height: 8),
          Row(
            children: [
              // Vencimiento
              if (fecha != null)
                Expanded(
                  child: _buildVencimientoCompacto(
                    fecha,
                    diasRestantes,
                    isDark,
                  ),
                )
              else
                const Expanded(child: SizedBox()),

              // Acciones
              if (!mostrarEliminados) ...[
                InkWell(
                  onTap: () => editarProducto(context, p),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => eliminarProducto(context, p),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVencimientoCompacto(
    DateTime fecha,
    int diasRestantes,
    bool isDark,
  ) {
    Color color;
    String texto;
    IconData icon;

    if (diasRestantes < 0) {
      color = Colors.red;
      icon = Icons.warning;
      texto = 'Vencido hace ${-diasRestantes}d';
    } else if (diasRestantes == 0) {
      color = Colors.red;
      icon = Icons.warning;
      texto = 'Vence hoy';
    } else if (diasRestantes <= 30) {
      color = Colors.red;
      icon = Icons.schedule;
      texto = '${fecha.day}/${fecha.month}/${fecha.year} ($diasRestantes días)';
    } else if (diasRestantes <= 60) {
      color = Colors.orange;
      icon = Icons.schedule;
      texto = '${fecha.day}/${fecha.month}/${fecha.year} ($diasRestantes días)';
    } else {
      color = Colors.grey;
      icon = Icons.event;
      texto = '${fecha.day}/${fecha.month}/${fecha.year} ($diasRestantes días)';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
