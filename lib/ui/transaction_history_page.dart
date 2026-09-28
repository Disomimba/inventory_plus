import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../logic/inventory_controller.dart';

class TransactionHistoryPage extends StatefulWidget {
  final InventoryController controller;

  const TransactionHistoryPage({super.key, required this.controller});

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  late Future<List<_OrderGroup>> _groupedFuture;
  String _filterStatus = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _load() {
    _groupedFuture = _fetchGrouped();
  }

  Future<List<_OrderGroup>> _fetchGrouped() async {
    final locId = widget.controller.activeLocationId;
    if (locId == null) return [];

    try {
      final orders = await widget.controller.supabase
          .from('orders')
          .select()
          .eq('location_id', locId)
          .order('created_at', ascending: false);

      final allUserIds = orders
          .expand((o) {
            final createdBy = o['created_by'];
            final preparedBy = o['prepared_by'];
            final preparedByInt = preparedBy != null ? int.tryParse(preparedBy.toString()) : null;
            return [createdBy, preparedByInt];
          })
          .where((id) => id != null)
          .toSet()
          .toList();

      Map<dynamic, String> profileNames = {};
      if (allUserIds.isNotEmpty) {
        final profiles = await widget.controller.supabase
            .from('profiles')
            .select('id, name')
            .inFilter('id', allUserIds);
        for (final p in profiles) {
          profileNames[p['id']] = p['name']?.toString() ?? '—';
        }
      }

      final List<_OrderGroup> groups = [];

      for (final order in orders) {
        final status = order['status'] as String? ?? 'pending';
        final createdAt = DateTime.parse(order['created_at']).toLocal();
        final rawItems = order['items'] as List<dynamic>? ?? [];
        
        final items = rawItems.map((i) {
          final parsedItem = _OrderLineItem.fromJson(i as Map<String, dynamic>);
          
          double itemPrice = parsedItem.price;
          if (itemPrice == 0.0) {
            try {
              final dbItem = widget.controller.allItems.firstWhere((inv) => inv.id == parsedItem.productId);
              itemPrice = dbItem.price;
            } catch (_) {}
          }
          
          return _OrderLineItem(
            productId: parsedItem.productId,
            productName: parsedItem.productName,
            quantity: parsedItem.quantity,
            price: itemPrice,
          );
        }).toList();

        double calculatedSubtotal = items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
        double totalAmount = (order['total_amount'] as num?)?.toDouble() ?? calculatedSubtotal;
        
        double discount = (order['discount_amount'] as num?)?.toDouble() ?? (calculatedSubtotal - totalAmount);
        if (discount < 0) discount = 0.0;

        double cashGiven = (order['cash_given'] as num?)?.toDouble() ?? 0.0;
        double changeAmount = (order['change_amount'] as num?)?.toDouble() ?? 0.0;
        String paymentMode = order['payment_mode'] as String? ?? 'N/A';

        groups.add(_OrderGroup(
          id: order['id'].toString(),
          status: status,
          createdAt: createdAt,
          totalAmount: totalAmount,
          subtotal: calculatedSubtotal, 
          discount: discount,           
          cashGiven: cashGiven,         
          changeAmount: changeAmount,   
          paymentMode: paymentMode,     
          items: items,
          createdBy: order['created_by'] != null
              ? profileNames[order['created_by']]
              : null,
          preparedBy: order['prepared_by'] != null
              ? profileNames[int.tryParse(order['prepared_by'].toString())]
              : null,
        ));
      }

      return groups;
    } catch (e) {
      debugPrint('Error fetching orders: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, 
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Transaction History',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    FutureBuilder<List<_OrderGroup>>(
                      future: _groupedFuture,
                      builder: (context, snapshot) {
                        final count = snapshot.data?.where((g) => g.createdAt.month == DateTime.now().month && g.createdAt.year == DateTime.now().year).length ?? 0;
                        return Text(
                          '$count orders this month',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        );
                      }
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(LucideIcons.refreshCw, size: 18, color: Colors.black87),
                    onPressed: () => setState(() => _load()),
                    tooltip: 'Refresh',
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),

          Expanded(
            child: FutureBuilder<List<_OrderGroup>>(
              future: _groupedFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.orange),
                  );
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final all = snapshot.data ?? [];
                
                final now = DateTime.now();
                final thisMonth = all.where((g) => g.createdAt.month == now.month && g.createdAt.year == now.year).toList();
                final totalOrders = thisMonth.length;
                final pendingOrders = thisMonth.where((g) => g.status == 'pending' || g.status == 'prepared').length;
                final revenue = thisMonth.where((g) => g.status == 'completed').fold(0.0, (sum, g) => sum + g.totalAmount);

                var filtered = _filterStatus == 'All'
                    ? all
                    : all.where((g) => g.status == _filterStatus.toLowerCase()).toList();
                    
                if (_searchQuery.isNotEmpty) {
                  filtered = filtered.where((g) {
                    final query = _searchQuery.toLowerCase();
                    final matchId = g.id.toLowerCase().contains(query);
                    final matchItem = g.items.any((item) => item.productName.toLowerCase().contains(query));
                    return matchId || matchItem;
                  }).toList();
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Row(
                        children: [
                          _buildStatCard("TOTAL ORDERS", "$totalOrders", Colors.black87),
                          const SizedBox(width: 16),
                          _buildStatCard("PENDING", "$pendingOrders", Colors.orange),
                          const SizedBox(width: 16),
                          _buildStatCard("REVENUE (MONTH)", "₱${revenue.toStringAsFixed(2)}", Colors.green),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: Colors.grey.shade200),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                      child: Row(
                        children: [
                          _buildFilterPills(),
                          const Spacer(),
                          SizedBox(
                            width: 280,
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search order # or item...',
                                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                prefixIcon: Icon(LucideIcons.search, size: 16, color: Colors.grey.shade500),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                              onChanged: (val) => setState(() => _searchQuery = val),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: filtered.isEmpty 
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) =>
                                  _OrderCard(group: filtered[index]),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color valueColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPills() {
    final filters = ['All', 'Pending', 'Prepared', 'Completed'];
    return Row(
      children: filters.map((f) {
        final isSelected = _filterStatus == f;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => setState(() => _filterStatus = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? Colors.grey.shade300 : Colors.transparent),
                boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : [],
              ),
              child: Text(
                f,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.black87 : Colors.grey.shade600,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.receipt, size: 52, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'No orders found',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 4),
          Text(
            'Adjust your search or filters to see results.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

Color _statusColor(String status) {
  switch (status) {
    case 'completed':
      return Colors.green;
    case 'prepared':
      return Colors.blue;
    case 'pending':
      return Colors.orange;
    default:
      return Colors.grey;
  }
}

IconData _statusIcon(String status) {
  switch (status) {
    case 'completed':
      return LucideIcons.check;
    case 'prepared':
      return LucideIcons.packageCheck;
    case 'pending':
      return LucideIcons.clock;
    default:
      return LucideIcons.circle;
  }
}

String _formatDate(DateTime date) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  final month = months[date.month - 1];
  final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  return '$month ${date.day}, ${date.year} • $hour:$minute $period';
}

// ─── Data models ──────────────────────────────────────────────────────────────

class _OrderGroup {
  final String id;
  final String status;
  final DateTime createdAt;
  final double totalAmount;
  final double subtotal; 
  final double discount; 
  final double cashGiven;      
  final double changeAmount;   
  final String paymentMode;    
  final List<_OrderLineItem> items;
  final String? createdBy;
  final String? preparedBy;

  _OrderGroup({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.totalAmount,
    required this.subtotal, 
    required this.discount, 
    required this.cashGiven,     
    required this.changeAmount,  
    required this.paymentMode,   
    required this.items,
    this.createdBy,
    this.preparedBy,
  });

  String get shortId =>
      id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
}

class _OrderLineItem {
  final String productId;
  final String productName;
  final int quantity;
  final double price; 

  _OrderLineItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
  });

  factory _OrderLineItem.fromJson(Map<String, dynamic> json) => _OrderLineItem(
        productId: json['product_id']?.toString() ?? '',
        productName: json['product_name']?.toString() ?? 'Unknown Item',
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
      );
}

// ─── Order Card ───────────────────────────────────────────────────────────────

class _OrderCard extends StatefulWidget {
  final _OrderGroup group;

  const _OrderCard({required this.group});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> with SingleTickerProviderStateMixin {
  bool _expanded = false;

  void _toggle() {
    setState(() => _expanded = !_expanded);
  }

  void _showReceiptModal(BuildContext context, _OrderGroup g) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          child: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Receipt Header
                    const Text(
                      'INVENTORY PLUS',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'SPRJ Paint Center - San Pedro, Laguna',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                    ),
                    const SizedBox(height: 16),
                    const _DashedDivider(),
                    const SizedBox(height: 16),
                    
                    // Meta info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Order #', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                        Text(g.shortId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Date', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                        Text(_formatDate(g.createdAt), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Cashier', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                        Text(g.createdBy ?? "Admin", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const _DashedDivider(),
                    const SizedBox(height: 16),
                    
                    // Items List
                    ...g.items.map((item) {
                      double itemTotal = item.price * item.quantity;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text('${item.quantity} qty x ₱${item.price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              )
                            ),
                            Text('₱${itemTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      );
                    }),
                    
                    const SizedBox(height: 16),
                    const _DashedDivider(),
                    const SizedBox(height: 16),
                    
                    // Totals
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal', style: TextStyle(fontSize: 12)),
                        Text('₱${g.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    if (g.discount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Discount', style: TextStyle(fontSize: 12)),
                          Text('-₱${g.discount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                        Text('₱${g.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                      ],
                    ),

                    if (g.status == 'completed') ...[
                      const SizedBox(height: 16),
                      const _DashedDivider(),
                      const SizedBox(height: 16),
                      if (g.cashGiven > 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Cash Given', style: TextStyle(fontSize: 12)),
                            Text('₱${g.cashGiven.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (g.changeAmount > 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Change', style: TextStyle(fontSize: 12)),
                            Text('₱${g.changeAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Mode of Payment', style: TextStyle(fontSize: 12)),
                          Text(g.paymentMode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),
                    Text('Thank you for your purchase!', style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontStyle: FontStyle.italic)),
                    Text('This serves as your official receipt.', style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontStyle: FontStyle.italic)),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text("Close", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final color = _statusColor(g.status);
    final bgColor = color.withOpacity(0.05);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 6,
              color: color,
            ),
            Expanded(
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  onExpansionChanged: (expanded) => _toggle(),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: bgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_statusIcon(g.status), color: color, size: 18),
                  ),
                  title: Row(
                    children: [
                      Text(
                        'Order #${g.shortId}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(width: 8),
                      _StatusChip(status: g.status),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      '${_formatDate(g.createdAt)} - by ${g.createdBy ?? "Admin"}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "₱${g.totalAmount.toStringAsFixed(2)}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${g.items.length} item${g.items.length == 1 ? '' : 's'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  children: [
                    Divider(height: 1, color: Colors.grey.shade100),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "ORDER ITEMS",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...g.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(LucideIcons.package, size: 16, color: Colors.orange),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                  ),
                                  if (item.price > 0)
                                    Text(
                                      "₱${item.price.toStringAsFixed(2)} / unit",
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "x${item.quantity}",
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showReceiptModal(context, g),
                        icon: const Icon(LucideIcons.receipt, size: 16),
                        label: const Text("Show Receipt", style: TextStyle(fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status._cap(),
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

extension _StrExt on String {
  String _cap() => isEmpty ? '' : '${this[0].toUpperCase()}${substring(1)}';
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 5.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.grey.shade300),
              ),
            );
          }),
        );
      },
    );
  }
}