import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Widget que muestra un gráfico de predicción de demanda de productos
/// con pestañas para Top y Bottom productos
class PrediccionDemandaChart extends StatefulWidget {
  const PrediccionDemandaChart({super.key});

  @override
  State<PrediccionDemandaChart> createState() => _PrediccionDemandaChartState();
}

class _PrediccionDemandaChartState extends State<PrediccionDemandaChart>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool cargando = false;
  bool obteniendoPrediccion = false;
  String? error;
  bool tienesDatos = false;

  // Datos de predicción
  List<ProductoDemanda> topProductos = [];
  List<ProductoDemanda> bottomProductos = [];

  // Control de vista: false = demanda total, true = demanda semanal
  bool mostrarDemandaSemanal = false;
  
  // Producto seleccionado para vista semanal (índice en la lista actual)
  int productoSeleccionadoTop = 0;
  int productoSeleccionadoBottom = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _obtenerPrediccion() async {
    setState(() {
      obteniendoPrediccion = true;
      error = null;
    });

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'smooth-api',
        method: HttpMethod.get,
      );

      if (response.status == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        
        // Parsear top_productos
        final topList = data['top_productos'] as List<dynamic>? ?? [];
        topProductos = topList.map((item) {
          final producto = item as Map<String, dynamic>;
          return ProductoDemanda(
            nombre: producto['producto'] as String? ?? 'Producto',
            yhatTotal: (producto['yhat_total'] as num?)?.toDouble() ?? 0.0,
            yhatPromedio: (producto['yhat_promedio'] as num?)?.toDouble() ?? 0.0,
            predicciones: _parsearPredicciones(producto['predicciones']),
          );
        }).toList();

        // Parsear bottom_productos
        final bottomList = data['bottom_productos'] as List<dynamic>? ?? [];
        bottomProductos = bottomList.map((item) {
          final producto = item as Map<String, dynamic>;
          return ProductoDemanda(
            nombre: producto['producto'] as String? ?? 'Producto',
            yhatTotal: (producto['yhat_total'] as num?)?.toDouble() ?? 0.0,
            yhatPromedio: (producto['yhat_promedio'] as num?)?.toDouble() ?? 0.0,
            predicciones: _parsearPredicciones(producto['predicciones']),
          );
        }).toList();

        tienesDatos = true;
      } else {
        error = 'Error al obtener predicción: ${response.data}';
      }
    } catch (e) {
      error = 'Error al conectar con el servidor: $e';
    }

    if (mounted) {
      setState(() {
        obteniendoPrediccion = false;
      });
    }
  }

  List<PrediccionSemana> _parsearPredicciones(dynamic prediccionesData) {
    if (prediccionesData == null) return [];
    final lista = prediccionesData as List<dynamic>;
    return lista.map((item) {
      final pred = item as Map<String, dynamic>;
      return PrediccionSemana(
        fecha: pred['ds'] as String? ?? '',
        semana: pred['semana'] as String? ?? '',
        yhat: (pred['yhat'] as num?)?.toDouble() ?? 0.0,
        yhatLower: (pred['yhat_lower'] as num?)?.toDouble() ?? 0.0,
        yhatUpper: (pred['yhat_upper'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: isDark ? 1 : 2,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.teal.withValues(alpha: isDark ? 0.4 : 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.inventory_2,
                  size: 24,
                  color: isDark ? Colors.teal[300] : Colors.teal[700],
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Predicción de Demanda por Productos',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Predicción de demanda total por producto',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),

            // Botón para obtener predicción
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: obteniendoPrediccion ? null : _obtenerPrediccion,
                icon: obteniendoPrediccion
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_graph),
                label: Text(
                  obteniendoPrediccion
                      ? 'Obteniendo predicción...'
                      : 'Obtener Predicción de Productos',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Mostrar contenido solo si hay datos
            if (!tienesDatos && error == null)
              _buildEmptyState(isDark)
            else if (error != null)
              _buildError(isDark)
            else ...[
              // Pestañas (solo 2: Top y Bottom)
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.grey.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TabBar(
                  controller: _tabController,
                  onTap: (_) => setState(() {}),
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: isDark ? Colors.teal[700] : Colors.teal,
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor:
                      isDark ? Colors.grey[400] : Colors.grey[700],
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.trending_up, size: 18),
                          SizedBox(width: 6),
                          Text('Top Productos'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.trending_down, size: 18),
                          SizedBox(width: 6),
                          Text('Bottom Productos'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Contenido según pestaña seleccionada
              if (cargando)
                const SizedBox(
                  height: 300,
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildTabContent(isDark),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withValues(alpha: isDark ? 0.2 : 0.15),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.bar_chart,
            size: 48,
            color: Colors.grey[isDark ? 600 : 400],
          ),
          const SizedBox(height: 12),
          Text(
            'Sin datos de predicción',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Presiona el botón para obtener la predicción de demanda por productos',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[isDark ? 500 : 500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _obtenerPrediccion,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(bool isDark) {
    List<ProductoDemanda> productos;
    Color colorPrincipal;
    String descripcion;
    IconData icono;
    final bool isTop = _tabController.index == 0;
    final int productoSeleccionado = isTop ? productoSeleccionadoTop : productoSeleccionadoBottom;

    switch (_tabController.index) {
      case 0:
        productos = topProductos;
        colorPrincipal = Colors.green;
        descripcion = mostrarDemandaSemanal 
            ? 'Demanda semanal proyectada (4 semanas)'
            : 'Productos con mayor demanda proyectada';
        icono = Icons.trending_up;
        break;
      case 1:
      default:
        productos = bottomProductos;
        colorPrincipal = Colors.orange;
        descripcion = mostrarDemandaSemanal 
            ? 'Demanda semanal proyectada (4 semanas)'
            : 'Productos con menor demanda proyectada';
        icono = Icons.trending_down;
        break;
    }

    if (productos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No hay productos en esta categoría',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    return Column(
      key: ValueKey('${_tabController.index}_${mostrarDemandaSemanal}_$productoSeleccionado'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Switch para alternar entre demanda total y demanda semanal
        _buildViewSwitch(isDark),
        const SizedBox(height: 12),

        // Dropdown para seleccionar producto (solo visible en modo semanal)
        if (mostrarDemandaSemanal) ...[
          _buildProductoDropdown(productos, isTop, isDark),
          const SizedBox(height: 12),
        ],

        // Descripción de la pestaña
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colorPrincipal.withValues(alpha: isDark ? 0.15 : 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorPrincipal.withValues(alpha: isDark ? 0.3 : 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(icono, size: 18, color: colorPrincipal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mostrarDemandaSemanal && productos.isNotEmpty
                      ? '${productos[productoSeleccionado].nombre} - $descripcion'
                      : descripcion,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Gráfico de barras
        SizedBox(
          height: 320,
          child: mostrarDemandaSemanal
              ? _buildWeeklyBarChart(productos[productoSeleccionado], colorPrincipal, isDark)
              : _buildHorizontalBarChart(productos, colorPrincipal, isDark),
        ),

        const SizedBox(height: 12),

        // Leyenda
        mostrarDemandaSemanal
            ? _buildLeyendaSemanal(colorPrincipal, isDark)
            : _buildLeyenda(colorPrincipal, isDark),
      ],
    );
  }

  Widget _buildViewSwitch(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.grey.withValues(alpha: isDark ? 0.2 : 0.15),
        ),
      ),
      child: Row(
        children: [
          Icon(
            mostrarDemandaSemanal ? Icons.calendar_view_day : Icons.bar_chart,
            size: 20,
            color: isDark ? Colors.teal[300] : Colors.teal[700],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mostrarDemandaSemanal ? 'Demanda Semanal' : 'Demanda Total',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.grey[800],
                  ),
                ),
                Text(
                  mostrarDemandaSemanal 
                      ? '4 semanas de predicción por producto'
                      : '10 productos con demanda total',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[isDark ? 500 : 600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: mostrarDemandaSemanal,
            onChanged: (value) {
              setState(() {
                mostrarDemandaSemanal = value;
              });
            },
            activeTrackColor: Colors.teal.withValues(alpha: 0.5),
            activeThumbColor: Colors.teal,
          ),
        ],
      ),
    );
  }

  Widget _buildProductoDropdown(List<ProductoDemanda> productos, bool isTop, bool isDark) {
    final int selectedIndex = isTop ? productoSeleccionadoTop : productoSeleccionadoBottom;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.teal.withValues(alpha: isDark ? 0.4 : 0.3),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedIndex,
          isExpanded: true,
          icon: Icon(
            Icons.arrow_drop_down,
            color: isDark ? Colors.teal[300] : Colors.teal[700],
          ),
          dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white : Colors.grey[800],
          ),
          items: productos.asMap().entries.map((entry) {
            return DropdownMenuItem<int>(
              value: entry.key,
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: (isTop ? Colors.green : Colors.orange).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '${entry.key + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isTop ? Colors.green : Colors.orange,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.value.nombre,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                if (isTop) {
                  productoSeleccionadoTop = value;
                } else {
                  productoSeleccionadoBottom = value;
                }
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildWeeklyBarChart(ProductoDemanda producto, Color color, bool isDark) {
    final predicciones = producto.predicciones;
    
    if (predicciones.isEmpty) {
      return Center(
        child: Text(
          'No hay predicciones semanales disponibles',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    final maxYhat = predicciones
        .map((p) => p.yhat)
        .reduce((a, b) => a > b ? a : b);
    
    // Evitar división por cero
    final safeMaxYhat = maxYhat > 0 ? maxYhat : 1.0;
    final horizontalInterval = safeMaxYhat / 5;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: safeMaxYhat * 1.15,
        minY: 0,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipPadding: const EdgeInsets.all(8),
            tooltipMargin: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final pred = predicciones[group.x.toInt()];
              return BarTooltipItem(
                '${pred.semana}\nDemanda: ${pred.yhat.toStringAsFixed(1)}\nRango: ${pred.yhatLower.toStringAsFixed(1)} - ${pred.yhatUpper.toStringAsFixed(1)}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 10,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= predicciones.length) {
                  return const SizedBox.shrink();
                }
                // Mostrar todas las semanas (son solo 4)
                final semana = predicciones[index].semana;
                // Extraer número de semana (ej: "Semana 2" -> "S2")
                final semanaCorta = semana.replaceAll('Semana ', 'S');
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    semanaCorta,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  _formatNumber(value),
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: horizontalInterval,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withValues(alpha: 0.2),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(show: false),
        barGroups: predicciones.asMap().entries.map((entry) {
          final index = entry.key;
          final pred = entry.value;

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: pred.yhat,
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.5),
                    color.withValues(alpha: 0.85),
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: 8,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(3),
                ),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: safeMaxYhat * 1.15,
                  color: Colors.grey.withValues(alpha: isDark ? 0.1 : 0.05),
                ),
              ),
            ],
            showingTooltipIndicators: [],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLeyendaSemanal(Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.withValues(alpha: isDark ? 0.2 : 0.15),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildLeyendaItem(
            'Demanda',
            'Unidades por semana',
            Icons.bar_chart,
            color,
            isDark,
          ),
          Container(
            width: 1,
            height: 35,
            color: Colors.grey.withValues(alpha: 0.3),
          ),
          _buildLeyendaItem(
            'Período',
            '4 semanas de predicción',
            Icons.date_range,
            Colors.blue,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalBarChart(
    List<ProductoDemanda> productos,
    Color color,
    bool isDark,
  ) {
    if (productos.isEmpty) {
      return const Center(child: Text('No hay datos'));
    }

    final maxCantidad = productos
        .map((p) => p.yhatTotal)
        .reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxCantidad * 1.15,
        minY: 0,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipPadding: const EdgeInsets.all(8),
            tooltipMargin: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final producto = productos[group.x.toInt()];
              return BarTooltipItem(
                '${producto.nombre}\nTotal: ${producto.yhatTotal.toStringAsFixed(0)} unidades\nPromedio: ${producto.yhatPromedio.toStringAsFixed(1)}/semana',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= productos.length) {
                  return const SizedBox.shrink();
                }
                final nombre = productos[index].nombre;
                // Truncar nombre si es muy largo
                final nombreCorto =
                    nombre.length > 12 ? '${nombre.substring(0, 10)}...' : nombre;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: RotatedBox(
                    quarterTurns: 1,
                    child: Text(
                      nombreCorto,
                      style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              },
              reservedSize: 80,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              getTitlesWidget: (value, meta) {
                return Text(
                  _formatNumber(value),
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxCantidad / 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withValues(alpha: 0.2),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(show: false),
        barGroups: productos.asMap().entries.map((entry) {
          final index = entry.key;
          final producto = entry.value;

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: producto.yhatTotal,
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.6),
                    color.withValues(alpha: 0.9),
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: 22,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxCantidad * 1.15,
                  color: Colors.grey.withValues(alpha: isDark ? 0.1 : 0.05),
                ),
              ),
            ],
            showingTooltipIndicators: [],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLeyenda(Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.withValues(alpha: isDark ? 0.2 : 0.15),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildLeyendaItem(
            'Total',
            'Demanda total proyectada',
            Icons.inventory,
            color,
            isDark,
          ),
          Container(
            width: 1,
            height: 35,
            color: Colors.grey.withValues(alpha: 0.3),
          ),
          _buildLeyendaItem(
            'Promedio',
            'Demanda diaria promedio',
            Icons.show_chart,
            Colors.blue,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildLeyendaItem(
    String label,
    String descripcion,
    IconData icono,
    Color color,
    bool isDark,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.25 : 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icono, color: color, size: 16),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.grey[800],
              ),
            ),
            Text(
              descripcion,
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey[isDark ? 500 : 600],
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatNumber(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }
}

/// Modelo de datos para predicción de una semana
class PrediccionSemana {
  final String fecha;
  final String semana;
  final double yhat;
  final double yhatLower;
  final double yhatUpper;

  PrediccionSemana({
    required this.fecha,
    required this.semana,
    required this.yhat,
    required this.yhatLower,
    required this.yhatUpper,
  });
}

/// Modelo de datos para un producto con su demanda predicha
class ProductoDemanda {
  final String nombre;
  final double yhatTotal;
  final double yhatPromedio;
  final List<PrediccionSemana> predicciones;

  ProductoDemanda({
    required this.nombre,
    required this.yhatTotal,
    required this.yhatPromedio,
    required this.predicciones,
  });
}
