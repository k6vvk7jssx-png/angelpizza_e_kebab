import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';
import '../services/notification_manager.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final OrderService _orderService = OrderService();
  final NotificationManager _notificationManager = NotificationManager();
  
  List<OrderModel> _orders = [];
  OrderModel? _selectedOrder;
  bool _isLoading = true;
  String? _errorMessage;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _setupRealtimeListener();
  }

  // Load orders from Supabase initially
  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      final orders = await _orderService.fetchOrders();
      setState(() {
        _orders = orders;
        if (_orders.isNotEmpty) {
          _selectedOrder = _orders.first;
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Errore nel caricamento degli ordini: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Listen to Supabase Postgres changes for real-time notifications
  void _setupRealtimeListener() {
    _realtimeChannel = _orderService.subscribeToOrders(
      onNewOrder: (order) {
        setState(() {
          // Avoid duplicate inserts
          if (!_orders.any((o) => o.id == order.id)) {
            _orders.insert(0, order);
            _selectedOrder = order; // Auto-select new order
          }
        });
        
        // Trigger sound alarm and OS system popup notification
        _notificationManager.playOrderAlarm();
        _notificationManager.triggerNewOrderNotification(
          orderId: order.id,
          guestName: order.guestName,
          totalPrice: order.totalPrice,
          deliveryType: order.deliveryType,
        );
      },
      onOrderUpdated: (id, status) {
        setState(() {
          final index = _orders.indexWhere((o) => o.id == id);
          if (index != -1) {
            // Update status of matching order
            final updatedOrder = OrderModel(
              id: _orders[index].id,
              guestName: _orders[index].guestName,
              guestPhone: _orders[index].guestPhone,
              guestAddress: _orders[index].guestAddress,
              deliveryType: _orders[index].deliveryType,
              status: status,
              requestedTime: _orders[index].requestedTime,
              totalPrice: _orders[index].totalPrice,
              notes: _orders[index].notes,
              createdAt: _orders[index].createdAt,
              items: _orders[index].items,
            );
            _orders[index] = updatedOrder;
            if (_selectedOrder?.id == id) {
              _selectedOrder = updatedOrder;
            }
          }
        });
      },
    );
  }

  // Update status in database and locally
  Future<void> _updateStatus(String status) async {
    if (_selectedOrder == null) return;
    try {
      await _orderService.updateOrderStatus(_selectedOrder!.id, status);
      
      setState(() {
        final index = _orders.indexWhere((o) => o.id == _selectedOrder!.id);
        if (index != -1) {
          final updatedOrder = OrderModel(
            id: _orders[index].id,
            guestName: _orders[index].guestName,
            guestPhone: _orders[index].guestPhone,
            guestAddress: _orders[index].guestAddress,
            deliveryType: _orders[index].deliveryType,
            status: status,
            requestedTime: _orders[index].requestedTime,
            totalPrice: _orders[index].totalPrice,
            notes: _orders[index].notes,
            createdAt: _orders[index].createdAt,
            items: _orders[index].items,
          );
          _orders[index] = updatedOrder;
          _selectedOrder = updatedOrder;
        }
      });

      // If we accept/process the order, stop the alarm sound automatically
      if (status == 'accepted' || status == 'cancelled') {
        await _notificationManager.stopOrderAlarm();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante l\'aggiornamento: $e')),
      );
    }
  }

  // Update order requested time in database and locally
  Future<void> _updateOrderTime(int minutesDelta) async {
    if (_selectedOrder == null) return;
    try {
      final newTime = _selectedOrder!.requestedTime.add(Duration(minutes: minutesDelta));
      await _orderService.updateOrderTime(_selectedOrder!.id, newTime);
      
      setState(() {
        final index = _orders.indexWhere((o) => o.id == _selectedOrder!.id);
        if (index != -1) {
          final updatedOrder = OrderModel(
            id: _orders[index].id,
            guestName: _orders[index].guestName,
            guestPhone: _orders[index].guestPhone,
            guestAddress: _orders[index].guestAddress,
            deliveryType: _orders[index].deliveryType,
            status: _orders[index].status,
            requestedTime: newTime,
            totalPrice: _orders[index].totalPrice,
            notes: _orders[index].notes,
            createdAt: _orders[index].createdAt,
            items: _orders[index].items,
          );
          _orders[index] = updatedOrder;
          _selectedOrder = updatedOrder;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Orario aggiornato a ${_formatTime(newTime)}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante l\'aggiornamento dell\'orario: $e')),
      );
    }
  }

  // Format date helper
  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // Helper for status badge styling
  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.red.shade600;
      case 'accepted':
        return Colors.amber.shade700;
      case 'delivering':
        return Colors.blue.shade600;
      case 'completed':
        return Colors.green.shade600;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1917), // Charcoal Black background
      appBar: AppBar(
        backgroundColor: const Color(0xFFEA580C), // Warm Orange AppBar
        title: const Text(
          'ANGELS LIVORNO - RICEVITORE ORDINI',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadInitialData,
            tooltip: 'Ricarica Ordini',
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFACC15), // Gold Accent
              foregroundColor: Colors.black,
            ),
            icon: const Icon(Icons.volume_off),
            label: const Text('SILENZIA ALLARME', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => _notificationManager.stopOrderAlarm(),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _handleLogout,
            tooltip: 'Esci / Logout',
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFEA580C)))
          : _errorMessage != null
              ? Center(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                  ),
                )
              : Row(
                  children: [
                    // Left Column: Orders list panel
                    Expanded(
                      flex: 4,
                      child: Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(color: Colors.white12, width: 1),
                          ),
                        ),
                        child: _orders.isEmpty
                            ? const Center(
                                child: Text(
                                  'Nessun ordine presente',
                                  style: TextStyle(color: Colors.white60, fontSize: 16),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _orders.length,
                                itemBuilder: (context, index) {
                                  final order = _orders[index];
                                  final isSelected = _selectedOrder?.id == order.id;
                                  return Card(
                                    color: isSelected
                                        ? const Color(0xFFEA580C).withOpacity(0.15)
                                        : const Color(0xFF2E2A27),
                                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    shape: RoundedRectangleBorder(
                                      side: BorderSide(
                                        color: isSelected ? const Color(0xFFEA580C) : Colors.transparent,
                                        width: 1.5,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ListTile(
                                      onTap: () {
                                        setState(() {
                                          _selectedOrder = order;
                                        });
                                      },
                                      title: Text(
                                        order.guestName.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Ora: ${_formatTime(order.createdAt)} | €${order.totalPrice.toStringAsFixed(2)}',
                                        style: const TextStyle(color: Colors.white70),
                                      ),
                                      trailing: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(order.status),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          order.status.toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                    
                    // Right Column: Active selected order detail pane
                    Expanded(
                      flex: 6,
                      child: _selectedOrder == null
                          ? const Center(
                              child: Text(
                                'Seleziona un ordine per visualizzare i dettagli',
                                style: TextStyle(color: Colors.white60, fontSize: 16),
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Detail Header Card
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'DETTAGLI ORDINE',
                                        style: TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontWeight: FontWeight.w900,
                                          fontSize: 20,
                                          color: const Color(0xFFFACC15),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(_selectedOrder!.status),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.black26, width: 1),
                                        ),
                                        child: Text(
                                          _selectedOrder!.status.toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(color: Colors.white24, height: 24),
                                  
                                  // Customer data panel
                                  Text(
                                    'CLIENTE: ${_selectedOrder!.guestName.toUpperCase()}',
                                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'TELEFONO: ${_selectedOrder!.guestPhone}',
                                    style: const TextStyle(color: Colors.white, fontSize: 16),
                                  ),
                                  if (_selectedOrder!.guestAddress != null && _selectedOrder!.guestAddress!.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'INDIRIZZO: ${_selectedOrder!.guestAddress}',
                                      style: const TextStyle(color: Colors.white, fontSize: 16),
                                    ),
                                  ],
                                   Text(
                                    'TIPO RITIRO: ${_selectedOrder!.deliveryType == 'delivery' ? 'CONSEGNA A DOMICILIO' : 'ASPORTO'}',
                                    style: TextStyle(
                                      color: const Color(0xFFFACC15),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'ORARIO RICHIESTO: ${_formatTime(_selectedOrder!.requestedTime)}',
                                        style: const TextStyle(
                                          color: Color(0xFFFACC15),
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 28),
                                            tooltip: 'Anticipa 10 min',
                                            onPressed: () => _updateOrderTime(-10),
                                          ),
                                          const Text(
                                            'MODIFICA',
                                            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.add_circle_outline, color: Colors.green, size: 28),
                                            tooltip: 'Posticipa 10 min',
                                            onPressed: () => _updateOrderTime(10),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),

                                  // Ordered Items Title
                                  const Text(
                                    'ARTICOLI ORDINATI:',
                                    style: TextStyle(
                                      color: Color(0xFFFACC15),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Ordered Items List
                                  if (_selectedOrder!.items.isEmpty)
                                    const Text(
                                      'Nessun articolo trovato per questo ordine.',
                                      style: TextStyle(color: Colors.white60, fontStyle: FontStyle.italic),
                                    )
                                  else
                                    ..._selectedOrder!.items.map<Widget>((item) {
                                      final name = item['name'] ?? 'Piatto';
                                      final qty = item['qty'] ?? 1;
                                      final price = item['price_at_order'] ?? 0.0;
                                      
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${qty}x ${name}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              '€${(price * qty).toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  const SizedBox(height: 20),
                                  
                                  // Total and Notes Card
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2E2A27),
                                      border: Border.all(color: Colors.white12, width: 1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'TOTALE ORDINE: €${_selectedOrder!.totalPrice.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        if (_selectedOrder!.notes != null && _selectedOrder!.notes!.isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          Text(
                                            'NOTE CLIENTE: ${_selectedOrder!.notes}',
                                            style: const TextStyle(
                                              color: Colors.redAccent,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  
                                  // Bottom Kitchen Action buttons
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (_selectedOrder!.status == 'pending') ...[
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          onPressed: () => _updateStatus('accepted'),
                                          child: const Text('ACCETTA ORDINE'),
                                        ),
                                      ] else if (_selectedOrder!.status == 'accepted') ...[
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          onPressed: () => _updateStatus('delivering'),
                                          child: const Text('IN CONSEGNA'),
                                        ),
                                      ] else if (_selectedOrder!.status == 'delivering') ...[
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.purple,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          onPressed: () => _updateStatus('completed'),
                                          child: const Text('CONSEGNA COMPLETATA'),
                                        ),
                                      ],
                                      const SizedBox(width: 12),
                                      if (_selectedOrder!.status != 'completed' && _selectedOrder!.status != 'cancelled')
                                        TextButton(
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.red,
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          ),
                                          onPressed: () => _updateStatus('cancelled'),
                                          child: const Text('ANNULLA ORDINE'),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  Future<void> _handleLogout() async {
    await _notificationManager.stopOrderAlarm();
    
    if (_realtimeChannel != null) {
      await _orderService.unsubscribe(_realtimeChannel!);
    }
    
    await Supabase.instance.client.auth.signOut();
    
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      _orderService.unsubscribe(_realtimeChannel!);
    }
    _notificationManager.dispose();
    super.dispose();
  }
}
