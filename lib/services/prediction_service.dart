import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio para obtener predicciones desde Supabase Edge Function
class PredictionService {
  static final _client = Supabase.instance.client;

  // Claves para SharedPreferences
  static const String _cacheKey = 'prediction_cache';
  static const String _lastUpdateKey = 'prediction_last_update';

  /// Llama a la edge function 'get-predict' y retorna el resultado
  /// Si falla, intenta cargar datos desde caché
  static Future<PredictionResult> obtenerPredicciones() async {
    try {
      final response = await _client.functions.invoke(
        'get-predict',
        method: HttpMethod.post,
        body: {'name': 'predict'}, // Body requerido por la edge function
      );

      if (response.status != 200) {
        throw Exception('Error ${response.status}: ${response.data}');
      }

      final data = response.data as Map<String, dynamic>;

      if (data['status'] != 'success') {
        throw Exception(data['error'] ?? 'Error desconocido');
      }

      final result = PredictionResult.fromJson(data);

      // Guardar en caché
      await _guardarEnCache(data);

      return result;
    } catch (e) {
      // Intentar cargar desde caché si hay error
      final cached = await _cargarDesdeCache();
      if (cached != null) {
        return cached;
      }
      throw Exception('Error al obtener predicciones: $e');
    }
  }

  /// Guarda los datos de predicción en SharedPreferences
  static Future<void> _guardarEnCache(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(data));
      await prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());
    } catch (e) {
      // Ignorar errores de caché
    }
  }

  /// Carga los datos de predicción desde SharedPreferences
  static Future<PredictionResult?> _cargarDesdeCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        final data = jsonDecode(cached) as Map<String, dynamic>;
        final result = PredictionResult.fromJson(data);
        result.esDesdeCache = true;
        result.ultimaActualizacion = await obtenerUltimaActualizacion();
        return result;
      }
    } catch (e) {
      // Ignorar errores de caché
    }
    return null;
  }

  /// Obtiene la fecha de última actualización desde SharedPreferences
  static Future<DateTime?> obtenerUltimaActualizacion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdate = prefs.getString(_lastUpdateKey);
      if (lastUpdate != null) {
        return DateTime.parse(lastUpdate);
      }
    } catch (e) {
      // Ignorar errores
    }
    return null;
  }

  /// Verifica si hay datos en caché disponibles
  static Future<bool> hayCacheDisponible() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_cacheKey);
    } catch (e) {
      return false;
    }
  }

  /// Limpia el caché de predicciones
  static Future<void> limpiarCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_lastUpdateKey);
    } catch (e) {
      // Ignorar errores
    }
  }
}

/// Resultado de predicción desde la edge function
class PredictionResult {
  final List<PredictionPoint> predictions;
  final int periods;

  /// Indica si los datos fueron cargados desde caché
  bool esDesdeCache = false;

  /// Fecha y hora de la última actualización exitosa
  DateTime? ultimaActualizacion;

  PredictionResult({required this.predictions, required this.periods});

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    final predictions = (json['predictions'] as List? ?? [])
        .map((p) => PredictionPoint.fromJson(p as Map<String, dynamic>))
        .toList();

    return PredictionResult(
      predictions: predictions,
      periods: json['periods'] as int? ?? 30,
    );
  }

  /// Total predicho para los próximos 7 días
  double get totalSemana {
    final semana = predictions.take(7);
    return semana.fold(0.0, (sum, p) => sum + (p.yhat > 0 ? p.yhat : 0));
  }

  /// Total predicho para los 30 días
  double get total30Dias {
    return predictions.fold(0.0, (sum, p) => sum + (p.yhat > 0 ? p.yhat : 0));
  }

  /// Promedio diario predicho
  double get promedioDiario {
    if (predictions.isEmpty) return 0;
    return total30Dias / predictions.length;
  }
}

/// Punto de predicción individual
class PredictionPoint {
  final DateTime fecha;
  final double yhat;
  final double yhatLower;
  final double yhatUpper;

  PredictionPoint({
    required this.fecha,
    required this.yhat,
    required this.yhatLower,
    required this.yhatUpper,
  });

  factory PredictionPoint.fromJson(Map<String, dynamic> json) {
    return PredictionPoint(
      fecha: DateTime.parse(json['ds'] as String),
      yhat: (json['yhat'] as num).toDouble(),
      yhatLower: (json['yhat_lower'] as num?)?.toDouble() ?? 0,
      yhatUpper: (json['yhat_upper'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Día de la semana abreviado
  String get diaSemana {
    const dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return dias[fecha.weekday - 1];
  }

  /// Fecha formateada corta (dd/MM)
  String get fechaCorta {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}';
  }
}
