import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order_model.dart';

class OrderService {
  final SupabaseClient _client;

  OrderService([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  // Fetch initial list of orders, sorted by created_at descending
  Future<List<OrderModel>> fetchOrders() async {
    final response = await _client
        .from('orders')
        .select()
        .order('created_at', ascending: false);
    
    final List<dynamic> data = response as List<dynamic>;
    return data.map((json) => OrderModel.fromJson(json as Map<String, dynamic>)).toList();
  }

  // Update status of a specific order
  Future<void> updateOrderStatus(String orderId, String status) async {
    await _client
        .from('orders')
        .update({'status': status})
        .eq('id', orderId);
  }

  // Update requested time of a specific order
  Future<void> updateOrderTime(String orderId, DateTime newTime) async {
    await _client
        .from('orders')
        .update({'requested_time': newTime.toIso8601String()})
        .eq('id', orderId);
  }

  // Subscribe to real-time insertions on the orders table
  RealtimeChannel subscribeToOrders({
    required void Function(OrderModel order) onNewOrder,
    required void Function(String id, String status) onOrderUpdated,
  }) {
    final channel = _client.channel('public:orders');
    
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'orders',
      callback: (payload) {
        final newRecord = payload.newRecord;
        if (newRecord.isNotEmpty) {
          final order = OrderModel.fromJson(newRecord);
          onNewOrder(order);
        }
      },
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'orders',
      callback: (payload) {
        final newRecord = payload.newRecord;
        if (newRecord.isNotEmpty) {
          final id = newRecord['id'] as String;
          final status = newRecord['status'] as String;
          onOrderUpdated(id, status);
        }
      },
    );

    channel.subscribe();
    return channel;
  }

  // Unsubscribe from a channel
  Future<void> unsubscribe(RealtimeChannel channel) async {
    await _client.removeChannel(channel);
  }
}
