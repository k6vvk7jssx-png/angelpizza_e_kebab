import 'package:flutter_test/flutter_test.dart';
import 'package:manager_app/models/order_model.dart';

void main() {
  group('OrderModel Tests', () {
    test('fromJson parses correct fields successfully', () {
      final json = {
        'id': 'd290f1ee-6c54-4b01-90e6-d701748f0851',
        'guest_name': 'Mario Rossi',
        'guest_phone': '3331234567',
        'guest_address': 'Via Roma 10, Livorno',
        'delivery_type': 'delivery',
        'status': 'pending',
        'requested_time': '2026-07-19T20:30:00.000Z',
        'total_price': 15.50,
        'notes': 'Citofono Rossi',
        'created_at': '2026-07-19T12:00:00.000Z',
      };

      final order = OrderModel.fromJson(json);

      expect(order.id, 'd290f1ee-6c54-4b01-90e6-d701748f0851');
      expect(order.guestName, 'Mario Rossi');
      expect(order.guestPhone, '3331234567');
      expect(order.guestAddress, 'Via Roma 10, Livorno');
      expect(order.deliveryType, 'delivery');
      expect(order.status, 'pending');
      expect(order.requestedTime, DateTime.parse('2026-07-19T20:30:00.000Z'));
      expect(order.totalPrice, 15.50);
      expect(order.notes, 'Citofono Rossi');
      expect(order.createdAt, DateTime.parse('2026-07-19T12:00:00.000Z'));
    });

    test('toJson generates correct keys and values', () {
      final order = OrderModel(
        id: 'd290f1ee-6c54-4b01-90e6-d701748f0851',
        guestName: 'Luigi Verdi',
        guestPhone: '3337654321',
        guestAddress: 'Via Grande 50, Livorno',
        deliveryType: 'pickup',
        status: 'accepted',
        requestedTime: DateTime.parse('2026-07-19T21:00:00.000Z'),
        totalPrice: 8.50,
        notes: null,
        createdAt: DateTime.parse('2026-07-19T12:05:00.000Z'),
      );

      final json = order.toJson();

      expect(json['id'], 'd290f1ee-6c54-4b01-90e6-d701748f0851');
      expect(json['guest_name'], 'Luigi Verdi');
      expect(json['guest_phone'], '3337654321');
      expect(json['guest_address'], 'Via Grande 50, Livorno');
      expect(json['delivery_type'], 'pickup');
      expect(json['status'], 'accepted');
      expect(json['requested_time'], '2026-07-19T21:00:00.000Z');
      expect(json['total_price'], 8.50);
      expect(json['notes'], null);
      expect(json['created_at'], '2026-07-19T12:05:00.000Z');
    });
  });
}
