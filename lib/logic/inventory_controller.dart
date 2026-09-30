import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import '../data/inventory.dart';
import 'dart:math' as math;
enum StockStatus { ok, low, critical, out }

class InventoryController {
  final SupabaseClient supabase = Supabase.instance.client;
  int? currentUserNumericId;
  List<InventoryItem> _items = [];
  String? activeLocationId;
  String? currentUserRole;
  String? currentUserName;
  String? currentUserId;
  String? loggedInUserEmail;
  bool get isAdmin => currentUserRole?.toLowerCase() == 'admin';
  double globalLowStockPct = 20.0;
  double globalCriticalPct = 10.0;
  List<Map<String, dynamic>> availableMeasurements = [];

  static const int _baselineRestocks = 3;
  static const int _baselineWindowDays = 180;
  Map<String, double> _baselineByProduct = {};

  Future<void> _loadStockBaselines() async {
    final locId = activeLocationId;
    if (locId == null) return;
    try {
      final cutoff = DateTime.now()
          .subtract(const Duration(days: _baselineWindowDays))
          .toIso8601String();

      final res = await supabase
          .from('transaction_history')
          .select('product_id, new_quantity, created_at')
          .eq('location_id', locId)
          .inFilter('transaction_type', ['add', 'stock_in'])
          .gte('created_at', cutoff)
          .order('created_at', ascending: false);

      final Map<String, List<double>> levels = {};
      for (final row in List<Map<String, dynamic>>.from(res)) {
        final pid = row['product_id']?.toString();
        if (pid == null) continue;
        final list = levels.putIfAbsent(pid, () => []);
        if (list.length < _baselineRestocks) {
          list.add((row['new_quantity'] as num).toDouble());
        }
      }
      _baselineByProduct = {
        for (final e in levels.entries) e.key: e.value.reduce(math.max),
      };
    } catch (e) {
      print("Error loading stock baselines: $e");
    }
  }

  double baselineFor(InventoryItem item) =>
      math.max(item.quantity, _baselineByProduct[item.id] ?? item.maxQuantity);

  double stockPercentFor(InventoryItem item) {
    final base = baselineFor(item);
    return base <= 0 ? 100 : (item.quantity / base) * 100;
  }

  StockStatus stockStatusFor(InventoryItem item) {
    if (item.quantity <= 0) return StockStatus.out;
    final pct = stockPercentFor(item);
    if (pct <= globalCriticalPct) return StockStatus.critical;
    if (pct <= globalLowStockPct) return StockStatus.low;
    return StockStatus.ok;
  }
  

  List<InventoryItem> get allItems => _items;

