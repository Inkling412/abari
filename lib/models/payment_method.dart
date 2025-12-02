class PaymentMethod {
  final int id;
  final String name;
  final String? provider;
  final DateTime createdAt;

  PaymentMethod({
    required this.id,
    required this.name,
    this.provider,
    required this.createdAt,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id'] as int,
      name: json['name'] as String,
      provider: json['provider'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'provider': provider,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
