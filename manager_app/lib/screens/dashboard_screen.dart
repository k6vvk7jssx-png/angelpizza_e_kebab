import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';
import '../services/notification_manager.dart';
import 'login_screen.dart';

enum DashboardTab {
  kitchen,  // active daily orders
  archive,  // historic list of days
  balance,  // performance chart & metrics
}

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

  // Selected tab
  DashboardTab _currentTab = DashboardTab.kitchen;

  // Archive view selections
  String? _selectedArchiveDay;
  OrderModel? _selectedArchiveOrder;

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
        
        // Setup initial selected order for active kitchen view
        final activeOrders = getActiveKitchenOrders();
        if (activeOrders.isNotEmpty) {
          _selectedOrder = activeOrders.first;
        } else if (_orders.isNotEmpty) {
          _selectedOrder = _orders.first;
        }
        
        // Setup initial selected day for archive view
        final grouped = getOrdersGroupedByBusinessDay();
        if (grouped.isNotEmpty) {
          _selectedArchiveDay = grouped.keys.first;
          if (grouped[_selectedArchiveDay]!.isNotEmpty) {
            _selectedArchiveOrder = grouped[_selectedArchiveDay]!.first;
          }
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
            
            // If the order is part of the current active shift, auto-select it
            if (order.createdAt.isAfter(getStartOfBusinessDay())) {
              _selectedOrder = order;
            }
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
            if (_selectedArchiveOrder?.id == id) {
              _selectedArchiveOrder = updatedOrder;
            }
          }
        });
      },
    );
  }

  // Business day shift calculation: 12:00 PM (noon) to 12:00 PM next day
  DateTime getStartOfBusinessDay() {
    final now = DateTime.now();
    if (now.hour < 12) {
      return DateTime(now.year, now.month, now.day - 1, 12, 0, 0);
    } else {
      return DateTime(now.year, now.month, now.day, 12, 0, 0);
    }
  }

  DateTime getStartOfBusinessDayFor(DateTime dt) {
    if (dt.hour < 12) {
      return DateTime(dt.year, dt.month, dt.day - 1, 12, 0, 0);
    } else {
      return DateTime(dt.year, dt.month, dt.day, 12, 0, 0);
    }
  }

  String getBusinessDayLabel(DateTime dt) {
    final start = getStartOfBusinessDayFor(dt);
    final months = [
      'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
      'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'
    ];
    final days = [
      'Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'
    ];
    
    final weekdayLabel = days[start.weekday - 1];
    final monthLabel = months[start.month - 1];
    return '$weekdayLabel ${start.day} $monthLabel';
  }

  // Filter for active daily kitchen orders
  List<OrderModel> getActiveKitchenOrders() {
    final startShift = getStartOfBusinessDay();
    return _orders.where((order) => order.createdAt.isAfter(startShift)).toList();
  }

  // Group all orders by business day
  Map<String, List<OrderModel>> getOrdersGroupedByBusinessDay() {
    final Map<String, List<OrderModel>> grouped = {};
    for (final order in _orders) {
      final label = getBusinessDayLabel(order.createdAt);
      if (!grouped.containsKey(label)) {
        grouped[label] = [];
      }
      grouped[label]!.add(order);
    }
    return grouped;
  }

  // Update status in database and locally
  Future<void> _updateStatus(String status) async {
    final targetOrder = _currentTab == DashboardTab.kitchen ? _selectedOrder : _selectedArchiveOrder;
    if (targetOrder == null) return;
    try {
      await _orderService.updateOrderStatus(targetOrder.id, status);
      
      setState(() {
        final index = _orders.indexWhere((o) => o.id == targetOrder.id);
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
          if (_selectedOrder?.id == targetOrder.id) {
            _selectedOrder = updatedOrder;
          }
          if (_selectedArchiveOrder?.id == targetOrder.id) {
            _selectedArchiveOrder = updatedOrder;
          }
        }
      });

      // Stop alarm sounds on action
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
    final targetOrder = _currentTab == DashboardTab.kitchen ? _selectedOrder : _selectedArchiveOrder;
    if (targetOrder == null) return;
    try {
      final newTime = targetOrder.requestedTime.add(Duration(minutes: minutesDelta));
      await _orderService.updateOrderTime(targetOrder.id, newTime);
      
      setState(() {
        final index = _orders.indexWhere((o) => o.id == targetOrder.id);
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
          if (_selectedOrder?.id == targetOrder.id) {
            _selectedOrder = updatedOrder;
          }
          if (_selectedArchiveOrder?.id == targetOrder.id) {
            _selectedArchiveOrder = updatedOrder;
          }
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

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'IN ATTESA';
      case 'accepted':
        return 'IN PREPARAZIONE';
      case 'delivering':
        return 'IN CONSEGNA';
      case 'completed':
        return 'CONSEGNATO';
      case 'cancelled':
        return 'ANNULLATO';
      default:
        return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1917), // Charcoal Black background
      appBar: AppBar(
        backgroundColor: const Color(0xFFEA580C), // Warm Orange AppBar
        title: const Text(
          'ANGELS LIVORNO - GESTIONALE',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadInitialData,
            tooltip: 'Ricarica Dati',
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
                    // Navigation Sidebar
                    _buildSidebar(),
                    
                    // Main workspace
                    Expanded(
                      child: _buildMainContent(),
                    ),
                  ],
                ),
    );
  }

  // Sidebar widget
  Widget _buildSidebar() {
    return Container(
      width: 240,
      color: const Color(0xFF141211),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Quick Stats header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TURNI DI OGGI',
                  style: TextStyle(color: Colors.white30, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ordini Attivi: ${getActiveKitchenOrders().length}',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Incasso: €${getActiveKitchenOrders().where((o) => o.status == 'completed').fold(0.0, (double sum, o) => sum + o.totalPrice).toStringAsFixed(2)}',
                  style: const TextStyle(color: Color(0xFFFACC15), fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          const Divider(color: Colors.white10),
          const SizedBox(height: 10),
          
          // Navigation Buttons
          _buildSidebarButton(
            tab: DashboardTab.kitchen,
            icon: Icons.kitchen,
            label: '🍳 CUCINA ATTIVA',
            badgeCount: getActiveKitchenOrders().where((o) => o.status == 'pending').length,
          ),
          _buildSidebarButton(
            tab: DashboardTab.archive,
            icon: Icons.library_books,
            label: '📅 RUBRICA GIORNATE',
          ),
          _buildSidebarButton(
            tab: DashboardTab.balance,
            icon: Icons.trending_up,
            label: '📈 BILANCIO & DATI',
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarButton({
    required DashboardTab tab,
    required IconData icon,
    required String label,
    int badgeCount = 0,
  }) {
    final isSelected = _currentTab == tab;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: isSelected ? const Color(0xFFEA580C) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            setState(() {
              _currentTab = tab;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: isSelected ? Colors.white : Colors.white60, size: 20),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (badgeCount > 0)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Switch between tab screens
  Widget _buildMainContent() {
    switch (_currentTab) {
      case DashboardTab.kitchen:
        return _buildKitchenView();
      case DashboardTab.archive:
        return _buildArchiveView();
      case DashboardTab.balance:
        return _buildBalanceView();
    }
  }

  // TAB 1: KITCHEN VIEW (ACTIVE SHIFT ORDERS ONLY)
  Widget _buildKitchenView() {
    final activeOrders = getActiveKitchenOrders();
    
    // Fallback selection if target selectedOrder is not in active shift
    if (_selectedOrder != null && !activeOrders.any((o) => o.id == _selectedOrder!.id)) {
      if (activeOrders.isNotEmpty) {
        _selectedOrder = activeOrders.first;
      } else {
        _selectedOrder = null;
      }
    } else if (_selectedOrder == null && activeOrders.isNotEmpty) {
      _selectedOrder = activeOrders.first;
    }

    return Row(
      children: [
        // Left Column: Active daily list
        Expanded(
          flex: 4,
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.white12, width: 1),
              ),
            ),
            child: activeOrders.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'Nessun ordine attivo per il turno di oggi.\nGli ordini dei clienti compariranno qui in tempo reale.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white60, fontSize: 16, height: 1.4),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: activeOrders.length,
                    itemBuilder: (context, index) {
                      final order = activeOrders[index];
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
                              _getStatusLabel(order.status),
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
        
        // Right Column: Active detail pane
        Expanded(
          flex: 6,
          child: _selectedOrder == null
              ? const Center(
                  child: Text(
                    'Seleziona un ordine per visualizzare i dettagli',
                    style: TextStyle(color: Colors.white60, fontSize: 16),
                  ),
                )
              : _buildOrderDetailsPane(_selectedOrder!),
        ),
      ],
    );
  }

  // TAB 2: HISTORIC ARCHIVE BY DAY (RUBRICA GIORNATE)
  Widget _buildArchiveView() {
    final grouped = getOrdersGroupedByBusinessDay();
    if (grouped.isEmpty) {
      return const Center(
        child: Text(
          'Nessuna giornata registrata nello storico.',
          style: TextStyle(color: Colors.white60, fontSize: 16),
        ),
      );
    }

    final daysList = grouped.keys.toList();
    if (_selectedArchiveDay == null || !daysList.contains(_selectedArchiveDay)) {
      _selectedArchiveDay = daysList.first;
    }

    final ordersForSelectedDay = grouped[_selectedArchiveDay] ?? [];
    if (_selectedArchiveOrder == null && ordersForSelectedDay.isNotEmpty) {
      _selectedArchiveOrder = ordersForSelectedDay.first;
    } else if (_selectedArchiveOrder != null && !ordersForSelectedDay.any((o) => o.id == _selectedArchiveOrder!.id)) {
      _selectedArchiveOrder = ordersForSelectedDay.isNotEmpty ? ordersForSelectedDay.first : null;
    }

    return Row(
      children: [
        // Left Column: List of business days
        Expanded(
          flex: 3,
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.white12, width: 1),
              ),
            ),
            child: ListView.builder(
              itemCount: daysList.length,
              itemBuilder: (context, index) {
                final dayLabel = daysList[index];
                final dayOrders = grouped[dayLabel] ?? [];
                final completedCount = dayOrders.length;
                final totalRev = dayOrders.where((o) => o.status == 'completed').fold(0.0, (double sum, o) => sum + o.totalPrice);
                final isSelected = _selectedArchiveDay == dayLabel;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedArchiveDay = dayLabel;
                      if (dayOrders.isNotEmpty) {
                        _selectedArchiveOrder = dayOrders.first;
                      } else {
                        _selectedArchiveOrder = null;
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF2E2A27) : Colors.transparent,
                      border: const Border(
                        bottom: BorderSide(color: Colors.white10, width: 0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dayLabel,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFFFACC15) : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$completedCount ordini totali',
                              style: const TextStyle(color: Colors.white60, fontSize: 13),
                            ),
                            Text(
                              '€${totalRev.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // Middle Column: Orders list for selected business day
        Expanded(
          flex: 3,
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.white12, width: 1),
              ),
            ),
            child: ordersForSelectedDay.isEmpty
                ? const Center(
                    child: Text('Nessun ordine in questo giorno', style: TextStyle(color: Colors.white60)),
                  )
                : ListView.builder(
                    itemCount: ordersForSelectedDay.length,
                    itemBuilder: (context, index) {
                      final order = ordersForSelectedDay[index];
                      final isSelected = _selectedArchiveOrder?.id == order.id;
                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: Colors.white12,
                        title: Text(
                          order.guestName.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Ora: ${_formatTime(order.createdAt)} | €${order.totalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white60),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: _getStatusColor(order.status).withOpacity(0.8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getStatusLabel(order.status),
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _selectedArchiveOrder = order;
                          });
                        },
                      );
                    },
                  ),
          ),
        ),

        // Right Column: Order Details Pane for selected archive order
        Expanded(
          flex: 4,
          child: _selectedArchiveOrder == null
              ? const Center(
                  child: Text(
                    'Seleziona un ordine dallo storico',
                    style: TextStyle(color: Colors.white60),
                  ),
                )
              : _buildOrderDetailsPane(_selectedArchiveOrder!),
        ),
      ],
    );
  }

  // TAB 3: BUSINESS PERFORMANCE VIEW (BILANCIO)
  Widget _buildBalanceView() {
    final grouped = getOrdersGroupedByBusinessDay();
    final List<MapEntry<String, double>> dailyRevenue = [];
    
    double totalRevenue = 0.0;
    int totalOrdersCount = 0;
    double maxDayRevenue = 0.0;
    String bestDayLabel = 'Nessuno';

    grouped.forEach((day, orders) {
      final completedOrders = orders.where((o) => o.status == 'completed').toList();
      final revenue = completedOrders.fold(0.0, (double sum, o) => sum + o.totalPrice);
      dailyRevenue.add(MapEntry(day, revenue));

      totalRevenue += revenue;
      totalOrdersCount += completedOrders.length;
      if (revenue > maxDayRevenue) {
        maxDayRevenue = revenue;
        bestDayLabel = day;
      }
    });

    final avgRevenue = totalOrdersCount > 0 ? (totalRevenue / totalOrdersCount) : 0.0;
    
    // Sort chronological: take up to last 7 days for the chart
    final chartData = dailyRevenue.take(7).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ANDAMENTO ECONOMICO',
            style: TextStyle(color: Color(0xFFFACC15), fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.1),
          ),
          const SizedBox(height: 6),
          const Text(
            'Analisi delle vendite e crescita del ristorante basata sui turni di cassa.',
            style: TextStyle(color: Colors.white60, fontSize: 14),
          ),
          const SizedBox(height: 30),

          // Cards Row
          Row(
            children: [
              _buildStatsCard(
                title: 'INCASSO TOTALE',
                value: '€ ${totalRevenue.toStringAsFixed(2)}',
                subtitle: 'Storico registrato',
                icon: Icons.account_balance_wallet,
                iconColor: Colors.green,
              ),
              const SizedBox(width: 20),
              _buildStatsCard(
                title: 'ORDINI COMPLETATI',
                value: '$totalOrdersCount',
                subtitle: 'Consegne riuscite',
                icon: Icons.check_circle,
                iconColor: Colors.blue,
              ),
              const SizedBox(width: 20),
              _buildStatsCard(
                title: 'RICEVUTA MEDIA',
                value: '€ ${avgRevenue.toStringAsFixed(2)}',
                subtitle: 'Scontrino medio clientela',
                icon: Icons.receipt_long,
                iconColor: Colors.purple,
              ),
              const SizedBox(width: 20),
              _buildStatsCard(
                title: 'GIORNATA MIGLIORE',
                value: bestDayLabel.split(' ').take(2).join(' '),
                subtitle: 'Record: €${maxDayRevenue.toStringAsFixed(0)}',
                icon: Icons.star,
                iconColor: const Color(0xFFFACC15),
              ),
            ],
          ),
          const SizedBox(height: 40),

          // Chart Section
          Container(
            height: 350,
            padding: const EdgeInsets.only(top: 24, bottom: 12, right: 30, left: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF2E2A27),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'RICAVO SHIFT GIORNALIERI (€) - ULTIMI 7 TURNI',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: _buildRevenueChart(chartData),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF2E2A27),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white30, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart(List<MapEntry<String, double>> last7DaysData) {
    if (last7DaysData.isEmpty) {
      return const Center(child: Text('Dati insufficienti per il grafico.', style: TextStyle(color: Colors.white60)));
    }
    
    final chronologicalData = last7DaysData.reversed.toList();
    final List<FlSpot> spots = [];
    double maxRevenue = 100.0;
    
    for (int i = 0; i < chronologicalData.length; i++) {
      final rev = chronologicalData[i].value;
      spots.add(FlSpot(i.toDouble(), rev));
      if (rev > maxRevenue) maxRevenue = rev;
    }
    
    maxRevenue = (maxRevenue * 1.15).ceilToDouble();
    if (maxRevenue == 0) maxRevenue = 100.0;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: maxRevenue / 4,
          verticalInterval: 1,
          getDrawingHorizontalLine: (value) => const FlLine(color: Colors.white10, strokeWidth: 1),
          getDrawingVerticalLine: (value) => const FlLine(color: Colors.white10, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < chronologicalData.length) {
                  final parts = chronologicalData[idx].key.split(' ');
                  if (parts.length >= 2) {
                    final day = parts[0].substring(0, 3);
                    final num = parts[1];
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('$day $num', style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(chronologicalData[idx].key, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: maxRevenue / 4,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text('€${value.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                );
              },
              reservedSize: 50,
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.white24, width: 1),
        ),
        minX: 0,
        maxX: (chronologicalData.length - 1).toDouble(),
        minY: 0,
        maxY: maxRevenue,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFFEA580C),
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFFEA580C).withOpacity(0.15),
            ),
          ),
        ],
      ),
    );
  }

  // SHARED ORDER DETAILS PANE
  Widget _buildOrderDetailsPane(OrderModel order) {
    return Container(
      color: const Color(0xFF231F1D), // Dark panel background
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Order Header ID and status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'ORDINE: #${order.id.split("-").first.toUpperCase()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(order.status),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _getStatusLabel(order.status),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Inserito il: ${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year} alle ore ${_formatTime(order.createdAt)}',
            style: const TextStyle(color: Colors.white30, fontSize: 13),
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white12),
          const SizedBox(height: 15),

          // Customer details card
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Client info
                  const Text(
                    'DATI CLIENTE:',
                    style: TextStyle(
                      color: Color(0xFFFACC15),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'NOME: ${order.guestName.toUpperCase()}',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'TEL: ${order.guestPhone}',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  if (order.guestAddress != null && order.guestAddress!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'INDIRIZZO: ${order.guestAddress}',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'TIPO RITIRO: ${order.deliveryType == 'delivery' ? 'CONSEGNA A DOMICILIO' : 'ASPORTO'}',
                    style: const TextStyle(
                      color: Color(0xFFFACC15),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  // Adjust requested time row (Only for non-cancelled and non-completed orders)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ORARIO RICHIESTO: ${_formatTime(order.requestedTime)}',
                        style: const TextStyle(
                          color: Color(0xFFFACC15),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (order.status != 'completed' && order.status != 'cancelled')
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

                  // Ordered Items List
                  const Text(
                    'ARTICOLI ORDINATI:',
                    style: TextStyle(
                      color: Color(0xFFFACC15),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (order.items.isEmpty)
                    const Text(
                      'Nessun articolo trovato per questo ordine.',
                      style: TextStyle(color: Colors.white60, fontStyle: FontStyle.italic),
                    )
                  else
                    ...order.items.map<Widget>((item) {
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
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'TOTALE DA PAGARE:',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              '€${order.totalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Color(0xFFFACC15),
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                        if (order.notes != null && order.notes!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'NOTE DELL\'ORDINE:',
                            style: TextStyle(color: Colors.white60, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            order.notes!,
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Bottom Kitchen Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (order.status == 'pending') ...[
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
              ] else if (order.status == 'accepted') ...[
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
              ] else if (order.status == 'delivering') ...[
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
              if (order.status != 'completed' && order.status != 'cancelled')
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
