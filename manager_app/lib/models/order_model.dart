class OrderModel {
  final String id;
  final String guestName;
  final String guestPhone;
  final String? guestAddress;
  final String deliveryType;
  final String status;
  final DateTime requestedTime;
  final double totalPrice;
  final String? notes;
  final DateTime createdAt;

  OrderModel({
    required this.id,
    required this.guestName,
    required this.guestPhone,
    this.guestAddress,
    required this.deliveryType,
    required this.status,
    required this.requestedTime,
    required this.totalPrice,
    this.notes,
    required this.createdAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as String,
      guestName: json['guest_name'] as String,
      guestPhone: json['guest_phone'] as String,
      guestAddress: json['guest_address'] as String?,
      deliveryType: json['delivery_type'] as String,
      status: json['status'] as String,
      requestedTime: DateTime.parse(json['requested_time'] as String),
      totalPrice: (json['total_price'] as num).toDouble(),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'guest_name': guestName,
      'guest_phone': guestPhone,
      'guest_address': guestAddress,
      'delivery_type': deliveryType,
      'status': status,
      'requested_time': requestedTime.toIso8601String(),
      'total_price': totalPrice,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
