import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:abari/services/prediction_service.dart';

/// Widget que muestra un gráfico de barras con las predicciones de ventas
/// para los próximos 30 días en córdobas
class PrediccionChart extends StatefulWidget {
  const PrediccionChart({super.key});

  @override
  State<PrediccionChart> createState() => _PrediccionChartState();
}

class _PrediccionChartState extends State<PrediccionChart> {
  bool cargando = true;
  String? error;
  PredictionResult? resultado;
  DateTime? ultimaActualizacion;

  @override
  void initState() {
    super.initState();
    cargarPredicciones();
  }

  Future<void> cargarPredicciones() async {
    setState(() {
      cargando = true;
      error = null;
    });

    try {
      final data = await PredictionService.obtenerPredicciones();
      if (mounted) {
        setState(() {
          resultado = data;
          ultimaActualizacion = data.esDesdeCache
              ? data.ultimaActualizacion
              : DateTime.now();
          cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          cargando = false;
        });
      }
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
          color: Colors.deepPurple.withValues(alpha: isDark ? 0.4 : 0.3),
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
                  Icons.analytics,
                  size: 24,
                  color: isDark
                      ? Colors.deepPurple[300]
                      : Colors.deepPurple[700],
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Predicción de Ventas',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                // Botón refrescar
                IconButton(
                  onPressed: cargando ? null : cargarPredicciones,
                  icon: cargando
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.deepPurple[400],
                          ),
                        )
                      : Icon(
                          Icons.refresh,
                          color: isDark
                              ? Colors.deepPurple[300]
                              : Colors.deepPurple[600],
                        ),
                  tooltip: 'Actualizar predicción',
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Subtítulo con última actualización
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Próximos 30 días (en córdobas)',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
                if (ultimaActualizacion != null) ...[
                  if (resultado?.esDesdeCache == true)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_off,
                            size: 12,
                            color: Colors.orange[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Caché',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    _formatearUltimaActualizacion(ultimaActualizacion!),
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Contenido
            if (cargando)
              const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error != null)
              _buildError(isDark)
            else if (resultado != null)
              _buildContent(isDark)
            else
              const SizedBox(
                height: 200,
                child: Center(child: Text('Sin datos disponibles')),
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
          TextButton(
            onPressed: cargarPredicciones,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    final predictions = resultado!.predictions;

    return Column(
      children: [
        // Tarjetas de resumen
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Próxima semana',
                'C\$${_formatNumber(resultado!.totalSemana)}',
                Icons.date_range,
                Colors.orange,
                isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Próximos 30 días',
                'C\$${_formatNumber(resultado!.total30Dias)}',
                Icons.calendar_month,
                Colors.deepPurple,
                isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Gráfico de barras
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: _getMaxY(predictions),
              minY: _getMinY(predictions),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final point = predictions[group.x.toInt()];
                    return BarTooltipItem(
                      '${point.fechaCorta}\nC\$${_formatNumber(point.yhat)}',
                      TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
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
                      // Mostrar cada 5 días para no saturar
                      if (index % 5 != 0 || index >= predictions.length) {
                        return const SizedBox.shrink();
                      }
                      final point = predictions[index];
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          point.fechaCorta,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      );
                    },
                    reservedSize: 30,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 50,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        _formatShortNumber(value),
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
                horizontalInterval: _getInterval(predictions),
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey.withValues(alpha: 0.2),
                    strokeWidth: 1,
                  );
                },
              ),
              borderData: FlBorderData(show: false),
              barGroups: _buildBarGroups(predictions, isDark),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Leyenda mejorada
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.grey.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.grey.withValues(alpha: isDark ? 0.2 : 0.15),
            ),
          ),
          child: Column(
            children: [
              Text(
                'Leyenda del gráfico',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[isDark ? 400 : 600],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildLegendItem(
                    'Ganancia esperada',
                    'Días con ventas proyectadas',
                    Icons.trending_up,
                    Colors.green,
                    isDark,
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey.withValues(alpha: 0.3),
                  ),
                  /*_buildLegendItem(
                    'Pérdida esperada',
                    'Días con déficit proyectado',
                    Icons.trending_down,
                    Colors.red,
                    isDark,
                  )*/
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String titulo,
    String valor,
    IconData icono,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.3 : 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: color, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            valor,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? _getLighterColor(color) : _getDarkerColor(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(
    String label,
    String descripcion,
    IconData icono,
    Color color,
    bool isDark,
  ) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.25 : 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icono,
              color: isDark ? _getLighterColor(color) : color,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
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
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups(
    List<PredictionPoint> predictions,
    bool isDark,
  ) {
    return predictions.asMap().entries.map((entry) {
      final index = entry.key;
      final point = entry.value;
      final isPositive = point.yhat >= 0;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: point.yhat,
            color: isPositive
                ? Colors.green.withValues(alpha: 0.7)
                : Colors.red.withValues(alpha: 0.7),
            width: 8,
            borderRadius: BorderRadius.vertical(
              top: isPositive ? const Radius.circular(4) : Radius.zero,
              bottom: isPositive ? Radius.zero : const Radius.circular(4),
            ),
          ),
        ],
      );
    }).toList();
  }

  double _getMaxY(List<PredictionPoint> predictions) {
    if (predictions.isEmpty) return 100;
    final max = predictions.map((p) => p.yhat).reduce((a, b) => a > b ? a : b);
    return max * 1.1; // 10% de margen
  }

  double _getMinY(List<PredictionPoint> predictions) {
    if (predictions.isEmpty) return 0;
    final min = predictions.map((p) => p.yhat).reduce((a, b) => a < b ? a : b);
    if (min >= 0) return 0;
    return min * 1.1; // 10% de margen para negativos
  }

  double _getInterval(List<PredictionPoint> predictions) {
    final range = _getMaxY(predictions) - _getMinY(predictions);
    if (range <= 0) return 1000;
    return (range / 5).roundToDouble();
  }

  String _formatNumber(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }

  String _formatShortNumber(double value) {
    if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toStringAsFixed(0);
  }

  Color _getLighterColor(Color color) {
    return Color.lerp(color, Colors.white, 0.3)!;
  }

  Color _getDarkerColor(Color color) {
    return Color.lerp(color, Colors.black, 0.2)!;
  }

  String _formatearUltimaActualizacion(DateTime fecha) {
    final ahora = DateTime.now();
    final diferencia = ahora.difference(fecha);

    if (diferencia.inMinutes < 1) {
      return 'Actualizado hace un momento';
    } else if (diferencia.inMinutes < 60) {
      return 'Actualizado hace ${diferencia.inMinutes} min';
    } else if (diferencia.inHours < 24) {
      return 'Actualizado hace ${diferencia.inHours}h';
    } else if (diferencia.inDays == 1) {
      return 'Actualizado ayer ${_formatHora(fecha)}';
    } else if (diferencia.inDays < 7) {
      return 'Actualizado hace ${diferencia.inDays} días';
    } else {
      return 'Actualizado ${_formatFechaCompleta(fecha)}';
    }
  }

  String _formatHora(DateTime fecha) {
    return '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
  }

  String _formatFechaCompleta(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')} ${_formatHora(fecha)}';
  }
}
