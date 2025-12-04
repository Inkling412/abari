import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:abari/widgets/prediccion_chart.dart';
import 'package:abari/widgets/prediccion_demanda_chart.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool cargando = true;
  bool entrenandoModelo = false;

  // Estadísticas
  int totalProductos = 0;
  int productosProximosVencer = 0;
  int productosStockBajo = 0;
  double ventasHoy = 0.0;
  double ventasMes = 0.0;
  double comprasMes = 0.0;
  int totalClientes = 0;
  int totalProveedores = 0;

  // Para gráficas
  double totalGanancias = 0.0;
  double totalGastos = 0.0;

  @override
  void initState() {
    super.initState();
    cargarEstadisticas();
  }

  Future<void> cargarEstadisticas() async {
    setState(() => cargando = true);

    try {
      final ahora = DateTime.now();
      final hoyStr = _formatDate(ahora);
      final inicioMesDate = DateTime(ahora.year, ahora.month, 1);
      final inicioMes = _formatDate(inicioMesDate);

      // ✅ OPTIMIZACIÓN: Ejecutar todas las consultas en paralelo
      final results = await Future.wait([
        // 0: Productos disponibles (con presentación y cantidad para calcular stock)
        Supabase.instance.client
            .from('producto')
            .select(
              'id_producto, codigo, fecha_vencimiento, cantidad, presentacion(descripcion)',
            )
            .eq('estado', 'Disponible'),
        // 1: Ventas del mes (incluye hoy)
        Supabase.instance.client
            .from('venta')
            .select('id_venta, total, fecha')
            .gte('fecha', inicioMes),
        // 2: Compras del mes
        Supabase.instance.client
            .from('compra')
            .select('total')
            .gte('fecha', inicioMes),
        // 3: Total clientes
        Supabase.instance.client.from('cliente').select('id_cliente'),
        // 4: Total proveedores
        Supabase.instance.client.from('proveedor').select('id_proveedor'),
        // 5: Productos en ventas del mes (para calcular costos) - UNA sola consulta
        Supabase.instance.client
            .from('producto_en_venta')
            .select('id_venta, precio_historico, costo_historico')
            .gte('id_venta', 0), // Traer todos, filtraremos en memoria
      ]);

      final productosResponse = results[0] as List;
      final ventasMesResponse = results[1] as List;
      final comprasMesResponse = results[2] as List;
      final clientesResponse = results[3] as List;
      final proveedoresResponse = results[4] as List;
      final productosEnVentaResponse = results[5] as List;

      // Procesar productos
      totalProductos = productosResponse.length;
      final en30Dias = ahora.add(const Duration(days: 30));
      productosProximosVencer = productosResponse.where((p) {
        final fechaVenc = p['fecha_vencimiento'] as String?;
        if (fechaVenc == null) return false;
        final fecha = DateTime.parse(fechaVenc);
        return fecha.isAfter(ahora) && fecha.isBefore(en30Dias);
      }).length;

      // Stock bajo - agrupar por código y considerar si es a granel
      final stockPorCodigo = <String, double>{};
      final esGranelPorCodigo = <String, bool>{};

      for (final p in productosResponse) {
        final codigo = p['codigo']?.toString() ?? p['id_producto'].toString();
        final presentacion = p['presentacion'] as Map<String, dynamic>?;
        final descripcionPres =
            presentacion?['descripcion']?.toString().toLowerCase() ?? '';
        final esGranel = descripcionPres == 'a granel';

        esGranelPorCodigo[codigo] = esGranel;

        if (esGranel) {
          // Para productos a granel: stock = cantidad del producto
          final cantidad = (p['cantidad'] as num?)?.toDouble() ?? 0;
          // Solo contar una vez por código (el primero que encuentre)
          if (!stockPorCodigo.containsKey(codigo)) {
            stockPorCodigo[codigo] = cantidad;
          }
        } else {
          // Para otros productos: stock = cantidad de registros
          stockPorCodigo[codigo] = (stockPorCodigo[codigo] ?? 0) + 1;
        }
      }

      productosStockBajo = stockPorCodigo.values.where((s) => s < 5).length;

      // Procesar ventas - filtrar hoy y calcular totales
      ventasHoy = 0.0;
      ventasMes = 0.0;
      final ventasIds = <int>{};

      for (var v in ventasMesResponse) {
        final total = (v['total'] as num?)?.toDouble() ?? 0.0;
        ventasMes += total;
        if (v['fecha'] == hoyStr) ventasHoy += total;
        ventasIds.add(v['id_venta'] as int);
      }

      // Compras del mes
      comprasMes = comprasMesResponse.fold<double>(
        0.0,
        (sum, c) => sum + ((c['total'] as num?)?.toDouble() ?? 0.0),
      );

      // Contadores
      totalClientes = clientesResponse.length;
      totalProveedores = proveedoresResponse.length;

      // ✅ Calcular costos usando costo_historico de producto_en_venta
      double totalCostos = 0.0;
      for (var pv in productosEnVentaResponse) {
        final idVenta = pv['id_venta'] as int?;
        if (idVenta != null && ventasIds.contains(idVenta)) {
          totalCostos += (pv['costo_historico'] as num?)?.toDouble() ?? 0.0;
        }
      }

      totalGanancias = ventasMes - totalCostos;
      totalGastos = comprasMes + totalCostos;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar estadísticas: $e')),
        );
      }
    }

    setState(() => cargando = false);
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _entrenarModelo() async {
    setState(() => entrenandoModelo = true);

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'reinforce-model',
        body: {},
      );

      if (mounted) {
        if (response.status == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Modelo entrenado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al entrenar modelo: ${response.data}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al entrenar modelo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => entrenandoModelo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: cargarEstadisticas,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado
            Row(
              children: [
                Icon(Icons.home, size: 32, color: Colors.blue[700]),
                const SizedBox(width: 12),
                const Text(
                  'Inicio',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Text(
              'Bienvenido al Dashboard',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 24),

            // Sección de Inventario
            _buildSeccionTitulo('Inventario', Icons.inventory_2),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildCardEstadistica(
                    'Total Productos',
                    totalProductos.toString(),
                    Icons.inventory,
                    Colors.blue,
                    isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCardEstadistica(
                    'Próximos a Vencer',
                    productosProximosVencer.toString(),
                    Icons.warning,
                    Colors.orange,
                    isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildCardEstadistica(
              'Stock Bajo (< 5 unidades)',
              productosStockBajo.toString(),
              Icons.trending_down,
              Colors.red,
              isDark,
              fullWidth: true,
            ),

            const SizedBox(height: 24),

            // Sección de Predicción de Ventas
            const PrediccionChart(),

            const SizedBox(height: 16),

            // Botón para entrenar modelo
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: entrenandoModelo ? null : _entrenarModelo,
                icon: entrenandoModelo
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.model_training),
                label: Text(
                  entrenandoModelo ? 'Entrenando...' : 'Entrenar Modelo',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Sección de Predicción de Demanda de Productos
            const PrediccionDemandaChart(),

            const SizedBox(height: 24),

            // Sección de Ventas
            _buildSeccionTitulo('Ventas', Icons.point_of_sale),
            const SizedBox(height: 12),
            _buildCardEstadistica(
              'Ventas Hoy',
              'C\$${ventasHoy.toStringAsFixed(2)}',
              Icons.today,
              Colors.green,
              isDark,
              fullWidth: true,
            ),
            const SizedBox(height: 12),
            _buildCardEstadistica(
              'Ventas del Mes',
              'C\$${ventasMes.toStringAsFixed(2)}',
              Icons.calendar_month,
              Colors.teal,
              isDark,
              fullWidth: true,
            ),

            const SizedBox(height: 24),

            // Sección de Compras
            _buildSeccionTitulo('Compras', Icons.shopping_cart),
            const SizedBox(height: 12),
            _buildCardEstadistica(
              'Compras del Mes',
              'C\$${comprasMes.toStringAsFixed(2)}',
              Icons.attach_money,
              Colors.purple,
              isDark,
              fullWidth: true,
            ),

            const SizedBox(height: 24),

            // Sección de Contactos
            _buildSeccionTitulo('Contactos', Icons.people),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildCardEstadistica(
                    'Clientes',
                    totalClientes.toString(),
                    Icons.person,
                    Colors.indigo,
                    isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCardEstadistica(
                    'Proveedores',
                    totalProveedores.toString(),
                    Icons.business,
                    Colors.cyan,
                    isDark,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Sección de Rentabilidad (Pie Chart)
            _buildSeccionTitulo('Rentabilidad del Negocio', Icons.pie_chart),
            const SizedBox(height: 12),
            _buildPieChart(isDark),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionTitulo(String titulo, IconData icono) {
    return Row(
      children: [
        Icon(icono, size: 24, color: Colors.grey[700]),
        const SizedBox(width: 8),
        Text(
          titulo,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildCardEstadistica(
    String titulo,
    String valor,
    IconData icono,
    Color color,
    bool isDark, {
    bool fullWidth = false,
  }) {
    // Colores adaptados para cada modo
    final bgColor = isDark
        ? const Color(0xFF1E1E1E) // Fondo oscuro elegante
        : Colors.white;
    final iconColor = isDark
        ? _getLighterColor(color) // Color más brillante en oscuro
        : color.withValues(alpha: 0.8);
    final textColor = isDark ? Colors.white70 : const Color(0xFF333333);
    final valueColor = isDark
        ? _getLighterColor(color) // Valores brillantes en oscuro
        : _getDarkerColor(color);
    final borderColor = isDark
        ? color.withValues(alpha: 0.4) // Borde visible en oscuro
        : color.withValues(alpha: 0.3);
    final shadowColor = color.withValues(alpha: isDark ? 0.2 : 0.3);

    return Card(
      elevation: 3,
      color: bgColor,
      shadowColor: shadowColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icono, color: iconColor, size: 28),
                ),
                if (!fullWidth)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: isDark ? 0.3 : 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      valor,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: valueColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            if (fullWidth) ...[
              const SizedBox(height: 8),
              Text(
                valor,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Obtener color más oscuro para mejor contraste en modo claro
  Color _getDarkerColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness * 0.6).clamp(0.0, 1.0)).toColor();
  }

  // Obtener color más brillante para mejor visibilidad en modo oscuro
  Color _getLighterColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness * 1.3).clamp(0.0, 0.85))
        .withSaturation((hsl.saturation * 1.1).clamp(0.0, 1.0))
        .toColor();
  }

  Widget _buildPieChart(bool isDark) {
    final total = totalGanancias + totalGastos;
    final porcentajeGanancias = total > 0
        ? (totalGanancias / total) * 100
        : 0.0;
    final porcentajeGastos = total > 0 ? (totalGastos / total) * 100 : 0.0;

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 350;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ventas vs Gastos',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (total == 0)
                  const SizedBox(
                    height: 200,
                    child: Center(child: Text('No hay datos disponibles')),
                  )
                else if (isMobile) ...[
                  // Layout vertical para mobile
                  SizedBox(
                    height: 180,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: [
                          PieChartSectionData(
                            value: totalGanancias,
                            title: '${porcentajeGanancias.toStringAsFixed(0)}%',
                            color: Colors.green,
                            radius: 50,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          PieChartSectionData(
                            value: totalGastos,
                            title: '${porcentajeGastos.toStringAsFixed(0)}%',
                            color: Colors.red,
                            radius: 50,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Leyenda compacta
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildLeyendaCompacta(
                        'Ventas',
                        Colors.green,
                        totalGanancias,
                      ),
                      _buildLeyendaCompacta('Gastos', Colors.red, totalGastos),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Total: C\$${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ] else ...[
                  // Layout horizontal para tablet/desktop
                  SizedBox(
                    height: 200,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                              sections: [
                                PieChartSectionData(
                                  value: totalGanancias,
                                  title:
                                      '${porcentajeGanancias.toStringAsFixed(1)}%',
                                  color: Colors.green,
                                  radius: 60,
                                  titleStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                PieChartSectionData(
                                  value: totalGastos,
                                  title:
                                      '${porcentajeGastos.toStringAsFixed(1)}%',
                                  color: Colors.red,
                                  radius: 60,
                                  titleStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLeyendaItem(
                                'Ventas',
                                Colors.green,
                                totalGanancias,
                              ),
                              const SizedBox(height: 8),
                              _buildLeyendaItem(
                                'Gastos',
                                Colors.red,
                                totalGastos,
                              ),
                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 4),
                              Text(
                                'Total: C\$${total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  totalGanancias > totalGastos
                      ? '✅ El negocio es rentable este mes'
                      : '⚠️ Aun no se recupera la inversion de este mes',
                  style: TextStyle(
                    fontSize: 12,
                    color: totalGanancias > totalGastos
                        ? Colors.green
                        : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLeyendaCompacta(String label, Color color, double valor) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
        ),
        Text(
          'C\$${valor.toStringAsFixed(0)}',
          style: const TextStyle(fontSize: 9, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildLeyendaItem(String label, Color color, double valor) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'C\$${valor.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
