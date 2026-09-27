import 'dart:async';
import 'package:flutter/material.dart';
import '../data/inventory.dart';
import '../logic/inventory_controller.dart';
import 'scanner_search_page.dart';

class OrderQueuePage extends StatefulWidget {
  final InventoryController controller;
  const OrderQueuePage({super.key, required this.controller});

  @override
  State<OrderQueuePage> createState() => _OrderQueuePageState();
}

class _OrderQueuePageState extends State<OrderQueuePage> {
  Timer? _timer;
  Duration? _timeOffset;
  final Set<String> _expandedOrders = {};

  // Track the selected order to show the checklist inline (keeps the sidebar visible!)
  dynamic _selectedOrder;

  List<dynamic> _cachedOrders = [];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _timeAgo(DateTime date) {
    var now = DateTime.now();
    if (date.isAfter(now)) {
      final drift = date.difference(now);
      if (_timeOffset == null || drift > _timeOffset!) {
        _timeOffset = drift;
      }
    }
    if (_timeOffset != null) {
      now = now.add(_timeOffset!);
    }
    final diff = now.difference(date);
    final minutes = diff.inMinutes;
    if (minutes < 1) return 'Just now';
    if (minutes < 60) return '${minutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _toggleExpand(String orderId) {
    setState(() {
      if (_expandedOrders.contains(orderId)) {
        _expandedOrders.remove(orderId);
      } else {
        _expandedOrders.add(orderId);
      }
    });
  }

  void _openOrderChecklist(dynamic order) {
    // Renders the checklist inline so the sidebar doesn't disappear
    setState(() {
      _selectedOrder = order;
    });
  }

