import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionProvider extends ChangeNotifier {
  int? _empleadoId;
  String _empleadoNombre;

  static const String _empleadoIdKey = 'session_empleado_id';
  static const String _empleadoNombreKey = 'session_empleado_nombre';

  // Constructor que recibe valores iniciales (cargados antes de iniciar la app)
  SessionProvider({int? empleadoId, String empleadoNombre = ''})
    : _empleadoId = empleadoId,
      _empleadoNombre = empleadoNombre;

  int? get empleadoId => _empleadoId;
  String get empleadoNombre => _empleadoNombre;
  bool get hasSession => _empleadoId != null && _empleadoNombre.isNotEmpty;

  // Método estático para cargar sesión guardada antes de crear el provider
  static Future<Map<String, dynamic>> loadSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final result = {
      'empleadoId': prefs.getInt(_empleadoIdKey),
      'empleadoNombre': prefs.getString(_empleadoNombreKey) ?? '',
    };
    debugPrint('👤 SessionProvider.loadSavedSession: $result');
    return result;
  }

  // Guardar sesión
  Future<void> setEmpleado(int id, String nombre) async {
    _empleadoId = id;
    _empleadoNombre = nombre;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_empleadoIdKey, id);
    await prefs.setString(_empleadoNombreKey, nombre);
    debugPrint(
      '👤 SessionProvider.setEmpleado: id=$id, nombre=$nombre guardado',
    );

    notifyListeners();
  }

  // Cerrar sesión
  Future<void> clearSession() async {
    _empleadoId = null;
    _empleadoNombre = '';

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_empleadoIdKey);
    await prefs.remove(_empleadoNombreKey);

    notifyListeners();
  }
}
