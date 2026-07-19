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
  final List<dynamic> items;

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
    required this.items,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final deliveryAddress = json['delivery_address'] as String?;
    final deducedDeliveryType = (deliveryAddress != null && deliveryAddress.isNotEmpty)
        ? 'delivery'
        : 'pickup';

    final rawItems = json['items'] as List<dynamic>? ?? [];

    return OrderModel(
      id: json['id'] as String? ?? '',
      guestName: json['guest_name'] as String? ?? 'Ospite',
      guestPhone: json['guest_phone'] as String? ?? '',
      guestAddress: deliveryAddress,
      deliveryType: deducedDeliveryType,
      status: json['status'] as String? ?? 'pending',
      requestedTime: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
      totalPrice: json['total_amount'] != null
          ? (json['total_amount'] as num).toDouble()
          : 0.0,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
      items: rawItems,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'guest_name': guestName,
      'guest_phone': guestPhone,
      'delivery_address': guestAddress,
      'delivery_type': deliveryType,
      'status': status,
      'requested_time': requestedTime.toIso8601String(),
      'total_price': totalPrice,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'items': items,
    };
  }
}
