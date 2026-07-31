import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';
import '../services/notification_manager.dart';
import 'login_screen.dart';

enum DashboardTab {
  kitchen, // active daily orders
  drivers, // riders & delivery assignment tracking
  archive, // historic list of days
  balance, // performance chart & metrics
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

  // Custom added driver roster list
  final List<String> _customDrivers = ['Marco', 'Luca', 'Giovanni', 'Giuseppe', 'Andrea'];

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
          if (!_orders.any((o) => o.id == order.id)) {
            _orders.insert(0, order);

            if (order.createdAt.isAfter(getStartOfBusinessDay())) {
              _selectedOrder = order;
            }
          }
        });

        _notificationManager.playOrderAlarm();
        _notificationManager.triggerNewOrderNotification(
          orderId: order.id,
          guestName: order.guestName,
          totalPrice: order.totalPrice,
          deliveryType: order.deliveryType,
        );
      },
      onOrderUpdated: (id, status) {
        _loadInitialData();
      },
    );
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      _orderService.unsubscribe(_realtimeChannel!);
    }
    super.dispose();
  }

  Future<void> _handleLogout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  DateTime getStartOfBusinessDay() {
    return getStartOfBusinessDayFor(DateTime.now());
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

  List<OrderModel> getActiveKitchenOrders() {
    final startShift = getStartOfBusinessDay();
    return _orders.where((order) => order.createdAt.isAfter(startShift)).toList();
  }

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

  // Extract all unique driver names from Telegram claims & custom list
  List<String> getExtractedDrivers() {
    final Set<String> drivers = {};
    for (final driver in _customDrivers) {
      drivers.add(driver.toUpperCase());
    }

    for (final order in _orders) {
      if (order.notes != null && order.notes!.isNotEmpty) {
        final note = order.notes!;
        if (note.contains('Fattorino:')) {
          final name = note.replaceAll('Fattorino:', '').replaceAll(RegExp(r'\(.*\)'), '').trim().toUpperCase();
          if (name.isNotEmpty) {
            drivers.add(name);
          }
        }
      }
    }
    return drivers.toList()..sort();
  }

  // Helper to extract clean driver name from order notes
  String? _getDriverFromOrder(OrderModel order) {
    if (order.notes != null && order.notes!.isNotEmpty) {
      final note = order.notes!;
      if (note.contains('Fattorino:')) {
        return note.replaceAll('Fattorino:', '').replaceAll(RegExp(r'\(.*\)'), '').trim().toUpperCase();
      }
    }
    return null;
  }

  bool _isOrderBatched(OrderModel order) {
    if (order.notes != null && order.notes!.isNotEmpty) {
      final note = order.notes!;
      return note.contains('Abbinato:') || note.contains('Doppia');
    }
    return false;
  }

  Future<void> _assignDriverToOrder(OrderModel order, String driverName) async {
    try {
      await _orderService.updateOrderDriver(order.id, driverName);
      await _loadInitialData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ordine assegnato a $driverName 🛵'),
          backgroundColor: Colors.green.shade800,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante l\'assegnazione: $e')),
      );
    }
  }

  Future<void> _unbatchOrder(OrderModel order) async {
    try {
      await _orderService.unbatchOrder(order.id);
      await _loadInitialData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Abbinamento rimosso. Ordine separato con successo! ✂️'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante la separazione: $e')),
      );
    }
  }

  Future<void> _updateStatus(String status) async {
    final targetOrder = _currentTab == DashboardTab.kitchen ? _selectedOrder : _selectedArchiveOrder;
    if (targetOrder == null) return;
    try {
      await _orderService.updateOrderStatus(targetOrder.id, status);
      await _loadInitialData();

      if (status == 'accepted' || status == 'cancelled') {
        await _notificationManager.stopOrderAlarm();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante l\'aggiornamento: $e')),
      );
    }
  }

  Future<void> _updateOrderTime(int minutesDelta) async {
    final targetOrder = _currentTab == DashboardTab.kitchen ? _selectedOrder : _selectedArchiveOrder;
    if (targetOrder == null) return;
    try {
      final newTime = targetOrder.requestedTime.add(Duration(minutes: minutesDelta));
      await _orderService.updateOrderTime(targetOrder.id, newTime);
      await _loadInitialData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Orario aggiornato a ${_formatTime(newTime)}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante l\'aggiornamento dell\'orario: $e')),
      );
    }
  }

  void _showAddDriverDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2E2A27),
          title: const Text('AGGIUNGI NUOVO FATTORINO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Nome Fattorino (es. Marco)',
              hintStyle: TextStyle(color: Colors.white38),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFEA580C))),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFACC15))),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ANNULLA', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEA580C)),
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  setState(() {
                    if (!_customDrivers.contains(name)) {
                      _customDrivers.add(name);
                    }
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('SALVA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

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

  void _showOrderDetailsMobileModal(OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1917),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.9,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'DETTAGLIO ORDINE',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24),
                    _buildOrderDetailsPane(order),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 850;

    return Scaffold(
      backgroundColor: const Color(0xFF1C1917),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEA580C),
        elevation: 2,
        title: Text(
          isMobile ? 'ANGELS GESTIONALE' : 'ANGELS LIVORNO - GESTIONALE',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.0, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadInitialData,
            tooltip: 'Ricarica Dati',
          ),
          if (isMobile)
            IconButton(
              icon: const Icon(Icons.volume_off, color: Color(0xFFFACC15)),
              onPressed: () => _notificationManager.stopOrderAlarm(),
              tooltip: 'Silenzia Allarme',
            )
          else
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFACC15),
                foregroundColor: Colors.black,
              ),
              icon: const Icon(Icons.volume_off, size: 18),
              label: const Text('SILENZIA ALLARME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: () => _notificationManager.stopOrderAlarm(),
            ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _handleLogout,
            tooltip: 'Esci / Logout',
          ),
          const SizedBox(width: 8),
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
              : isMobile
                  ? _buildMainContentMobile()
                  : Row(
                      children: [
                        _buildSidebar(),
                        Expanded(
                          child: _buildMainContent(),
                        ),
                      ],
                    ),
      bottomNavigationBar: isMobile
          ? BottomNavigationBar(
              backgroundColor: const Color(0xFF141211),
              selectedItemColor: const Color(0xFFEA580C),
              unselectedItemColor: Colors.white60,
              type: BottomNavigationBarType.fixed,
              currentIndex: _currentTab.index,
              onTap: (index) {
                setState(() {
                  _currentTab = DashboardTab.values[index];
                });
              },
              items: [
                BottomNavigationBarItem(
                  icon: Stack(
                    children: [
                      const Icon(Icons.kitchen),
                      if (getActiveKitchenOrders().where((o) => o.status == 'pending').isNotEmpty)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            child: Text(
                              '${getActiveKitchenOrders().where((o) => o.status == 'pending').length}',
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                  label: 'Cucina',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.two_wheeler),
                  label: 'Fattorini',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.library_books),
                  label: 'Rubrica',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.trending_up),
                  label: 'Bilancio',
                ),
              ],
            )
          : null,
    );
  }

  // Sidebar widget for Desktop
  Widget _buildSidebar() {
    return Container(
      width: 240,
      color: const Color(0xFF141211),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          _buildSidebarButton(
            tab: DashboardTab.kitchen,
            icon: Icons.kitchen,
            label: '🍳 CUCINA ATTIVA',
            badgeCount: getActiveKitchenOrders().where((o) => o.status == 'pending').length,
          ),
          _buildSidebarButton(
            tab: DashboardTab.drivers,
            icon: Icons.two_wheeler,
            label: '🛵 FATTORINI & RIDER',
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

  Widget _buildMainContent() {
    switch (_currentTab) {
      case DashboardTab.kitchen:
        return _buildKitchenView();
      case DashboardTab.drivers:
        return _buildDriversView();
      case DashboardTab.archive:
        return _buildArchiveView();
      case DashboardTab.balance:
        return _buildBalanceView();
    }
  }

  Widget _buildMainContentMobile() {
    switch (_currentTab) {
      case DashboardTab.kitchen:
        return _buildKitchenViewMobile();
      case DashboardTab.drivers:
        return _buildDriversViewMobile();
      case DashboardTab.archive:
        return _buildArchiveViewMobile();
      case DashboardTab.balance:
        return _buildBalanceViewMobile();
    }
  }

  // TAB 1: KITCHEN VIEW DESKTOP
  Widget _buildKitchenView() {
    final activeOrders = getActiveKitchenOrders();

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
                        style: TextStyle(color: Colors.white60, fontSize: 16, height: 1.4),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: activeOrders.length,
                    itemBuilder: (context, index) {
                      final order = activeOrders[index];
                      final isSelected = _selectedOrder?.id == order.id;
                      final driverInfo = _getDriverFromOrder(order);
                      final isBatched = _isOrderBatched(order);

                      return Card(
                        color: isSelected
                            ? const Color(0xFFEA580C).withOpacity(0.15)
                            : const Color(0xFF2E2A27),
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: isBatched ? Colors.purpleAccent : (isSelected ? const Color(0xFFEA580C) : Colors.transparent),
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
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  order.guestName.toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (isBatched)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade700,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('📦 DOPPIA', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ora: ${_formatTime(order.createdAt)} | €${order.totalPrice.toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              if (driverInfo != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Text(
                                    '🛵 $driverInfo',
                                    style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
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

  // TAB 1: KITCHEN VIEW MOBILE
  Widget _buildKitchenViewMobile() {
    final activeOrders = getActiveKitchenOrders();
    if (activeOrders.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Nessun ordine attivo per il turno di oggi.\nGli ordini dei clienti compariranno qui in tempo reale.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 15, height: 1.4),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: activeOrders.length,
      itemBuilder: (context, index) {
        final order = activeOrders[index];
        final driverInfo = _getDriverFromOrder(order);
        final isBatched = _isOrderBatched(order);

        return Card(
          color: const Color(0xFF2E2A27),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isBatched ? Colors.purpleAccent : (order.status == 'pending' ? Colors.red : Colors.white10),
              width: order.status == 'pending' || isBatched ? 1.5 : 0.5,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            onTap: () {
              setState(() {
                _selectedOrder = order;
              });
              _showOrderDetailsMobileModal(order);
            },
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    order.guestName.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '€${order.totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFFFACC15),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Ora: ${_formatTime(order.createdAt)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _getStatusColor(order.status),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getStatusLabel(order.status),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isBatched) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade700,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('📦 DOPPIA', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  if (driverInfo != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '🛵 $driverInfo',
                      style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
          ),
        );
      },
    );
  }

  // TAB 2: DRIVERS & RIDER MANAGEMENT DESKTOP
  Widget _buildDriversView() {
    final drivers = getExtractedDrivers();
    final activeShiftOrders = getActiveKitchenOrders();
    final deliveryOrders = activeShiftOrders.where((o) => o.deliveryType == 'delivery').toList();

    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GESTIONE FATTORINI & ASSEGNAZIONI',
                    style: TextStyle(color: Color(0xFFFACC15), fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tracciamento consegne, presa in carico da Telegram e abbinamento consegne vicine (~500m).',
                    style: TextStyle(color: Colors.white60, fontSize: 14),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA580C),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                icon: const Icon(Icons.person_add, color: Colors.white),
                label: const Text('+ AGGIUNGI FATTORINO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: _showAddDriverDialog,
              ),
            ],
          ),
          const SizedBox(height: 30),

          // Drivers Summary Cards Grid
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SQUADRA RIDER & STATISTICHE DI OGGI',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),

                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 2.2,
                    ),
                    itemCount: drivers.length,
                    itemBuilder: (context, index) {
                      final driverName = drivers[index];
                      final driverOrders = deliveryOrders.where((o) => _getDriverFromOrder(o) == driverName).toList();
                      final completedCount = driverOrders.where((o) => o.status == 'completed').length;
                      final inProgressCount = driverOrders.where((o) => o.status == 'delivering' || o.status == 'accepted').length;
                      final totalCash = driverOrders.where((o) => o.status == 'completed').fold(0.0, (double sum, o) => sum + o.totalPrice);

                      return Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E2A27),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: inProgressCount > 0 ? Colors.cyanAccent : Colors.white10,
                            width: inProgressCount > 0 ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: const Color(0xFFEA580C).withOpacity(0.2),
                              child: const Icon(Icons.two_wheeler, color: Color(0xFFEA580C), size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    driverName,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$completedCount consegne • €${totalCash.toStringAsFixed(2)}',
                                    style: const TextStyle(color: Color(0xFFFACC15), fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    inProgressCount > 0 ? '🛵 In viaggio ($inProgressCount ordini)' : '🟢 Disponibile',
                                    style: TextStyle(
                                      color: inProgressCount > 0 ? Colors.cyanAccent : Colors.greenAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),

                  // Delivery Orders Quick-Assign Section
                  const Text(
                    'ORDINI A DOMICILIO - ASSEGNAZIONE & ABBINAMENTI',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),

                  deliveryOrders.isEmpty
                      ? const Card(
                          color: Color(0xFF2E2A27),
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Center(
                              child: Text('Nessun ordine a domicilio attivo nel turno corrente.', style: TextStyle(color: Colors.white60)),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: deliveryOrders.length,
                          itemBuilder: (context, index) {
                            final order = deliveryOrders[index];
                            final assignedDriver = _getDriverFromOrder(order);
                            final isBatched = _isOrderBatched(order);

                            return Card(
                              color: const Color(0xFF2E2A27),
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: isBatched ? Colors.purpleAccent : (assignedDriver != null ? Colors.cyanAccent.withOpacity(0.5) : Colors.white10),
                                  width: isBatched ? 1.5 : 1.0,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                order.guestName.toUpperCase(),
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                              ),
                                              if (isBatched) ...[
                                                const SizedBox(width: 10),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: Colors.purple.shade700,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Text('📦 DOPPIA CONSEGNA ABBINATA', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '📍 ${order.guestAddress ?? "Indirizzo N/D"} • Tel: ${order.guestPhone}',
                                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Ora Richiesta: ${_formatTime(order.requestedTime)} | Totale: €${order.totalPrice.toStringAsFixed(2)}',
                                            style: const TextStyle(color: Color(0xFFFACC15), fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                assignedDriver != null ? 'FATTORINO: $assignedDriver' : '⚠️ NON ASSEGNATO',
                                                style: TextStyle(
                                                  color: assignedDriver != null ? Colors.cyanAccent : Colors.amber,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  if (isBatched)
                                                    Padding(
                                                      padding: const EdgeInsets.only(right: 8.0),
                                                      child: TextButton.icon(
                                                        style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                                                        icon: const Icon(Icons.content_cut, size: 14),
                                                        label: const Text('DIVIDI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                                        onPressed: () => _unbatchOrder(order),
                                                      ),
                                                    ),
                                                  PopupMenuButton<String>(
                                                    color: const Color(0xFF1C1917),
                                                    onSelected: (selectedDriver) => _assignDriverToOrder(order, selectedDriver),
                                                    itemBuilder: (context) {
                                                      return drivers.map((d) {
                                                        return PopupMenuItem<String>(
                                                          value: d,
                                                          child: Row(
                                                            children: [
                                                              const Icon(Icons.two_wheeler, color: Color(0xFFEA580C), size: 18),
                                                              const SizedBox(width: 10),
                                                              Text(d, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                            ],
                                                          ),
                                                        );
                                                      }).toList();
                                                    },
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFEA580C),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: const Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.person_pin, color: Colors.white, size: 16),
                                                          SizedBox(width: 6),
                                                          Text('ASSEGNA ORA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // TAB 2: DRIVERS VIEW MOBILE
  Widget _buildDriversViewMobile() {
    final drivers = getExtractedDrivers();
    final activeShiftOrders = getActiveKitchenOrders();
    final deliveryOrders = activeShiftOrders.where((o) => o.deliveryType == 'delivery').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SQUADRA FATTORINI',
                style: TextStyle(color: Color(0xFFFACC15), fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.person_add, color: Color(0xFFEA580C)),
                onPressed: _showAddDriverDialog,
                tooltip: 'Aggiungi Fattorino',
              ),
            ],
          ),
          const SizedBox(height: 12),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: drivers.length,
            itemBuilder: (context, index) {
              final driverName = drivers[index];
              final driverOrders = deliveryOrders.where((o) => _getDriverFromOrder(o) == driverName).toList();
              final completedCount = driverOrders.where((o) => o.status == 'completed').length;
              final totalCash = driverOrders.where((o) => o.status == 'completed').fold(0.0, (double sum, o) => sum + o.totalPrice);

              return Card(
                color: const Color(0xFF2E2A27),
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEA580C),
                    child: Icon(Icons.two_wheeler, color: Colors.white, size: 20),
                  ),
                  title: Text(driverName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Text('$completedCount consegne • Incasso: €${totalCash.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  trailing: const Icon(Icons.check_circle_outline, color: Colors.greenAccent),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          const Text(
            'ASSEGNAZIONE CONSEGNE',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),

          deliveryOrders.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: Text('Nessuna consegna attiva al momento.', style: TextStyle(color: Colors.white54))),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: deliveryOrders.length,
                  itemBuilder: (context, index) {
                    final order = deliveryOrders[index];
                    final assignedDriver = _getDriverFromOrder(order);
                    final isBatched = _isOrderBatched(order);

                    return Card(
                      color: const Color(0xFF2E2A27),
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    order.guestName.toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '€${order.totalPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(color: Color(0xFFFACC15), fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('📍 ${order.guestAddress ?? "N/D"}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            const SizedBox(height: 8),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      assignedDriver != null ? '🛵 $assignedDriver' : '⚠️ NON ASSEGNATO',
                                      style: TextStyle(
                                        color: assignedDriver != null ? Colors.cyanAccent : Colors.amber,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (isBatched) ...[
                                      const SizedBox(width: 6),
                                      const Text('📦 DOPPIA', style: TextStyle(color: Colors.purpleAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ],
                                  ],
                                ),
                                Row(
                                  children: [
                                    if (isBatched)
                                      IconButton(
                                        icon: const Icon(Icons.content_cut, color: Colors.redAccent, size: 18),
                                        onPressed: () => _unbatchOrder(order),
                                        tooltip: 'Dividi Ordini',
                                      ),
                                    PopupMenuButton<String>(
                                      color: const Color(0xFF1C1917),
                                      onSelected: (selectedDriver) => _assignDriverToOrder(order, selectedDriver),
                                      itemBuilder: (context) {
                                        return drivers.map((d) {
                                          return PopupMenuItem<String>(
                                            value: d,
                                            child: Text(d, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          );
                                        }).toList();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEA580C),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text('ASSEGNA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  // TAB 3: ARCHIVE VIEW DESKTOP
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
                      final driverInfo = _getDriverFromOrder(order);

                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: Colors.white12,
                        title: Text(
                          order.guestName.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ora: ${_formatTime(order.createdAt)} | €${order.totalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white60),
                            ),
                            if (driverInfo != null)
                              Text(
                                '🛵 $driverInfo',
                                style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                          ],
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

  // TAB 3: ARCHIVE VIEW MOBILE
  Widget _buildArchiveViewMobile() {
    final grouped = getOrdersGroupedByBusinessDay();
    if (grouped.isEmpty) {
      return const Center(
        child: Text(
          'Nessuna giornata registrata nello storico.',
          style: TextStyle(color: Colors.white60, fontSize: 15),
        ),
      );
    }

    final daysList = grouped.keys.toList();
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: daysList.length,
      itemBuilder: (context, index) {
        final dayLabel = daysList[index];
        final dayOrders = grouped[dayLabel] ?? [];
        final completedCount = dayOrders.length;
        final totalRev = dayOrders.where((o) => o.status == 'completed').fold(0.0, (double sum, o) => sum + o.totalPrice);

        return Card(
          color: const Color(0xFF2E2A27),
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            onTap: () {
              _showDayOrdersMobileModal(dayLabel, dayOrders);
            },
            title: Text(
              dayLabel,
              style: const TextStyle(color: Color(0xFFFACC15), fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              '$completedCount ordini • Incasso: €${totalRev.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
          ),
        );
      },
    );
  }

  void _showDayOrdersMobileModal(String dayLabel, List<OrderModel> dayOrders) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1917),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dayLabel,
                        style: const TextStyle(color: Color(0xFFFACC15), fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24, height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: dayOrders.length,
                    itemBuilder: (context, index) {
                      final order = dayOrders[index];
                      final driverInfo = _getDriverFromOrder(order);

                      return ListTile(
                        title: Text(order.guestName.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'Ora: ${_formatTime(order.createdAt)} | €${order.totalPrice.toStringAsFixed(2)}${driverInfo != null ? "\n🛵 $driverInfo" : ""}',
                          style: const TextStyle(color: Colors.white60),
                        ),
                        trailing: Icon(Icons.chevron_right, color: _getStatusColor(order.status)),
                        onTap: () {
                          setState(() {
                            _selectedArchiveOrder = order;
                          });
                          Navigator.pop(context);
                          _showOrderDetailsMobileModal(order);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // TAB 4: BUSINESS PERFORMANCE VIEW DESKTOP
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

  // TAB 4: BUSINESS PERFORMANCE VIEW MOBILE
  Widget _buildBalanceViewMobile() {
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
    final chartData = dailyRevenue.take(7).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ANDAMENTO ECONOMICO',
            style: TextStyle(color: Color(0xFFFACC15), fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.0),
          ),
          const SizedBox(height: 4),
          const Text(
            'Analisi delle vendite e crescita del ristorante.',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatsCardMobile(
                  title: 'INCASSO TOTALE',
                  value: '€${totalRevenue.toStringAsFixed(0)}',
                  icon: Icons.account_balance_wallet,
                  iconColor: Colors.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatsCardMobile(
                  title: 'ORDINI COMPLETATI',
                  value: '$totalOrdersCount',
                  icon: Icons.check_circle,
                  iconColor: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildStatsCardMobile(
                  title: 'RICEVUTA MEDIA',
                  value: '€${avgRevenue.toStringAsFixed(1)}',
                  icon: Icons.receipt_long,
                  iconColor: Colors.purple,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatsCardMobile(
                  title: 'GIORNATA TOP',
                  value: bestDayLabel.split(' ').take(2).join(' '),
                  icon: Icons.star,
                  iconColor: const Color(0xFFFACC15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            height: 280,
            padding: const EdgeInsets.only(top: 16, bottom: 12, right: 16, left: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2E2A27),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'RICAVO SHIFT GIORNALIERI (€)',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
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

  Widget _buildStatsCardMobile({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2E2A27),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
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
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
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
                    style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart(List<MapEntry<String, double>> chartData) {
    if (chartData.isEmpty) {
      return const Center(
        child: Text('Nessun dato per il grafico', style: TextStyle(color: Colors.white38)),
      );
    }

    final reversedData = chartData.reversed.toList();
    final maxVal = reversedData.fold(0.0, (double max, entry) => entry.value > max ? entry.value : max);
    final maxY = maxVal == 0 ? 100.0 : maxVal * 1.25;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => const FlLine(color: Colors.white10, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  '€${value.toInt()}',
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < reversedData.length) {
                  final rawLabel = reversedData[index].key;
                  final shortLabel = rawLabel.split(' ').take(2).join(' ');
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      shortLabel,
                      style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (reversedData.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: reversedData.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), e.value.value);
            }).toList(),
            isCurved: true,
            color: const Color(0xFFEA580C),
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 5,
                color: const Color(0xFFFACC15),
                strokeWidth: 2,
                strokeColor: const Color(0xFFEA580C),
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFFEA580C).withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetailsPane(OrderModel order) {
    final isDelivery = order.deliveryType == 'delivery';
    final shortId = order.id.length > 8 ? order.id.substring(0, 8).toUpperCase() : order.id.toUpperCase();
    final driverName = _getDriverFromOrder(order);
    final isBatched = _isOrderBatched(order);
    final availableDrivers = getExtractedDrivers();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ORDINE: #$shortId',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(order.status),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _getStatusLabel(order.status),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Inserito il: ${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year} alle ore ${_formatTime(order.createdAt)}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 24),

          if (isBatched) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.purple.shade900.withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purpleAccent),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '📦 DOPPIA CONSEGNA ABBINATA IN ZONA',
                          style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.notes ?? 'Stessa direzione (~500m)',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800),
                    icon: const Icon(Icons.content_cut, size: 16, color: Colors.white),
                    label: const Text('DIVIDI ORDINI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                    onPressed: () => _unbatchOrder(order),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2E2A27),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('NOME:', order.guestName.toUpperCase()),
                const SizedBox(height: 8),
                _buildInfoRow('TEL:', order.guestPhone),
                const SizedBox(height: 8),
                _buildInfoRow('INDIRIZZO:', order.guestAddress ?? 'N/D'),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'TIPO RITIRO:',
                  isDelivery ? 'CONSEGNA A DOMICILIO 🛵' : 'ASPORTO IN CASSA 🛍️',
                  valueColor: isDelivery ? const Color(0xFFFACC15) : Colors.greenAccent,
                ),

                if (isDelivery) ...[
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 8),
                  const Text(
                    '🛵 FATTORINO ASSEGNATO:',
                    style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),

                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: driverName != null ? Colors.cyan.shade900.withOpacity(0.4) : Colors.white12,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: driverName != null ? Colors.cyanAccent.withOpacity(0.5) : Colors.white24,
                            ),
                          ),
                          child: Text(
                            driverName != null ? '🛵 $driverName' : '⚠️ Nessun fattorino assegnato',
                            style: TextStyle(
                              color: driverName != null ? Colors.cyanAccent : Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      PopupMenuButton<String>(
                        color: const Color(0xFF1C1917),
                        onSelected: (selectedDriver) => _assignDriverToOrder(order, selectedDriver),
                        itemBuilder: (context) {
                          return availableDrivers.map((d) {
                            return PopupMenuItem<String>(
                              value: d,
                              child: Row(
                                children: [
                                  const Icon(Icons.two_wheeler, color: Color(0xFFEA580C), size: 18),
                                  const SizedBox(width: 10),
                                  Text(d, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            );
                          }).toList();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEA580C),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('CAMBIA / ASSEGNA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(color: Colors.white10),
                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'ORARIO RICHIESTO: ${_formatTime(order.requestedTime)}',
                        style: const TextStyle(color: Color(0xFFFACC15), fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                          onPressed: () => _updateOrderTime(-15),
                          tooltip: 'Anticipa 15 min',
                        ),
                        const Text('MODIFICA', style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Colors.greenAccent),
                          onPressed: () => _updateOrderTime(15),
                          tooltip: 'Posticipa 15 min',
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'ARTICOLI ORDINATI:',
            style: TextStyle(color: Color(0xFFFACC15), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.8),
          ),
          const SizedBox(height: 12),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: order.items.length,
            separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
            itemBuilder: (context, index) {
              final item = order.items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${item['qty'] ?? item['quantity'] ?? 1}x  ${item['name'] ?? 'Piatto'}',
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      '€${(Number(item['price_at_order'] ?? item['price'] ?? 0) * Number(item['qty'] ?? item['quantity'] ?? 1)).toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2E2A27),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTALE DA PAGARE:',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '€${order.totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(color: Color(0xFFFACC15), fontWeight: FontWeight.w900, fontSize: 22),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action Status Buttons
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              if (order.status == 'pending')
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  onPressed: () => _updateStatus('accepted'),
                  child: const Text('🧑‍🍳 IN PREPARAZIONE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              if (order.status == 'accepted')
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  onPressed: () => _updateStatus('delivering'),
                  child: const Text('🛵 IN CONSEGNA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              if (order.status == 'delivering' || order.status == 'accepted')
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  onPressed: () => _updateStatus('completed'),
                  child: const Text('✅ CONSEGNATO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              if (order.status != 'cancelled' && order.status != 'completed')
                TextButton(
                  onPressed: () => _updateStatus('cancelled'),
                  child: const Text('ANNULLA ORDINE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  num Number(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val;
    return num.tryParse(val.toString()) ?? 0;
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
