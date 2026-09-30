import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/inventory.dart';
import '../logic/inventory_controller.dart';

// Your UI Pages
import 'profile_info_page.dart';
import 'inventory_page.dart';
import 'item_detail_page.dart';
import 'dashboard_page.dart';
import 'pos_cart_page.dart';
import 'order_queue_page.dart';
import 'transaction_history_page.dart';
import 'system_settings_page.dart';

class MainScreen extends StatefulWidget {
  final InventoryController controller;
  const MainScreen({super.key, required this.controller});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int? _currentIndex;
  bool _isDetailView = false;
  InventoryItem? _selectedItem;
  String _txTargetTab = 'Sales History';
  String? _targetOrderId;
  // --- DESKTOP COLOR PALETTE ---
  static const Color _primaryOrange = Color(0xFFEA580C);
  static const Color _darkSidebarBg = Color(0xFF0F172A);
  static const Color _mainBg = Color(0xFFF1F5F9);

  // --- REUSABLE PAGE FUNCTIONS ---
  void _handleSelectItem(InventoryItem item) {
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (dialogContext) => Dialog(
          // <- was (context)
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 500,
            height: 700,
            child: ItemDetailPage(
              item: item,
              controller: widget.controller,
              onBack: () => Navigator.pop(dialogContext),
              onUpdate: (updatedItem) async {
                await widget.controller.updateItem(updatedItem);
                if (mounted) setState(() {});
              },
              onDelete: (id) async {
                await widget.controller.deleteItem(id);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) setState(() {});
              },
            ),
          ),
        ),
      );
    } else {
      setState(() {
        _selectedItem = item;
        _isDetailView = true;
      });
    }
  }

  void _handleBackToMain() {
    setState(() {
      _isDetailView = false;
      _selectedItem = null;
    });
  }

  Future<void> _handleUpdateItem(InventoryItem item) async {
    await widget.controller.updateItem(item);
    if (mounted) {
      setState(() {
        _selectedItem = item;
      });
    }
  }

  Future<void> _handleDeleteItem(String id) async {
    await widget.controller.deleteItem(id);
    if (!mounted) return;
    setState(() {
      _isDetailView = false;
      _selectedItem = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.currentUserId == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(color: Colors.orange),
        ),
      );
    }

    if (_isDetailView && _selectedItem != null) {
      return ItemDetailPage(
        item: _selectedItem!,
        controller: widget.controller,
        onBack: _handleBackToMain,
        onUpdate: _handleUpdateItem,
        onDelete: _handleDeleteItem,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 600;
        final role = widget.controller.currentUserRole?.toLowerCase() ?? 'staff';
        final isAdmin = role == 'admin';
        final isCashier = role == 'staff';
        final isHelper = role == 'helper';

        _currentIndex ??= 0;

        // 2. DYNAMIC INDICES BASED ON ROLE (Settings Removed)
        int pageIndex = 0;
        final int dashboardIndex = isAdmin ? pageIndex++ : -1;
        final int posIndex = (isCashier || isAdmin) ? pageIndex++ : -1;
        final int orderQueueIndex = (isHelper || isAdmin) ? pageIndex++ : -1;
        final int inventoryIndex = pageIndex++;
        final int transactionIndex = isAdmin ? pageIndex++ : -1;
        final int system_settings_page = isAdmin? pageIndex++ : -1;

        final pages = <Widget>[];
                 
        if (isAdmin) {
          pages.add(DashboardPage(
            controller: widget.controller,
            onViewTransactions: () {
              setState(() {
                _txTargetTab = 'Sales History'; 
                _currentIndex = transactionIndex;
              });
            },
            onOpenQueue: () { 
              setState(() {
                _currentIndex = orderQueueIndex; 
              });
            },
            onViewActivity: () { 
              setState(() {
                _txTargetTab = 'Activity Log'; 
                _currentIndex = transactionIndex;
              });
            },
          ));
        }
        if (isCashier || isAdmin) {
          pages.add(PosCartPage(controller: widget.controller));
        }
       if (isHelper || isAdmin) {
          pages.add(
            OrderQueuePage(
              controller: widget.controller,
              targetOrderId: _targetOrderId,
              onOrderOpened: () {
                if (mounted) setState(() => _targetOrderId = null);
              },
            ),
          );
        }
        
        pages.add(
          InventoryPage(
            controller: widget.controller,
            onSelectItem: _handleSelectItem,
          )
        );

        if (isAdmin) {
          pages.add(
            TransactionHistoryPage(
              controller: widget.controller,
              initialTab: _txTargetTab,
              onCompleteOrder: (orderId) {
                setState(() {
                  _targetOrderId = orderId;
                  _currentIndex = orderQueueIndex;
                });
              },
            ),
          );
        } 

        if (isAdmin) {
          pages.add(SystemSettingsPage(controller: widget.controller));
        }

        // ==========================================
        // DESKTOP LAYOUT (Sidebar)
        // ==========================================
        if (isDesktop) {
          return Scaffold(
            backgroundColor: _mainBg,
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 240,
                  color: _darkSidebarBg,
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView( 
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 30.0,
                                  vertical: 40.0,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.inventory_2_rounded,
                                      color: _primaryOrange,
                                      size: 28,
                                    ),
                                    SizedBox(width: 16),
                                    Text(
                                      'Inventory Plus',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isAdmin)
                                _buildSidebarItem(
                                  dashboardIndex,
                                  Icons.dashboard_outlined,
                                  'Dashboard',
                                  activeIcon: Icons.dashboard,
                                ),
                              if (isCashier || isAdmin)
                                _buildSidebarItem(
                                  posIndex,
                                  Icons.point_of_sale_outlined,
                                  'POS System',
                                  activeIcon: Icons.point_of_sale,
                                ),
                              if (isHelper || isAdmin)
                                _buildSidebarItem(
                                  orderQueueIndex,
                                  Icons.receipt_long_outlined,
                                  'Order Queue',
                                  activeIcon: Icons.receipt_long,
                                ),
                              _buildSidebarItem(
                                inventoryIndex,
                                Icons.inventory_2_outlined,
                                'Inventory',
                                activeIcon: Icons.inventory_2,
                              ),
                              if (isAdmin)
                                _buildSidebarItem(
                                  transactionIndex,
                                  Icons.history_outlined,
                                  'Transactions',
                                  activeIcon: Icons.history,
                                ),
                              if (isAdmin)
                                _buildSidebarItem(
                                  system_settings_page, // The index variable from your code
                                  Icons.settings_outlined,
                                  'System Settings',
                                  activeIcon: Icons.settings,
                                ),
                            ],
                          ),
                        ),
                      ),
                      _buildProfileTile(),
                    ],
                  ),
                ),
                Expanded(
                  child: IndexedStack(index: _currentIndex, children: pages),
                ),
              ],
            ),
          );
        }

        // ==========================================
        // MOBILE LAYOUT (Bottom Navigation)
        // ==========================================

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: _darkSidebarBg,
            toolbarHeight: 70, 
            elevation: 0,
            titleSpacing: 0,
            title: _buildProfileTile(), 
          ),
          body: IndexedStack(index: _currentIndex, children: pages),
          bottomNavigationBar: NavigationBarTheme(
            data: NavigationBarThemeData(
              indicatorColor: Colors.orange,
              labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
                (Set<WidgetState> states) {
                  if (states.contains(WidgetState.selected)) {
                    return const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12);
                  }
                  return const TextStyle(color: Colors.grey, fontSize: 12);
                },
              ),
            ),
            child: NavigationBar(
              backgroundColor: _darkSidebarBg,
              selectedIndex: _currentIndex!,
              onDestinationSelected: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              destinations: [
                if (isAdmin)
                  const NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined, color: Colors.grey),
                    selectedIcon: Icon(Icons.dashboard, color: Colors.white),
                    label: 'Dashboard',
                  ),
                if (isCashier || isAdmin)
                  const NavigationDestination(
                    icon: Icon(Icons.point_of_sale_outlined, color: Colors.grey),
                    selectedIcon: Icon(Icons.point_of_sale, color: Colors.white),
                    label: 'POS',
                  ),
                if (isHelper || isAdmin)
                  const NavigationDestination(
                    icon: Icon(Icons.receipt_long_outlined, color: Colors.grey),
                    selectedIcon: Icon(Icons.receipt_long, color: Colors.white),
                    label: 'Queue',
                  ),
                const NavigationDestination(
                  icon: Icon(Icons.assignment_outlined, color: Colors.grey),
                  selectedIcon: Icon(Icons.assignment, color: Colors.white),
                  label: 'Inventory',
                ),
                if (isAdmin)
                  const NavigationDestination(
                    icon: Icon(Icons.history_outlined, color: Colors.grey),
                    selectedIcon: Icon(Icons.history, color: Colors.white),
                    label: 'History',
                  ),
                if (isAdmin)
                  const NavigationDestination(
                    icon: Icon(Icons.settings_outlined, color: Colors.grey),
                    selectedIcon: Icon(Icons.settings, color: Colors.white),
                    label: 'Settings',
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSidebarItem(
    int index,
    IconData icon,
    String label, {
    IconData? activeIcon,
  }) {
    final isSelected = _currentIndex == index;
    final currentColor = isSelected ? _primaryOrange : const Color(0xFF94A3B8);

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
        color: isSelected
            ? _primaryOrange.withOpacity(0.05)
            : Colors.transparent,
        child: Row(
          children: [
            Icon(
              isSelected ? (activeIcon ?? icon) : icon,
              color: currentColor,
              size: 28,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: currentColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Update 1: Replace _handleLogout to show a confirmation dialog.
  void _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Log Out"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Log Out", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  Widget _buildProfileTile() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        hoverColor: Colors.white.withOpacity(0.05),
        onTap: () {
          final isDesktop = MediaQuery.of(context).size.width >= 600;
          final profilePage = ProfileInfoPage(
            controller: widget.controller,
            currentName: widget.controller.currentUserName ?? "Unknown",
            currentEmail: widget.controller.loggedInUserEmail,
            userId: widget.controller.currentUserId ?? "",
            role: widget.controller.currentUserRole ?? "staff",
          );
      
          if (isDesktop) {
            showDialog(
              context: context,
              builder: (context) => Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(width: 500, height: 600, child: profilePage),
              ),
            );
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (context) => profilePage));
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Colors.white10)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.orange.withOpacity(0.2),
                child: Text(
                  widget.controller.currentUserName?[0].toUpperCase() ?? 'U',
                  style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.controller.currentUserName ?? "Unknown User",
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "ID: ${widget.controller.currentUserId}",
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.logOut, color: Colors.redAccent, size: 20),
                onPressed: _handleLogout,
                tooltip: "Logout",
              ),
            ],
          ),
        ),
      ),
    );
  }
}