class Cliente {
  final int idCliente;
  final String nombreCliente;
  final String? numeroTelefono;

  Cliente({
    required this.idCliente,
    required this.nombreCliente,
    this.numeroTelefono,
  });

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      idCliente: json['id_cliente'] as int,
      nombreCliente: json['nombre_cliente'] as String,
      numeroTelefono: json['numero_telefono'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_cliente': idCliente,
      'nombre_cliente': nombreCliente,
      'numero_telefono': numeroTelefono,
    };
  }
}
