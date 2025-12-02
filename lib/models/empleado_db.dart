class EmpleadoDB {
  final int idEmpleado;
  final String nombreEmpleado;
  final int idCargo;
  final String? telefono;
  final String? cargoNombre;

  EmpleadoDB({
    required this.idEmpleado,
    required this.nombreEmpleado,
    required this.idCargo,
    this.telefono,
    this.cargoNombre,
  });

  factory EmpleadoDB.fromJson(Map<String, dynamic> json) {
    String? cargo;
    if (json['cargo_empleado'] != null) {
      if (json['cargo_empleado'] is Map) {
        cargo = json['cargo_empleado']['cargo'] as String?;
      }
    }
    
    return EmpleadoDB(
      idEmpleado: json['id_empleado'] as int,
      nombreEmpleado: json['nombre_empleado'] as String,
      idCargo: json['id_cargo'] as int,
      telefono: json['telefono'] as String?,
      cargoNombre: cargo,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_empleado': idEmpleado,
      'nombre_empleado': nombreEmpleado,
      'id_cargo': idCargo,
      'telefono': telefono,
    };
  }
}