  void setLoggedInUser({
    required String name,
    required String id,
    required String role,
    String? email,
  }) {
    currentUserName = name;
    currentUserId = id;
    currentUserRole = role;
    currentUserNumericId = int.tryParse(id);
    loggedInUserEmail = email;
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<void> loadSystemSettings() async {
    try {
      // 1. Fetch thresholds (same row that updateGlobalThresholds writes: id = 1)
      final thresholdRes = await supabase
          .from('threshold')
          .select('low_stock, critical')
          .eq('id', 1)
          .maybeSingle();

      if (thresholdRes != null) {
        globalLowStockPct = (thresholdRes['low_stock'] as num).toDouble();
        globalCriticalPct = (thresholdRes['critical'] as num).toDouble();
      }

      // 2. Fetch measurements
      final measureRes = await supabase
          .from('measurements')
          .select('id, name, symbol');

      availableMeasurements = List<Map<String, dynamic>>.from(measureRes);
    } catch (e) {
      print("Error loading system settings: $e");
      rethrow; // callers decide how to show the error
    }
  }

  Future<void> updateGlobalThresholds(double low, double critical) async {
    try {
      await supabase.from('threshold').upsert({
        'id': 1, // Assuming row ID 1 for global settings
        'low_stock': low,
        'critical': critical,
      });
      globalLowStockPct = low;
      globalCriticalPct = critical;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addMeasurement(String name, String symbol) async {
    try {
      final response = await supabase
          .from('measurements')
          .insert({'name': name, 'symbol': symbol})
          .select()
          .single();

      availableMeasurements.add(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateMeasurement(String id, String name, String symbol) async {
    try {
      final response = await supabase
          .from('measurements')
          .update({'name': name, 'symbol': symbol})
          .eq('id', id)
          .select()
          .single();

      final index = availableMeasurements.indexWhere(
        (m) => m['id'].toString() == id,
      );
      if (index != -1) {
        availableMeasurements[index] = response;
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteMeasurement(String id) async {
    try {
      await supabase.from('measurements').delete().eq('id', id);
      availableMeasurements.removeWhere((m) => m['id'].toString() == id);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> loadAppData(String userLocationId) async {
    activeLocationId = userLocationId;

    try {
      final productsResponse = await supabase
          .from('products')
          .select()
          .eq('location_id', userLocationId);

      _items = (productsResponse as List)
          .map((p) => InventoryItem.fromSupabase(p))
          .toList();

      await _loadStockBaselines();  
    } catch (e) {
      _items = [];
    }
  }

  Future<void> addItem(InventoryItem newItem) async {
    final locId = activeLocationId;
    if (locId == null) {
      return;
    }

    try {
      final response = await supabase
          .from('products')
          .insert({
            'sku': newItem.sku,
            'product_name': newItem.name,
            'category': newItem.category,
            'product_price': newItem.price,
            'product_quantity': newItem.quantity,
            'description': newItem.description,
            'image_url': newItem.imageUrl,
            'location_id': locId,
            'manufacturer': newItem.manufacturer,
            'model': newItem.model,
            'product_size': newItem.productSize,
            'shelf_level': newItem.shelfLevel,
            'bin_number': newItem.binNumber,
            'unit': newItem.unit,
            'max_quantity': newItem.maxQuantity,
          })
          .select()
          .single();

      final savedItem = InventoryItem.fromSupabase(response);
      _items.add(savedItem);
      _baselineByProduct[savedItem.id] = savedItem.quantity; 

      await _logTransaction(
        productId: savedItem.id,
        type: 'add',
        quantityChange: savedItem.quantity,
        newQuantity: savedItem.quantity,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _logTransaction({
    String? productId,
    required String type,
    required double quantityChange,
    required double newQuantity,
  }) async {
    final locId = activeLocationId;
    final userId = currentUserId;
    final userName = currentUserName ?? 'Unknown User';

    if (locId == null || userId == null) return;
    try {
      final Map<String, dynamic> insertData = {
        'product_id': productId,
        'transaction_type': type,
        'quantity_change': quantityChange,
        'new_quantity': newQuantity,
        'location_id': locId,
        'user_id': int.tryParse(userId) ?? userId,
        'user_name': userName,
      };

      await supabase.from('transaction_history').insert(insertData);
    } catch (e) {}
  }

  Future<String?> uploadProductImage(File imageFile, String fileName) async {
    try {
      final path = 'public/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      await supabase.storage.from('product_images').upload(path, imageFile);
      return supabase.storage.from('product_images').getPublicUrl(path);
    } catch (e) {
      return null;
    }
  }

  Future<String?> uploadImageBytes(
    Uint8List imageBytes,
    String fileName,
  ) async {
    try {
      final path = 'public/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      await supabase.storage
          .from('product_images')
          .uploadBinary(path, imageBytes);
      return supabase.storage.from('product_images').getPublicUrl(path);
    } catch (e) {
      return null;
    }
  }

  Future<void> updateItem(InventoryItem updatedItem) async {
    final index = _items.indexWhere((item) => item.id == updatedItem.id);
    final oldItem = index != -1 ? _items[index] : null;

    // 1. Write to the DB first. If this throws, nothing local has changed.
    await supabase
        .from('products')
        .update({
          'product_name': updatedItem.name,
          'sku': updatedItem.sku,
          'product_price': updatedItem.price,
          'product_quantity': updatedItem.quantity,
          'description': updatedItem.description,
          'manufacturer': updatedItem.manufacturer,
          'model': updatedItem.model,
          'product_size': updatedItem.productSize,
          'shelf_level': updatedItem.shelfLevel,
          'bin_number': updatedItem.binNumber,
          'image_url': updatedItem.imageUrl,
          'unit': updatedItem.unit,
          'max_quantity': updatedItem.maxQuantity,
        })
        .eq('id', updatedItem.id);

    // 2. Only after success: update local state, log, refresh baselines.
    if (index != -1 && oldItem != null) {
      final quantityChange = updatedItem.quantity - oldItem.quantity;
      _items[index] = updatedItem;

      if (quantityChange != 0) {
        await _logTransaction(
          productId: updatedItem.id,
          type: quantityChange > 0 ? 'stock_in' : 'checkout',
          quantityChange: quantityChange,
          newQuantity: updatedItem.quantity,
        );
        if (quantityChange > 0) await _loadStockBaselines();
      }
    }
  }

  Future<void> deleteItem(String id) async {
    final index = _items.indexWhere((item) => item.id == id);
    await supabase.from('products').delete().eq('id', id); // throws on failure

    if (index != -1) {
      final itemToDelete = _items[index];
      _items.removeAt(index);
      await _logTransaction(
        productId: null,
        type: 'delete',
        quantityChange: -itemToDelete.quantity,
        newQuantity: 0,
      );
    }
  }

  Future<void> updateItemLocationDetails(
    String itemId, {
    required int shelf,
    required String layer,
  }) async {
    try {
      await supabase
          .from('products')
          .update({
            'shelf_level': shelf.toString(),
            'bin_number': layer,
          })
          .eq('id', itemId);

      final index = _items.indexWhere((item) => item.id == itemId);
      if (index != -1) {
        _items[index] = _items[index].copyWith(
          shelfLevel: shelf.toString(),
          binNumber: layer,
        );
      }
    } catch (e) {}
  }

  List<InventoryItem> get unassignedItems =>
      _items.where((item) => item.shelfLevel == null || item.shelfLevel!.isEmpty).toList();

  List<InventoryItem> filterInventory({
    required String query,
    required String category,
  }) {
    final filtered = _items.where((item) {
      final matchesSearch =
          item.name.toLowerCase().contains(query.toLowerCase()) ||
          item.sku.toLowerCase().contains(query.toLowerCase());

      final matchesCategory =
          category == 'All' ||
          (category == 'Unassigned' && (item.shelfLevel == null || item.shelfLevel!.isEmpty)) ||
          item.category == category;

      return matchesSearch && matchesCategory;
    }).toList();

    filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return filtered;
  }

  List<String> getUniqueCategories() {
    final categories = _items.map((item) => item.category).toSet().toList();
    categories.sort();
    return ['All', 'Unassigned', ...categories];
  }

  InventoryItem prepareUpdatedItem({
    required InventoryItem originalItem,
    required String newName,
    required String newSku,
    required String newPrice,
    required String newStock,
    required String newMaxStock,
    required String newDesc,
    String? manufacturer,
    String? model,
    String? productSize,
    String? shelfLevel,
    String? binNumber,
    String? imageUrl,
    String? unit,
  }) {
    return originalItem.copyWith(
      name: newName,
      sku: newSku,
      price: double.tryParse(newPrice) ?? originalItem.price,
      quantity: double.tryParse(newStock) ?? originalItem.quantity,
      maxQuantity: double.tryParse(newMaxStock) ?? originalItem.maxQuantity,
      description: newDesc,
      manufacturer: manufacturer,
      model: model,
      productSize: productSize,
      shelfLevel: shelfLevel,
      binNumber: binNumber,
      imageUrl: imageUrl,
      unit: unit,
    );
  }

  InventoryItem createNewItem({
    required String name,
    required String sku,
    required String price,
    required String quantity,
    required String maxQuantity,
    required String category,
    required String description,
    String? manufacturer,
    String? model,
    String? productSize,
    String? shelfLevel,
    String? binNumber,
    String? imageUrl,
    String unit = 'pcs',
  }) {
    double parsedQty = double.tryParse(quantity) ?? 0.0;
    double parsedMax = double.tryParse(maxQuantity) ?? parsedQty;

    return InventoryItem(
      id: '',
      name: name,
      sku: sku,
      price: double.tryParse(price) ?? 0.0,
      quantity: parsedQty,
       maxQuantity: parsedMax == 0 ? parsedQty : parsedMax,
      category: category,
      description: description,
      manufacturer: manufacturer,
      model: model,
      productSize: productSize,
      shelfLevel: shelfLevel,
      binNumber: binNumber,
      imageUrl: imageUrl ?? '',
      unit: unit,
    );
  }

  InventoryItem calculateCheckout(InventoryItem item, double quantity) {
    return item.copyWith(
      quantity: (item.quantity - quantity).clamp(0.0, 999999.0),
    );
  }

  InventoryItem? findItemByCode(String code) {
    try {
      return _items.firstWhere((item) => item.sku.trim() == code.trim());
    } catch (e) {
      return null;
    }
  }

  List<InventoryItem> searchInventory(String query) {
    if (query.isEmpty) return _items;

    final lowercaseQuery = query.toLowerCase();
    return _items.where((item) {
      return item.name.toLowerCase().contains(lowercaseQuery) ||
          item.sku.toLowerCase().contains(lowercaseQuery) ||
          item.category.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchStaff() async {
    final locId = activeLocationId;
    if (locId == null) return [];
    try {
      final response = await supabase
          .from('profiles')
          .select()
          .eq('location_id', locId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<bool> createStaff({
    required String name,
    required String username,
    required String password,
    required String role,
    String? email,
    String? phone,
    String? address,
  }) async {
    final locId = activeLocationId;
    if (locId == null) return false;
    try {
      final hashedPassword = _hashPassword(password);

      await supabase.from('profiles').insert({
        'name': name,
        'username': username,
        'password': hashedPassword,
        'role': role,
        'location_id': locId,
        'email': email,
        'phone': phone,
        'address': address,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateStaffRole(String id, String newRole) async {
    try {
      await supabase.from('profiles').update({'role': newRole}).eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteStaff(String id) async {
    try {
      await supabase.from('profiles').delete().eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    if (currentUserId == null) return "User not logged in.";
    try {
      final hashedCurrentPassword = _hashPassword(currentPassword);
      final hashedNewPassword = _hashPassword(newPassword);

      final response = await supabase
          .from('profiles')
          .select('password')
          .eq('id', currentUserId!)
          .single();

      if (response['password'] != hashedCurrentPassword) {
        return "Incorrect current password.";
      }

      await supabase
          .from('profiles')
          .update({'password': hashedNewPassword})
          .eq('id', currentUserId!);
      return null;
    } catch (e) {
      return "An error occurred while changing the password.";
    }
  }

  Future<List<Map<String, dynamic>>> fetchTransactionHistory(
    String productId,
  ) async {
    try {
      final response = await supabase
          .from('transaction_history')
          .select('*, profiles(name, role)')
          .eq('product_id', productId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllTransactionHistory() async {
    final locId = activeLocationId;
    if (locId == null) return [];
    try {
      final response = await supabase
          .from('transaction_history')
          .select('*, products(product_name, sku), profiles(name, role)')
          .eq('location_id', locId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<void> clearTransactionHistory() async {
    final locId = activeLocationId;
    if (locId == null) return;
    try {
      await supabase
          .from('transaction_history')
          .delete()
          .eq('location_id', locId);
    } catch (e) {}
  }

  Future<List<Map<String, dynamic>>> generateInventoryAnalytics({
    int days = 30,
    int leadTimeDays = 7,
  }) async {
    final locId = activeLocationId;
    if (locId == null) return [];

    try {
      final cutoffDate = DateTime.now()
          .subtract(Duration(days: days))
          .toIso8601String();

      final response = await supabase
          .from('transaction_history')
          .select('product_id, quantity_change, created_at')
          .eq('location_id', locId)
          .eq('transaction_type', 'checkout')
          .gte('created_at', cutoffDate);

      final transactions = List<Map<String, dynamic>>.from(response);

      Map<String, int> salesData = {};
      for (var tx in transactions) {
        final String? pId = tx['product_id']?.toString();
        if (pId != null) {
          final int qty = (tx['quantity_change'] as num).abs().toInt();
          salesData[pId] = (salesData[pId] ?? 0) + qty;
        }
      }

      List<Map<String, dynamic>> analyticsList = [];

      for (var item in _items) {
        final totalSold = salesData[item.id] ?? 0;
        final dailySalesVelocity = totalSold / days;

        String classification;
        if (totalSold == 0) {
          classification = 'Dead Stock';
        } else if (dailySalesVelocity >= 1.0) {
          classification = 'Fast-Moving';
        } else {
          classification = 'Slow-Moving';
        }

        double daysUntilStockout = -1;
        DateTime? stockoutDate;
        if (dailySalesVelocity > 0) {
          daysUntilStockout = item.quantity / dailySalesVelocity;
          stockoutDate = DateTime.now().add(
            Duration(days: daysUntilStockout.floor()),
          );
        }

        int safetyStock = 0;
        int reorderPoint = 0;
        int optimalReorderQuantity = 0;

        if (classification == 'Fast-Moving') {
          safetyStock = (leadTimeDays * dailySalesVelocity * 1.5).ceil();
          reorderPoint =
              (leadTimeDays * dailySalesVelocity).ceil() + safetyStock;
          optimalReorderQuantity = (dailySalesVelocity * 30).ceil();
        } else if (classification == 'Slow-Moving') {
          safetyStock = (leadTimeDays * dailySalesVelocity * 1.0).ceil();
          reorderPoint =
              (leadTimeDays * dailySalesVelocity).ceil() + safetyStock;
          optimalReorderQuantity = (dailySalesVelocity * 15).ceil();
        } else {
          safetyStock = 0;
          reorderPoint = 0;
          optimalReorderQuantity = 0;
        }

        analyticsList.add({
          'item': item,
          'totalSoldLast30Days': totalSold,
          'dailySalesVelocity': dailySalesVelocity,
          'classification': classification,
          'daysUntilStockout': daysUntilStockout,
          'stockoutDate': stockoutDate,
          'safetyStock': safetyStock,
          'reorderPoint': reorderPoint,
          'optimalReorderQuantity': optimalReorderQuantity,
          'needsReorder':
              item.quantity <= reorderPoint && classification != 'Dead Stock',
        });
      }

      analyticsList.sort((a, b) {
        if (a['needsReorder'] && !b['needsReorder']) return -1;
        if (!a['needsReorder'] && b['needsReorder']) return 1;
        if (a['daysUntilStockout'] != -1 && b['daysUntilStockout'] != -1) {
          return (a['daysUntilStockout'] as double).compareTo(
            b['daysUntilStockout'] as double,
          );
        }
        return 0;
      });

      return analyticsList;
    } catch (e) {
      return [];
    }
  }

  // CHANGE 1: Update the signature to return Future<CustomerOrder?>
  Future<CustomerOrder?> createCustomerOrder(
    List<CustomerOrderItem> items, {
    required double totalAmount,
    required double discountAmount,
    String? paymentMode,
    double? cashGiven,
    double? changeAmount,
    bool soloHandled = false,  
  }) async {
    final locId = activeLocationId;
    if (locId == null) return null; // CHANGE 2: return null

    try {
      final response = await supabase.from('orders').insert({
        'location_id': locId,
        'status': 'pending',
        'total_amount': totalAmount,
        'discount_amount': discountAmount,
        'payment_mode': paymentMode ?? 'Cash',
        'cash_given': cashGiven,
        'change_amount': changeAmount,
        'items': items.map((i) => i.toJson()).toList(),
        'created_by': currentUserNumericId,
        'status': soloHandled ? 'solo_picking' : 'pending', 
      }).select();

      for (var orderItem in items) {
        final index = _items.indexWhere((i) => i.id == orderItem.productId);
        if (index != -1) {
          final currentItem = _items[index];
          final updatedItem = calculateCheckout(
            currentItem,
            orderItem.quantity,
          );
          await updateItem(updatedItem);
        }
      }

      // CHANGE 3: Return the created order object
      if (response.isNotEmpty) {
        return CustomerOrder.fromJson(response.first);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> cancelOrder(CustomerOrder order) async {
    final row = await supabase
        .from('orders')
        .select('status')
        .eq('id', order.id)
        .single();
    final status = row['status'];
    if (status == 'completed' || status == 'cancelled') {
      throw Exception('Order is already $status.');
    }

    await supabase
        .from('orders')
        .update({'status': 'cancelled'})
        .eq('id', order.id);

    for (final oi in order.items) {
      final index = _items.indexWhere((i) => i.id == oi.productId);
      if (index == -1) continue;
      final restored = _items[index].copyWith(
        quantity: _items[index].quantity + oi.quantity,
      );
      await supabase
          .from('products')
          .update({'product_quantity': restored.quantity})
          .eq('id', restored.id);
      _items[index] = restored;
      await _logTransaction(
        productId: restored.id,
        type: 'order_cancelled',
        quantityChange: oi.quantity,
        newQuantity: restored.quantity,
      );
    }
  }

Stream<List<CustomerOrder>> streamOrders() {
    final locId = activeLocationId;
    if (locId == null) return Stream.value([]);

    return supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('location_id', locId)
        .order('created_at', ascending: false)
        .map(
          (list) =>
              list.map((item) => CustomerOrder.fromJson(item)).toList(),
        );
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    try {
      final Map<String, dynamic> updateData = {'status': newStatus};
      if (newStatus == 'prepared') {
        updateData['prepared_by'] = currentUserNumericId;
      }
      await supabase
          .from('orders')
          .update(updateData)
          .eq('id', orderId)
          .neq('status', 'cancelled')
          .neq('status', 'completed');
    } catch (e) {}
  }

  Set<String>? _processingOrders;

  Future<void> completeOrder(
    CustomerOrder order, {
    String? paymentMode,
    double? cashGiven,
    double? changeAmount,
  }) async {
    _processingOrders ??= {};
    if (_processingOrders!.contains(order.id)) return;
    _processingOrders!.add(order.id);

    try {
      final checkOrder = await supabase
          .from('orders')
          .select('status')
          .eq('id', order.id)
          .single();
       final s = checkOrder['status'];
      if (s == 'completed') return;
      if (s == 'cancelled') throw Exception('This order was cancelled.');

      // Prepare the data payload to update
      final Map<String, dynamic> updateData = {
        'status': 'completed',
      };

      // Add payment data if provided
      if (paymentMode != null) updateData['payment_mode'] = paymentMode;
      if (cashGiven != null) updateData['cash_given'] = cashGiven;
      if (changeAmount != null) updateData['change_amount'] = changeAmount;

      // Update the database
      await supabase.from('orders').update(updateData).eq('id', order.id);
      
    } finally {
      _processingOrders!.remove(order.id);
    }
  }

  Future<void> updateProfile({
    required String userId,
    required String name,
    required String email,
    required String location,
    required String phone,
  }) async {
    try {
      final updateData = {
        'name': name,
        'email': email.isEmpty ? null : email,
        'address': location,
        'phone': phone,
      };

      await Supabase.instance.client
          .from('profiles')
          .update(updateData)
          .eq('id', userId);
    } catch (e) {
      throw Exception("Failed to save changes to the database.");
    }
  }

  Future<bool> adminResetUserPassword(
    String targetUserId,
    String newPassword,
  ) async {
    try {
      final hashedNewPassword = _hashPassword(newPassword);

      await supabase
          .from('profiles')
          .update({'password': hashedNewPassword})
          .eq('id', targetUserId);

      return true;
    } catch (e) {
      return false;
    }
  }
}