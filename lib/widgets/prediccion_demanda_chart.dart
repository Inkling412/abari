import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// Widget que muestra un gráfico de predicción de demanda de productos
/// con pestañas para filtrar por nivel de demanda
class PrediccionDemandaChart extends StatefulWidget {
  const PrediccionDemandaChart({super.key});

  @override
  State<PrediccionDemandaChart> createState() => _PrediccionDemandaChartState();
}

class _PrediccionDemandaChartState extends State<PrediccionDemandaChart>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool cargando = false;
  String? error;

  // Datos de muestra para cada categoría
  late List<ProductoDemanda> productosMayorDemanda;
  late List<ProductoDemanda> productosMenorDemanda;
  late List<ProductoDemanda> productosMediaDemanda;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _generarDatosMuestra();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _generarDatosMuestra() {
    // Productos con mayor demanda (ordenados de mayor a menor)
    productosMayorDemanda = [
      ProductoDemanda(
        nombre: 'Coca-Cola 600ml',
        cantidad: 450,
        tendencia: 12.5,
      ),
      ProductoDemanda(
        nombre: 'Pan Bimbo Grande',
        cantidad: 380,
        tendencia: 8.2,
      ),
      ProductoDemanda(
        nombre: 'Leche Parmalat 1L',
        cantidad: 320,
        tendencia: 5.7,
      ),
      ProductoDemanda(
        nombre: 'Arroz Faisan 5lb',
        cantidad: 290,
        tendencia: 15.3,
      ),
      ProductoDemanda(
        nombre: 'Aceite Mazola 1L',
        cantidad: 275,
        tendencia: 3.1,
      ),
      ProductoDemanda(
        nombre: 'Azúcar San Antonio 2lb',
        cantidad: 260,
        tendencia: 7.8,
      ),
      ProductoDemanda(
        nombre: 'Frijoles Rojos 1lb',
        cantidad: 245,
        tendencia: 9.4,
      ),
      ProductoDemanda(nombre: 'Huevos Docena', cantidad: 230, tendencia: 4.2),
      ProductoDemanda(
        nombre: 'Café Presto 100g',
        cantidad: 215,
        tendencia: 6.5,
      ),
      ProductoDemanda(nombre: 'Jabón Xtra 500g', cantidad: 200, tendencia: 2.8),
    ];

    // Productos con menor demanda (ordenados de menor a mayor)
    productosMenorDemanda = [
      ProductoDemanda(
        nombre: 'Salsa Inglesa 150ml',
        cantidad: 8,
        tendencia: -5.2,
      ),
      ProductoDemanda(
        nombre: 'Pimienta Molida 50g',
        cantidad: 12,
        tendencia: -3.1,
      ),
      ProductoDemanda(
        nombre: 'Vinagre Blanco 500ml',
        cantidad: 15,
        tendencia: -8.7,
      ),
      ProductoDemanda(
        nombre: 'Canela en Raja 25g',
        cantidad: 18,
        tendencia: -2.4,
      ),
      ProductoDemanda(nombre: 'Mostaza 200g', cantidad: 22, tendencia: -4.6),
      ProductoDemanda(
        nombre: 'Salsa de Soya 250ml',
        cantidad: 25,
        tendencia: -1.8,
      ),
      ProductoDemanda(nombre: 'Orégano 15g', cantidad: 28, tendencia: -6.3),
      ProductoDemanda(nombre: 'Laurel 10g', cantidad: 30, tendencia: -0.5),
      ProductoDemanda(
        nombre: 'Comino Molido 30g',
        cantidad: 32,
        tendencia: -2.9,
      ),
      ProductoDemanda(
        nombre: 'Clavo de Olor 15g',
        cantidad: 35,
        tendencia: -4.1,
      ),
    ];

    // Productos con demanda media
    productosMediaDemanda = [
      ProductoDemanda(
        nombre: 'Pasta Dental Colgate',
        cantidad: 85,
        tendencia: 1.2,
      ),
      ProductoDemanda(
        nombre: 'Shampoo H&S 400ml',
        cantidad: 82,
        tendencia: -0.8,
      ),
      ProductoDemanda(
        nombre: 'Detergente Rinso 1kg',
        cantidad: 78,
        tendencia: 2.1,
      ),
      ProductoDemanda(
        nombre: 'Papel Higiénico 4pk',
        cantidad: 75,
        tendencia: 0.5,
      ),
      ProductoDemanda(
        nombre: 'Galletas Oreo 154g',
        cantidad: 72,
        tendencia: -1.5,
      ),
      ProductoDemanda(
        nombre: 'Atún Van Camps 170g',
        cantidad: 70,
        tendencia: 3.2,
      ),
      ProductoDemanda(
        nombre: 'Mayonesa Kraft 400g',
        cantidad: 68,
        tendencia: -0.3,
      ),
      ProductoDemanda(
        nombre: 'Sardinas Calvo 125g',
        cantidad: 65,
        tendencia: 1.8,
      ),
      ProductoDemanda(
        nombre: 'Salsa Tomate 400g',
        cantidad: 62,
        tendencia: 0.9,
      ),
      ProductoDemanda(
        nombre: 'Avena Quaker 400g',
        cantidad: 60,
        tendencia: -2.1,
      ),
    ];
  }

  Future<void> _cargarDatos() async {
    setState(() {
      cargando = true;
      error = null;
    });

    // TODO: Implementar llamada al endpoint cuando esté listo
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      setState(() {
        _generarDatosMuestra();
        cargando = false;
      });
    }
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
                    'Predicción de Demanda',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                // Badge de datos de muestra
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.science, size: 14, color: Colors.amber[700]),
                      const SizedBox(width: 4),
                      Text(
                        'Demo',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber[700],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Botón refrescar
                IconButton(
                  onPressed: cargando ? null : _cargarDatos,
                  icon: cargando
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.teal[400],
                          ),
                        )
                      : Icon(
                          Icons.refresh,
                          color: isDark ? Colors.teal[300] : Colors.teal[600],
                        ),
                  tooltip: 'Actualizar predicción',
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Predicción de cantidad demandada por producto (próximos 30 días)',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),

            // Pestañas
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
                unselectedLabelColor: isDark
                    ? Colors.grey[400]
                    : Colors.grey[700],
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.trending_up, size: 16),
                        SizedBox(width: 4),
                        Text('Mayor'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.trending_down, size: 16),
                        SizedBox(width: 4),
                        Text('Menor'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.trending_flat, size: 16),
                        SizedBox(width: 4),
                        Text('Media'),
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
            else if (error != null)
              _buildError(isDark)
            else
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildTabContent(isDark),
              ),
          ],
        ),
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
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
          TextButton(onPressed: _cargarDatos, child: const Text('Reintentar')),
        ],
      ),
    );
  }

  Widget _buildTabContent(bool isDark) {
    List<ProductoDemanda> productos;
    Color colorPrincipal;
    String descripcion;
    IconData icono;

    switch (_tabController.index) {
      case 0:
        productos = productosMayorDemanda;
        colorPrincipal = Colors.green;
        descripcion = 'Top 10 productos con mayor demanda proyectada';
        icono = Icons.trending_up;
        break;
      case 1:
        productos = productosMenorDemanda;
        colorPrincipal = Colors.red;
        descripcion = 'Top 10 productos con menor demanda proyectada';
        icono = Icons.trending_down;
        break;
      case 2:
      default:
        productos = productosMediaDemanda;
        colorPrincipal = Colors.blue;
        descripcion = 'Top 10 productos con demanda media proyectada';
        icono = Icons.trending_flat;
        break;
    }

    return Column(
      key: ValueKey(_tabController.index),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  descripcion,
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

        // Gráfico de barras horizontales
        SizedBox(
          height: 320,
          child: _buildHorizontalBarChart(productos, colorPrincipal, isDark),
        ),

        const SizedBox(height: 12),

        // Leyenda
        _buildLeyenda(colorPrincipal, isDark),
      ],
    );
  }

  Widget _buildHorizontalBarChart(
    List<ProductoDemanda> productos,
    Color color,
    bool isDark,
  ) {
    final maxCantidad = productos
        .map((p) => p.cantidad)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

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
              final tendenciaStr = producto.tendencia >= 0
                  ? '+${producto.tendencia.toStringAsFixed(1)}%'
                  : '${producto.tendencia.toStringAsFixed(1)}%';
              return BarTooltipItem(
                '${producto.nombre}\n${producto.cantidad} unidades\nTendencia: $tendenciaStr',
                TextStyle(
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
                final nombreCorto = nombre.length > 12
                    ? '${nombre.substring(0, 10)}...'
                    : nombre;
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
                toY: producto.cantidad.toDouble(),
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
            'Cantidad',
            'Unidades proyectadas',
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
            'Tendencia',
            '% vs mes anterior',
            Icons.show_chart,
            Colors.orange,
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

/// Modelo de datos para un producto con su demanda predicha
class ProductoDemanda {
  final String nombre;
  final int cantidad;
  final double tendencia; // Porcentaje de cambio respecto al mes anterior

  ProductoDemanda({
    required this.nombre,
    required this.cantidad,
    required this.tendencia,
  });

  factory ProductoDemanda.fromJson(Map<String, dynamic> json) {
    return ProductoDemanda(
      nombre: json['nombre'] as String? ?? 'Producto',
      cantidad: json['cantidad'] as int? ?? 0,
      tendencia: (json['tendencia'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
