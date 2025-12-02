import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportesVentasScreen extends StatefulWidget {
  const ReportesVentasScreen({super.key});

  @override
  State<ReportesVentasScreen> createState() => _ReportesVentasScreenState();
}

class _ReportesVentasScreenState extends State<ReportesVentasScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> ventas = [];
  DateTime? fechaInicio;
  DateTime? fechaFin;
  List<int> ventasSeleccionadas = []; // IDs de ventas para reporte detallado
  late TabController _tabController;
  bool _isLoading = true; // Estado de carga
  bool _isLoadingMore = false; // Estado de carga de más datos
  bool _hasMoreData = true; // Si hay más datos por cargar

  // Paginación
  static const int _pageSize = 50; // Ventas por página
  int _currentPage = 0;

  // Filtros
  String ordenarPor = 'fecha_desc';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    cargarVentas();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> cargarVentas({bool reset = true}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _currentPage = 0;
        _hasMoreData = true;
        ventas = [];
      });
    } else {
      if (_isLoadingMore || !_hasMoreData) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      // Construir filtros de fecha
      String? fechaInicioStr;
      String? fechaFinStr;

      if (fechaInicio != null) {
        fechaInicioStr = fechaInicio!.toIso8601String().substring(0, 10);
      }
      if (fechaFin != null) {
        fechaFinStr = fechaFin!.toIso8601String().substring(0, 10);
      }

      // Consulta paginada de ventas
      final ventasBase = await _buildVentasQueryPaginated(
        fechaInicioStr,
        fechaFinStr,
        _currentPage * _pageSize,
        _pageSize,
      );

      if (ventasBase.isEmpty) {
        if (mounted) {
          setState(() {
            _hasMoreData = false;
            _isLoading = false;
            _isLoadingMore = false;
          });
        }
        return;
      }

      // Obtener IDs de ventas para esta página
      final ventaIds = ventasBase.map((v) => v['id_venta'] as int).toList();

      // Consulta de productos solo para las ventas de esta página
      final productosResponse = await Supabase.instance.client
          .from('producto_en_venta')
          .select(
            'id_venta, id_producto, precio_historico, costo_historico, producto(nombre_producto, codigo)',
          )
          .inFilter('id_venta', ventaIds);

      final todosProductos = List<Map<String, dynamic>>.from(productosResponse);

      // Indexar productos por id_venta
      final productosPorVenta = <int, List<Map<String, dynamic>>>{};
      for (var p in todosProductos) {
        final idVenta = p['id_venta'] as int?;
        if (idVenta != null) {
          productosPorVenta.putIfAbsent(idVenta, () => []).add(p);
        }
      }

      // Procesar ventas
      for (var v in ventasBase) {
        final idVenta = v['id_venta'] as int;
        final listaProductos = productosPorVenta[idVenta] ?? [];

        double totalVenta = 0.0;
        double totalCosto = 0.0;
        for (var p in listaProductos) {
          final precioHistorico =
              (p['precio_historico'] as num?)?.toDouble() ?? 0.0;
          final costoHistorico =
              (p['costo_historico'] as num?)?.toDouble() ?? 0.0;
          totalVenta += precioHistorico;
          totalCosto += costoHistorico;
        }

        v['productos'] = listaProductos;
        v['total_calculado'] = totalVenta;
        v['total_costo'] = totalCosto;
        v['ganancia_total'] = totalVenta - totalCosto;
      }

      if (mounted) {
        setState(() {
          if (reset) {
            ventas = ventasBase;
          } else {
            ventas.addAll(ventasBase);
          }
          _currentPage++;
          _hasMoreData = ventasBase.length >= _pageSize;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar ventas: $e')));
      }
    }
  }

  Future<List<Map<String, dynamic>>> _buildVentasQueryPaginated(
    String? fechaInicio,
    String? fechaFin,
    int offset,
    int limit,
  ) async {
    var query = Supabase.instance.client
        .from('venta')
        .select(
          'id_venta, fecha, total, cliente(nombre_cliente), empleado(nombre_empleado), payment_method:payment_method_id(name, provider)',
        );

    // Aplicar filtros de fecha primero
    if (fechaInicio != null) {
      query = query.gte('fecha', fechaInicio);
    }
    if (fechaFin != null) {
      query = query.lte('fecha', fechaFin);
    }

    // Luego ordenar y paginar
    final response = await query
        .order('fecha', ascending: false)
        .range(offset, offset + limit - 1);

    return List<Map<String, dynamic>>.from(response);
  }

  int _contarProductos(Map<String, dynamic> venta) {
    final productos = (venta['productos'] as List?) ?? [];
    return productos.length;
  }

  // PDF para reporte general (resumen de ventas)
  Future<Uint8List> _buildPdfGeneral(
    List<Map<String, dynamic>> ventasParaPdf,
  ) async {
    final pdf = pw.Document();

    final totalGeneral = ventasParaPdf.fold<double>(
      0.0,
      (sum, v) => sum + (v['total_calculado'] ?? 0.0),
    );
    final costoGeneral = ventasParaPdf.fold<double>(
      0.0,
      (sum, v) => sum + (v['total_costo'] ?? 0.0),
    );
    final gananciaGeneral = totalGeneral - costoGeneral;

    pdf.addPage(
      pw.MultiPage(
        build: (context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Reporte General de Ventas',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Text(
              'Rango de fechas: '
              '${fechaInicio != null ? '${fechaInicio!.day}/${fechaInicio!.month}/${fechaInicio!.year}' : 'Todas'}'
              ' - '
              '${fechaFin != null ? '${fechaFin!.day}/${fechaFin!.month}/${fechaFin!.year}' : 'Todas'}',
            ),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: const [
                'ID',
                'Fecha',
                'Cliente',
                'Productos',
                'Total Venta',
                'Ganancia',
              ],
              data: ventasParaPdf.map((v) {
                return [
                  v['id_venta'].toString(),
                  (v['fecha'] ?? '').toString(),
                  v['cliente']?['nombre_cliente']?.toString() ?? 'N/A',
                  _contarProductos(v).toString(),
                  'C\$${(v['total_calculado'] ?? 0.0).toStringAsFixed(2)}',
                  'C\$${(v['ganancia_total'] ?? 0.0).toStringAsFixed(2)}',
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 10),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Total Vendido: C\$${totalGeneral.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'Total Costo: C\$${costoGeneral.toStringAsFixed(2)}',
                    ),
                    pw.Text(
                      'Ganancia Total: C\$${gananciaGeneral.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // PDF para reporte detallado (productos por venta)
  Future<Uint8List> _buildPdfDetallado(
    List<Map<String, dynamic>> ventasParaPdf,
  ) async {
    final pdf = pw.Document();

    for (var venta in ventasParaPdf) {
      final productos = (venta['productos'] as List?) ?? [];

      // Agrupar productos iguales usando precio_historico y costo_historico
      final Map<String, Map<String, dynamic>> productosAgrupados = {};
      for (final p in productos) {
        final prod = (p['producto'] as Map<String, dynamic>?) ?? {};
        final nombre =
            prod['nombre_producto']?.toString() ?? 'Producto eliminado';
        final codigo = prod['codigo']?.toString() ?? 'N/A';
        // Usar precio_historico y costo_historico de producto_en_venta
        final precioVenta = (p['precio_historico'] as num?)?.toDouble() ?? 0.0;
        final precioCompra = (p['costo_historico'] as num?)?.toDouble() ?? 0.0;

        final key = '$nombre|$codigo|$precioVenta|$precioCompra';

        if (!productosAgrupados.containsKey(key)) {
          productosAgrupados[key] = {
            'nombre': nombre,
            'codigo': codigo,
            'precio_venta': precioVenta,
            'precio_compra': precioCompra,
            'cantidad': 1,
          };
        } else {
          productosAgrupados[key]!['cantidad'] =
              (productosAgrupados[key]!['cantidad'] as int) + 1;
        }
      }

      final listaAgrupada = productosAgrupados.values.toList();

      pdf.addPage(
        pw.MultiPage(
          build: (context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'ID de Venta: ${venta['id_venta']}',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Text('Fecha: ${venta['fecha'] ?? 'N/A'}'),
              pw.Text(
                'Cliente: ${venta['cliente']?['nombre_cliente'] ?? 'N/A'}',
              ),
              pw.Text(
                'Empleado: ${venta['empleado']?['nombre_empleado'] ?? 'N/A'}',
              ),
              pw.Text(
                'Método de Pago: ${venta['payment_method']?['name'] ?? 'N/A'}',
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Productos:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 5),
              pw.Table.fromTextArray(
                headers: const [
                  'Producto',
                  'Código',
                  'Cant.',
                  'P. Compra',
                  'P. Venta',
                  'Ganancia Unit.',
                  'Ganancia Total',
                ],
                data: listaAgrupada.map((p) {
                  final precioCompra = p['precio_compra'] as double? ?? 0.0;
                  final precioVenta = p['precio_venta'] as double? ?? 0.0;
                  final cantidad = p['cantidad'] as int? ?? 0;
                  final gananciaUnit = precioVenta - precioCompra;
                  final gananciaTotal = gananciaUnit * cantidad;

                  return [
                    p['nombre']?.toString() ?? 'N/A',
                    p['codigo']?.toString() ?? 'N/A',
                    cantidad.toString(),
                    'C\$${precioCompra.toStringAsFixed(2)}',
                    'C\$${precioVenta.toStringAsFixed(2)}',
                    'C\$${gananciaUnit.toStringAsFixed(2)}',
                    'C\$${gananciaTotal.toStringAsFixed(2)}',
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Total Costo: C\$${(venta['total_costo'] ?? 0.0).toStringAsFixed(2)}',
                      ),
                      pw.Text(
                        'Total Venta: C\$${(venta['total_calculado'] ?? 0.0).toStringAsFixed(2)}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'Ganancia: C\$${(venta['ganancia_total'] ?? 0.0).toStringAsFixed(2)}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ];
          },
        ),
      );
    }

    return pdf.save();
  }

  Future<void> _exportarPdfGeneral() async {
    if (ventas.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay ventas para exportar.')),
        );
      }
      return;
    }

    await Printing.layoutPdf(
      onLayout: (format) async => _buildPdfGeneral(ventas),
    );
  }

  Future<void> _exportarPdfDetallado() async {
    if (ventasSeleccionadas.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona al menos una venta.')),
        );
      }
      return;
    }

    final ventasFiltradas = ventas
        .where((v) => ventasSeleccionadas.contains(v['id_venta'] as int))
        .toList();

    await Printing.layoutPdf(
      onLayout: (format) async => _buildPdfDetallado(ventasFiltradas),
    );
  }

  double calcularTotalGeneral() {
    return ventas.fold(0.0, (sum, v) => sum + (v['total_calculado'] ?? 0.0));
  }

  double calcularCostoGeneral() {
    return ventas.fold(0.0, (sum, v) => sum + (v['total_costo'] ?? 0.0));
  }

  double calcularGananciaGeneral() {
    return calcularTotalGeneral() - calcularCostoGeneral();
  }

  List<Map<String, dynamic>> _filtrarYOrdenarVentas() {
    var ventasFiltradas = List<Map<String, dynamic>>.from(ventas);

    // Ordenar según criterio seleccionado
    ventasFiltradas.sort((a, b) {
      switch (ordenarPor) {
        case 'fecha_asc':
          return (a['fecha'] ?? '').toString().compareTo(
            (b['fecha'] ?? '').toString(),
          );
        case 'fecha_desc':
          return (b['fecha'] ?? '').toString().compareTo(
            (a['fecha'] ?? '').toString(),
          );
        case 'ganancia_asc':
          return ((a['ganancia_total'] ?? 0.0) as double).compareTo(
            (b['ganancia_total'] ?? 0.0) as double,
          );
        case 'ganancia_desc':
          return ((b['ganancia_total'] ?? 0.0) as double).compareTo(
            (a['ganancia_total'] ?? 0.0) as double,
          );
        case 'total_asc':
          return ((a['total_calculado'] ?? 0.0) as double).compareTo(
            (b['total_calculado'] ?? 0.0) as double,
          );
        case 'total_desc':
          return ((b['total_calculado'] ?? 0.0) as double).compareTo(
            (a['total_calculado'] ?? 0.0) as double,
          );
        case 'productos_asc':
          return _contarProductos(a).compareTo(_contarProductos(b));
        case 'productos_desc':
          return _contarProductos(b).compareTo(_contarProductos(a));
        default:
          return 0;
      }
    });

    return ventasFiltradas;
  }

  String _getFilterSummary() {
    final parts = <String>[];

    if (fechaInicio != null || fechaFin != null) {
      if (fechaInicio != null && fechaFin != null) {
        parts.add(
          '${fechaInicio!.day}/${fechaInicio!.month} - ${fechaFin!.day}/${fechaFin!.month}',
        );
      } else if (fechaInicio != null) {
        parts.add('Desde ${fechaInicio!.day}/${fechaInicio!.month}');
      } else {
        parts.add('Hasta ${fechaFin!.day}/${fechaFin!.month}');
      }
    }

    if (ordenarPor != 'fecha_desc') {
      final ordenLabels = {
        'fecha_asc': 'Fecha ↑',
        'ganancia_desc': 'Ganancia ↓',
        'ganancia_asc': 'Ganancia ↑',
        'total_desc': 'Total ↓',
        'total_asc': 'Total ↑',
        'productos_desc': 'Productos ↓',
        'productos_asc': 'Productos ↑',
      };
      parts.add(ordenLabels[ordenarPor] ?? '');
    }

    return parts.isEmpty ? 'Filtros' : parts.join(' • ');
  }

  void _mostrarModalFiltros() {
    var tempFechaInicio = fechaInicio;
    var tempFechaFin = fechaFin;
    var tempOrdenarPor = ordenarPor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filtros',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            tempFechaInicio = null;
                            tempFechaFin = null;
                            tempOrdenarPor = 'fecha_desc';
                          });
                        },
                        child: const Text('Limpiar todo'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Rango de fechas
                  const Text(
                    'Rango de fechas',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Text(
                            tempFechaInicio != null
                                ? '${tempFechaInicio!.day}/${tempFechaInicio!.month}/${tempFechaInicio!.year}'
                                : 'Desde',
                          ),
                          onPressed: () async {
                            final fecha = await showDatePicker(
                              context: context,
                              initialDate: tempFechaInicio ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (fecha != null) {
                              setModalState(() => tempFechaInicio = fecha);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Text(
                            tempFechaFin != null
                                ? '${tempFechaFin!.day}/${tempFechaFin!.month}/${tempFechaFin!.year}'
                                : 'Hasta',
                          ),
                          onPressed: () async {
                            final fecha = await showDatePicker(
                              context: context,
                              initialDate: tempFechaFin ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (fecha != null) {
                              setModalState(() => tempFechaFin = fecha);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Ordenar por
                  const Text(
                    'Ordenar por',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip(
                        'Fecha ↓',
                        'fecha_desc',
                        tempOrdenarPor,
                        (v) {
                          setModalState(() => tempOrdenarPor = v);
                        },
                      ),
                      _buildFilterChip('Fecha ↑', 'fecha_asc', tempOrdenarPor, (
                        v,
                      ) {
                        setModalState(() => tempOrdenarPor = v);
                      }),
                      _buildFilterChip(
                        'Ganancia ↓',
                        'ganancia_desc',
                        tempOrdenarPor,
                        (v) {
                          setModalState(() => tempOrdenarPor = v);
                        },
                      ),
                      _buildFilterChip(
                        'Ganancia ↑',
                        'ganancia_asc',
                        tempOrdenarPor,
                        (v) {
                          setModalState(() => tempOrdenarPor = v);
                        },
                      ),
                      _buildFilterChip(
                        'Total ↓',
                        'total_desc',
                        tempOrdenarPor,
                        (v) {
                          setModalState(() => tempOrdenarPor = v);
                        },
                      ),
                      _buildFilterChip('Total ↑', 'total_asc', tempOrdenarPor, (
                        v,
                      ) {
                        setModalState(() => tempOrdenarPor = v);
                      }),
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
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Cerrar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            // Verificar si cambiaron las fechas (requiere recarga de BD)
                            final cambioFechas =
                                fechaInicio?.toIso8601String() !=
                                    tempFechaInicio?.toIso8601String() ||
                                fechaFin?.toIso8601String() !=
                                    tempFechaFin?.toIso8601String();

                            setState(() {
                              fechaInicio = tempFechaInicio;
                              fechaFin = tempFechaFin;
                              ordenarPor = tempOrdenarPor;
                            });
                            Navigator.pop(context);

                            // Solo recargar si cambiaron las fechas
                            if (cambioFechas) {
                              cargarVentas();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
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
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    String currentValue,
    Function(String) onSelected,
  ) {
    final isSelected = currentValue == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(value),
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      checkmarkColor: Theme.of(context).colorScheme.primary,
    );
  }

  Widget _buildReporteGeneral(bool isDark) {
    return Column(
      children: [
        // Resumen de totales
        Card(
          margin: const EdgeInsets.all(12),
          color: isDark ? Colors.blue[900]?.withOpacity(0.3) : Colors.blue[50],
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text(
                      'Total Vendido',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'C\$${calcularTotalGeneral().toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 18, color: Colors.blue),
                    ),
                  ],
                ),
                Column(
                  children: [
                    const Text(
                      'Total Costo',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'C\$${calcularCostoGeneral().toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    const Text(
                      'Ganancia Total',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'C\$${calcularGananciaGeneral().toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Lista de ventas con paginación
        Expanded(
          child: ListView.builder(
            itemCount: ventas.length + (_hasMoreData ? 1 : 0),
            itemBuilder: (context, index) {
              // Botón de cargar más al final
              if (index == ventas.length) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: _isLoadingMore
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          onPressed: () => cargarVentas(reset: false),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Cargar más ventas'),
                        ),
                );
              }

              final v = ventas[index];
              final ganancia = v['ganancia_total'] ?? 0.0;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.shopping_cart, color: Colors.blue),
                  title: Text(
                    'ID de Venta: ${v['id_venta']} - C\$${(v['total_calculado'] ?? 0.0).toStringAsFixed(2)}',
                  ),
                  subtitle: Text(
                    'Fecha: ${v['fecha']}\n'
                    'Cliente: ${v['cliente']?['nombre_cliente'] ?? 'N/A'}\n'
                    'Ganancia: C\$${ganancia.toStringAsFixed(2)}',
                  ),
                  trailing: Text(
                    '${_contarProductos(v)} productos',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  isThreeLine: true,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReporteDetallado(bool isDark) {
    // Aplicar filtros y ordenamiento
    final ventasFiltradas = _filtrarYOrdenarVentas();

    // Calcular totales de ventas seleccionadas
    final ventasSeleccionadasData = ventasFiltradas
        .where((v) => ventasSeleccionadas.contains(v['id_venta'] as int))
        .toList();

    final totalVentaSeleccionada = ventasSeleccionadasData.fold<double>(
      0.0,
      (sum, v) => sum + (v['total_calculado'] ?? 0.0),
    );
    final totalCostoSeleccionado = ventasSeleccionadasData.fold<double>(
      0.0,
      (sum, v) => sum + (v['total_costo'] ?? 0.0),
    );
    final gananciaSeleccionada =
        totalVentaSeleccionada - totalCostoSeleccionado;

    return Column(
      children: [
        // Resumen de ventas seleccionadas (compacto)
        if (ventasSeleccionadas.isNotEmpty)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: isDark
                ? Colors.green[900]?.withOpacity(0.3)
                : Colors.green[50],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${ventasSeleccionadas.length} seleccionada(s)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Total: C\$${totalVentaSeleccionada.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Ganancia: C\$${gananciaSeleccionada.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        // Lista scrolleable de todas las ventas (seleccionadas y disponibles)
        Expanded(
          child: ListView.builder(
            itemCount: ventasFiltradas.length + (_hasMoreData ? 1 : 0),
            itemBuilder: (context, index) {
              // Botón de cargar más al final
              if (index == ventasFiltradas.length) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: _isLoadingMore
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          onPressed: () => cargarVentas(reset: false),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Cargar más ventas'),
                        ),
                );
              }

              final v = ventasFiltradas[index];
              final isSelected = ventasSeleccionadas.contains(
                v['id_venta'] as int,
              );
              return _buildVentaDetalladaCard(v, isSelected);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVentaDetalladaCard(Map<String, dynamic> v, bool isSelected) {
    final idVenta = v['id_venta'] as int;
    final productos = (v['productos'] as List?) ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Agrupar productos usando precio_historico y costo_historico
    final Map<String, Map<String, dynamic>> productosAgrupados = {};
    for (final p in productos) {
      final prod = (p['producto'] as Map<String, dynamic>?) ?? {};
      final nombre =
          prod['nombre_producto']?.toString() ?? 'Producto eliminado';
      final codigo = prod['codigo']?.toString() ?? 'N/A';
      // Usar precio_historico y costo_historico de producto_en_venta
      final precioVenta = (p['precio_historico'] as num?)?.toDouble() ?? 0.0;
      final precioCompra = (p['costo_historico'] as num?)?.toDouble() ?? 0.0;

      final key = '$nombre|$codigo|$precioVenta|$precioCompra';

      if (!productosAgrupados.containsKey(key)) {
        productosAgrupados[key] = {
          'nombre': nombre,
          'codigo': codigo,
          'precio_venta': precioVenta,
          'precio_compra': precioCompra,
          'cantidad': 1,
        };
      } else {
        productosAgrupados[key]!['cantidad'] =
            (productosAgrupados[key]!['cantidad'] as int) + 1;
      }
    }

    final listaAgrupada = productosAgrupados.values.toList();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: isSelected
          ? (isDark ? Colors.green[900]?.withOpacity(0.3) : Colors.green[50])
          : null,
      child: ExpansionTile(
        dense: true,
        leading: Checkbox(
          value: isSelected,
          onChanged: (value) {
            setState(() {
              if (value == true) {
                ventasSeleccionadas.add(idVenta);
              } else {
                ventasSeleccionadas.remove(idVenta);
              }
            });
          },
        ),
        title: Text(
          'ID de Venta: $idVenta - C\$${(v['total_calculado'] ?? 0.0).toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${v['fecha']} | ${v['cliente']?['nombre_cliente'] ?? 'N/A'} | Ganancia: C\$${(v['ganancia_total'] ?? 0.0).toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 12),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Productos:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                ...listaAgrupada.map((p) {
                  final precioCompra = p['precio_compra'] as double? ?? 0.0;
                  final precioVenta = p['precio_venta'] as double? ?? 0.0;
                  final cantidad = p['cantidad'] as int? ?? 0;
                  final gananciaUnit = precioVenta - precioCompra;
                  final gananciaTotal = gananciaUnit * cantidad;

                  return Card(
                    color: isDark ? Colors.grey[800] : Colors.grey[100],
                    margin: const EdgeInsets.only(bottom: 4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${p['nombre']} (${p['codigo']}) - Cant: $cantidad',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Compra: C\$${precioCompra.toStringAsFixed(2)} | Venta: C\$${precioVenta.toStringAsFixed(2)} | Ganancia: C\$${gananciaTotal.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Costo: C\$${(v['total_costo'] ?? 0.0).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Venta: C\$${(v['total_calculado'] ?? 0.0).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Ganancia: C\$${(v['ganancia_total'] ?? 0.0).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    // Mostrar pantalla de carga mientras se cargan los datos
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reportes de Ventas')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                'Cargando reportes...',
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes de Ventas'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.summarize), text: 'Reporte General'),
            Tab(icon: Icon(Icons.analytics), text: 'Reporte Detallado'),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            children: [
              // Botón de filtros compacto
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.filter_list),
                      label: Text(_getFilterSummary()),
                      onPressed: _mostrarModalFiltros,
                    ),
                    if (fechaInicio != null ||
                        fechaFin != null ||
                        ordenarPor != 'fecha_desc')
                      IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Limpiar filtros',
                        onPressed: () {
                          setState(() {
                            fechaInicio = null;
                            fechaFin = null;
                            ordenarPor = 'fecha_desc';
                          });
                          cargarVentas();
                        },
                      ),
                  ],
                ),
              ),
              // Contenido de tabs
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildReporteGeneral(isDark),
                    _buildReporteDetallado(isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) {
            _exportarPdfGeneral();
          } else {
            _exportarPdfDetallado();
          }
        },
        backgroundColor: Colors.red,
        icon: const Icon(Icons.picture_as_pdf),
        label: const Text('Exportar'),
      ),
    );
  }
}