  void _closeOrderChecklist() {
    setState(() {
      _selectedOrder = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // IF AN ORDER IS SELECTED, SHOW THE INLINE CHECKLIST
    if (_selectedOrder != null) {
      return OrderChecklistPage(
        order: _selectedOrder,
        controller: widget.controller,
        onBack: _closeOrderChecklist,
      );
    }

    // OTHERWISE, SHOW THE LIST
    return Scaffold(
      backgroundColor: Colors.white, // Plain white background
      appBar: AppBar(
        automaticallyImplyLeading: false, // <--- ADD THIS FIX HERE
        title: const Text(
          'Helper Dashboard',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent, // Keeps it seamless with white
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: StreamBuilder<List<dynamic>>(
        stream: widget.controller.streamOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _cachedOrders.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFF58220)),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.hasData) {
            _cachedOrders = snapshot.data!;
          }

          final pendingOrders =
              _cachedOrders.where((o) => o.status == 'pending').toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatCard(
                  "ACTIVE QUEUE",
                  "${pendingOrders.length}",
                  const Color(0xFFD67E24),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: pendingOrders.isEmpty
                      ? const Center(
                          child: Text(
                            'No pending orders right now!',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: pendingOrders.length,
                          itemBuilder: (context, index) {
                            final order = pendingOrders[index];
                            return _OrderCard(
                              key: ValueKey(order.id),
                              order: order,
                              controller: widget.controller,
                              isExpanded: _expandedOrders.contains(order.id),
                              onToggle: () => _toggleExpand(order.id),
                              timeAgo: _timeAgo(order.createdAt),
                              onPrepare: () => _openOrderChecklist(order),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFBEADB), // Restored original peach color
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3E322C),
            ),
          ),
          const SizedBox(height: 4),
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
    );
  }
}

class _OrderCard extends StatelessWidget {
  final dynamic order;
  final InventoryController controller;
  final bool isExpanded;
  final VoidCallback onToggle;
  final String timeAgo;
  final VoidCallback onPrepare;

  const _OrderCard({
    super.key,
    required this.order,
    required this.controller,
    required this.isExpanded,
    required this.onToggle,
    required this.timeAgo,
    required this.onPrepare,
  });

  @override
  Widget build(BuildContext context) {
    final String shortId = order.id.toString().substring(0, 8).toUpperCase();

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isExpanded ? const Color(0xFFF58220) : Colors.grey.shade200,
          ),
          boxShadow: isExpanded
              ? [
                  BoxShadow(
                    color: const Color(0xFFF58220).withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#ORD-$shortId',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${order.items.length} item${order.items.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            timeAgo,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: onPrepare,
                    behavior: HitTestBehavior.opaque,
                    child: ElevatedButton(
                      onPressed: onPrepare,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF58220),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'Prepare',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              child: isExpanded
                  ? _ExpandedItems(order: order, controller: controller)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandedItems extends StatelessWidget {
  final dynamic order;
  final InventoryController controller;

  const _ExpandedItems({required this.order, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
        ...order.items.map<Widget>((item) {
          String locationLabel = 'Unassigned';
          try {
            final dbItem = controller.allItems.firstWhere(
              (i) => i.id == item.productId,
            );
            final parts = <String>[];
            if (dbItem.shelfLevel != null && dbItem.shelfLevel!.isNotEmpty) {
              parts.add('Shelf ${dbItem.shelfLevel}');
            }
            if (dbItem.binNumber != null && dbItem.binNumber!.isNotEmpty) {
              parts.add('Bin ${dbItem.binNumber}');
            }
            if (parts.isNotEmpty) locationLabel = parts.join(' • ');
          } catch (_) {}

          return AnimatedOpacity(
            opacity: 1.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBEADB), // Restored peach
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'x${item.quantity.toInt()}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF9E651D), // Restored orange/brown
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 11,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              locationLabel,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
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
        }),
      ],
    );
  }
}

// ============================================================================
// INLINE CHECKLIST PAGE
// ============================================================================
class OrderChecklistPage extends StatefulWidget {
  final dynamic order;
  final InventoryController controller;
  final VoidCallback onBack;

  const OrderChecklistPage({
    super.key,
    required this.order,
    required this.controller,
    required this.onBack,
  });

  @override
  State<OrderChecklistPage> createState() => _OrderChecklistPageState();
}

class _OrderChecklistPageState extends State<OrderChecklistPage> {
  // Using a Set of indices guarantees we track completion perfectly
  final Set<int> _checkedIndices = {};

  bool get _allChecked =>
      _checkedIndices.length == widget.order.items.length &&
      widget.order.items.isNotEmpty;
  int get _checkedCount => _checkedIndices.length;
  int get _totalCount => widget.order.items.length;

  void _markPrepared() async {
    await widget.controller.updateOrderStatus(widget.order.id, 'prepared');
    if (mounted) {
      widget.onBack();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order marked as Prepared!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showPickConfirmationSheet(
    InventoryItem dbItem,
    double targetQuantity,
    int listIndex,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PickConfirmationSheet(
        item: dbItem,
        targetQuantity: targetQuantity,
        onConfirm: () async {
          if (mounted) {
            setState(() {
              _checkedIndices.add(listIndex);
            });
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${dbItem.name} checked off!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
    );
  }

  void _openScannerToCheckoff(int index, String expectedProductId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScannerSearchPage(
          controller: widget.controller,
          onSelectItem: (scannedItem) {
            Navigator.pop(context); // Close scanner
            if (scannedItem.id == expectedProductId) {
              _showPickConfirmationSheet(
                scannedItem,
                widget.order.items[index].quantity,
                index,
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${scannedItem.name} is not the right item!'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  void _showTutorialModal() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.orange),
            SizedBox(width: 10),
            // FIX: Wrap Text in Expanded to prevent right overflow
            Expanded(
              child: Text("How to Prepare an Order"),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("1. Tap any item in the list to open the QR scanner."),
            SizedBox(height: 8),
            Text("2. Scan the QR code on the Shelf."),
            SizedBox(height: 8),
            Text("3. Confirm the pick to check it off the list."),
            SizedBox(height: 16),
            Text(
              "Once all items are checked, the 'Notify Cashier' button will be enabled.",
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Got it!",
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String shortId = widget.order.id
        .toString()
        .substring(0, 8)
        .toUpperCase();
    final double progress = _totalCount == 0 ? 0 : _checkedCount / _totalCount;

    return Scaffold(
      backgroundColor: Colors.white, // Plain White Background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: widget.onBack,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "ORDER ASSIGNMENT",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "ID: #ORD-$shortId",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        InkWell(
                          onTap: _showTutorialModal,
                          child: const CircleAvatar(
                            radius: 14,
                            backgroundColor: Color(0xFF3E322C),
                            child: Icon(
                              Icons.question_mark,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _allChecked
                                ? Colors.green.shade100
                                : const Color(0xFFFBEADB),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "$_checkedCount/$_totalCount",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _allChecked ? Colors.green.shade900 : const Color(0xFF9E651D),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    backgroundColor: const Color(
                      0xFFFBEADB,
                    ), // Restored peach background
                    color: _allChecked
                        ? Colors.green
                        : const Color(
                            0xFFF58220,
                          ), // Orange initially, GREEN on success!
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _allChecked ? "ALL ITEMS PICKED" : "READY FOR PICKING",
                  style: TextStyle(
                    color: _allChecked ? Colors.green : Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: widget.order.items.length,
              itemBuilder: (context, index) {
                final item = widget.order.items[index];
                final bool isChecked = _checkedIndices.contains(index);

                // FIX: Determine the correct color based on the overall progress.
                // If all items are checked, everything turns green. Otherwise, checked
                // items are orange.
                final Color activeColor = _allChecked ? Colors.green : const Color(0xFFF58220);

                InventoryItem? dbItem;
                try {
                  dbItem = widget.controller.allItems.firstWhere(
                    (i) => i.id == item.productId,
                  );
                } catch (_) {}

                String locationString = "UNASSIGNED";
                if (dbItem != null) {
                  final parts = <String>[];
                  if (dbItem.shelfLevel != null &&
                      dbItem.shelfLevel!.isNotEmpty) {
                    parts.add("Shelf ${dbItem.shelfLevel}");
                  }
                  if (dbItem.binNumber != null &&
                      dbItem.binNumber!.isNotEmpty) {
                    parts.add("Bin ${dbItem.binNumber}");
                  }
                  if (parts.isNotEmpty) {
                    locationString = parts.join(" • ").toUpperCase();
                  }
                }

                return GestureDetector(
                  onTap: () {
                    if (!isChecked) {
                      _openScannerToCheckoff(index, item.productId);
                    } else {
                      setState(() {
                        _checkedIndices.remove(index);
                      });
                    }
                  },
                  onLongPress: () {
                    // Manual override just so you can test the green logic quickly!
                    setState(() {
                      if (isChecked)
                        _checkedIndices.remove(index);
                      else
                        _checkedIndices.add(index);
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isChecked ? const Color(0xFFE8F5E9) : Colors.white,
                      border: Border.all(
                        color: isChecked
                            ? const Color(0xFFC8E6C9)
                            : Colors.grey.shade300,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isChecked ? activeColor : Colors.white,
                            border: Border.all(
                              color:
                                  isChecked ? activeColor : Colors.grey.shade400,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: isChecked
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.black87,
                                  decoration: isChecked
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                ),
                                child: Text(item.productName),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isChecked ? activeColor : const Color(0xFFFBEADB),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'QTY: ${item.quantity}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isChecked ? Colors.white : const Color(0xFF9E651D),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      locationString,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
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
          ),
          Container(
            padding: const EdgeInsets.all(20),
            color: _allChecked ? Colors.green.shade50 : const Color(0xFFF8E9DE),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _allChecked ? _markPrepared : null,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text(
                  "NOTIFY CASHIER (PREPARED)",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                style:
                    ElevatedButton.styleFrom(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ).copyWith(
                      backgroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        if (states.contains(WidgetState.disabled)) {
                          return const Color(
                            0xFFDAC7B8,
                          ); // Original disabled color
                        }
                        return Colors
                            .green; // Turn GREEN when active (success state!)
                      }),
                      foregroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        if (states.contains(WidgetState.disabled)) {
                          return Colors.white70; // Original disabled text
                        }
                        return Colors.white;
                      }),
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PICK CONFIRMATION SHEET
// ============================================================================
class PickConfirmationSheet extends StatelessWidget {
  final InventoryItem item;
  final double targetQuantity;
  final VoidCallback onConfirm;

  const PickConfirmationSheet({
    super.key,
    required this.item,
    required this.targetQuantity,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    String locationString = "Unassigned";
    if (item.shelfLevel != null || item.binNumber != null) {
      final parts = <String>[];
      if (item.shelfLevel != null && item.shelfLevel!.isNotEmpty) {
        parts.add("Shelf ${item.shelfLevel}");
      }
      if (item.binNumber != null && item.binNumber!.isNotEmpty) {
        parts.add("Bin ${item.binNumber}");
      }
      if (parts.isNotEmpty) locationString = parts.join(" • ");
    }

    final String displayQty =
        targetQuantity.truncateToDouble() == targetQuantity
        ? targetQuantity.toInt().toString()
        : targetQuantity.toStringAsFixed(2);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 12),
            const Text(
              "Item Verified!",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: NetworkImage(item.imageUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "SKU-${item.sku}",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.shopping_basket,
                    color: Colors.green.shade700,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          color: Colors.green.shade900,
                          fontSize: 14,
                          height: 1.4,
                        ),
                        children: [
                          const TextSpan(text: "Please pick exactly "),
                          TextSpan(
                            text: "$displayQty ${item.unit}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          TextSpan(text: "\nLocation: $locationString"),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text(
                  "Confirm Pick",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, // Green by default here
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
