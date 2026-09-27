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

  @override
  void initState() {
    super.initState();
    _load();
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

      // Collect all unique user IDs (both cashier and helper)
      final allUserIds = orders
          .expand((o) {
            final createdBy = o['created_by'];
            final preparedBy = o['prepared_by'];
            // prepared_by is stored as text, parse to int to match profiles.id (bigint)
            final preparedByInt = preparedBy != null ? int.tryParse(preparedBy.toString()) : null;
            return [createdBy, preparedByInt];
          })
          .where((id) => id != null)
          .toSet()
          .toList();

      // Single batch fetch for all names
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
        final items = rawItems
            .map((i) => _OrderLineItem.fromJson(i as Map<String, dynamic>))
            .toList();

        groups.add(_OrderGroup(
          id: order['id'].toString(),
          status: status,
          createdAt: createdAt,
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Transaction History',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 20),
            onPressed: () => setState(() => _load()),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
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
                final filtered = _filterStatus == 'All'
                    ? all
                    : all
                        .where((g) =>
                            g.status == _filterStatus.toLowerCase())
                        .toList();

                if (filtered.isEmpty) return _buildEmptyState();

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) =>
                      _OrderCard(group: filtered[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = ['All', 'Pending', 'Prepared', 'Completed'];
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((f) {
            final isSelected = _filterStatus == f;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _filterStatus = f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _statusColor(f.toLowerCase())
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    f,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          isSelected ? Colors.white : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
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
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 4),
          Text(
            'Orders will appear here once they are placed.',
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
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  return '$month ${date.day}, ${date.year} • $hour:$minute $period';
}

// ─── Data models ──────────────────────────────────────────────────────────────

class _OrderGroup {
  final String id;
  final String status;
  final DateTime createdAt;
  final List<_OrderLineItem> items;
  final String? createdBy;
  final String? preparedBy;

  _OrderGroup({
    required this.id,
    required this.status,
    required this.createdAt,
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

  _OrderLineItem({
    required this.productId,
    required this.productName,
    required this.quantity,
  });

  factory _OrderLineItem.fromJson(Map<String, dynamic> json) => _OrderLineItem(
        productId: json['product_id']?.toString() ?? '',
        productName: json['product_name']?.toString() ?? 'Unknown Item',
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      );
}

// ─── Order Card ───────────────────────────────────────────────────────────────

class _OrderCard extends StatefulWidget {
  final _OrderGroup group;

  const _OrderCard({required this.group});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _expandAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _controller.forward() : _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final color = _statusColor(g.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child:
                        Icon(_statusIcon(g.status), color: color, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Order #${g.shortId}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusChip(status: g.status),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _formatDate(g.createdAt),
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${g.items.length} item${g.items.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: Icon(LucideIcons.chevronDown,
                            size: 18, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Expandable content ────────────────────────────────────────
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Column(
              children: [
                Divider(height: 1, color: Colors.grey.shade100),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Staff row ──────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _StaffBadge(
                                label: 'Cashier',
                                name: g.createdBy ?? '—',
                                icon: LucideIcons.creditCard,
                                color: Colors.orange,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 36,
                              color: Colors.grey.shade200,
                              margin: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            Expanded(
                              child: _StaffBadge(
                                label: 'Helper',
                                name: g.preparedBy ?? '—',
                                icon: LucideIcons.handHelping,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ── Items ──────────────────────────────────────
                      Text(
                        'ORDER ITEMS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...g.items.asMap().entries.map((entry) {
                        final isLast = entry.key == g.items.length - 1;
                        return _LineItemRow(
                            item: entry.value, isLast: isLast);
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Staff badge ──────────────────────────────────────────────────────────────

class _StaffBadge extends StatelessWidget {
  final String label;
  final String name;
  final IconData icon;
  final Color color;

  const _StaffBadge({
    required this.label,
    required this.name,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade400,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Line item row ────────────────────────────────────────────────────────────

class _LineItemRow extends StatelessWidget {
  final _OrderLineItem item;
  final bool isLast;

  const _LineItemRow({required this.item, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(LucideIcons.package, size: 16, color: Colors.orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.productName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'x${item.quantity}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Status chip ──────────────────────────────────────────────────────────────

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