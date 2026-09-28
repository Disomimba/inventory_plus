import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../data/inventory.dart';
import '../../logic/inventory_controller.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class ItemDetailPage extends StatefulWidget {
  final InventoryItem item;
  final InventoryController controller;
  final VoidCallback onBack;
  final Future<void> Function(InventoryItem) onUpdate;
  final Function(String) onDelete;

  const ItemDetailPage({
    super.key,
    required this.item,
    required this.controller,
    required this.onBack,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  late InventoryItem _currentItem;
  List<Map<String, dynamic>> _transactionHistory = [];
  bool _isLoadingHistory = true;

  bool _isEditing = false;
  bool isReadOnly = false;

  bool _isSaving = false;
  String? _newImageUrl;
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  late TextEditingController _skuController;
  late TextEditingController _descController;
  late TextEditingController _manufacturerController;
  late TextEditingController _modelController;
  late TextEditingController _sizeController;

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
    _initControllers();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;
    setState(() => _isLoadingHistory = true);
    final history = await widget.controller.fetchTransactionHistory(
      _currentItem.id,
    );
    if (mounted) {
      setState(() {
        _transactionHistory = history;
        _isLoadingHistory = false;
      });
    }
  }

  void _initControllers() {
    _nameController = TextEditingController(text: _currentItem.name);
    _priceController = TextEditingController(
      text: _currentItem.price.toString(),
    );
    _stockController = TextEditingController(
      text: _currentItem.quantity.toString(),
    );
    _skuController = TextEditingController(text: _currentItem.sku);
    _descController = TextEditingController(text: _currentItem.description);

    _manufacturerController = TextEditingController(
      text: _currentItem.manufacturer ?? "",
    );
    _modelController = TextEditingController(text: _currentItem.model ?? "");
    _sizeController = TextEditingController(
      text: _currentItem.productSize ?? "",
    );
  }

  @override
  void didUpdateWidget(ItemDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item != widget.item) {
      _currentItem = widget.item;
      _initControllers(); 
      _loadHistory();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _skuController.dispose();
    _descController.dispose();
    _manufacturerController.dispose();
    _modelController.dispose();
    _sizeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (!_isEditing) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(LucideIcons.camera),
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? photo = await _picker.pickImage(
                  source: ImageSource.camera,
                );
                if (photo != null) {
                  setState(() {
                    _selectedImage = photo;
                    _newImageUrl = photo.path;
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.image),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (image != null) {
                  setState(() {
                    _selectedImage = image;
                    _newImageUrl = image.path;
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.link),
              title: const Text('Enter Image URL'),
              onTap: () {
                Navigator.pop(context);
                _showUrlInputDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showUrlInputDialog() {
    final urlController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Image URL"),
        content: TextField(
          controller: urlController,
          decoration: const InputDecoration(hintText: "Paste link here"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _newImageUrl = urlController.text;
                _selectedImage = null;
              });
              Navigator.pop(context);
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);

    try {
      String finalImageUrl = _currentItem.imageUrl;

      if (_newImageUrl != null && _newImageUrl != _currentItem.imageUrl) {
        if (!_newImageUrl!.startsWith('http')) {
          final String fileName = _nameController.text.isNotEmpty
              ? '${_nameController.text}_image.jpg'
              : 'updated_product_image.jpg';
          String? uploadedUrl;
          if (kIsWeb && _selectedImage != null) {
            final bytes = await _selectedImage!.readAsBytes();
            uploadedUrl = await widget.controller.uploadImageBytes(
              bytes,
              fileName,
            );
          } else if (_newImageUrl != null) {
            final File imageFile = File(_newImageUrl!);
            uploadedUrl = await widget.controller.uploadProductImage(
              imageFile,
              fileName,
            );
          }
          if (uploadedUrl != null) finalImageUrl = uploadedUrl;
        } else {
          finalImageUrl = _newImageUrl!;
        }
      }

      final updated = widget.controller.prepareUpdatedItem(
        originalItem: _currentItem,
        newName: _nameController.text,
        newSku: _skuController.text,
        newPrice: _priceController.text,
        newStock: _stockController.text,
        newMaxStock: _currentItem.maxQuantity.toString(), // Passes existing back safely
        newDesc: _descController.text,
        manufacturer: _manufacturerController.text,
        model: _modelController.text,
        productSize: _sizeController.text,
        shelfLevel: _currentItem.shelfLevel ?? '', // Passes existing back safely
        binNumber: _currentItem.binNumber ?? '', // Passes existing back safely
        imageUrl: finalImageUrl,
      );

      await widget.onUpdate(updated);
      if (mounted) {
        setState(() {
          _currentItem = updated;
          _isEditing = false;
          _newImageUrl = null;
          _selectedImage = null;
        });
        await _loadHistory();
        _showSnackBar('Item updated successfully', Colors.green);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error updating item: $e', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handleCheckout(double qty) async {
    final updated = widget.controller.calculateCheckout(_currentItem, qty);
    await widget.onUpdate(updated);
    if (mounted) {
      Navigator.pop(context);
      _showSnackBar('Checked out $qty item(s)', Colors.orange);
      await _loadHistory();
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _buildStatCard(
                            "Price",
                            "₱${_currentItem.price.toStringAsFixed(2)}",
                            LucideIcons.banknote,
                            Colors.green,
                            _priceController,
                          ),
                          const SizedBox(width: 12),
                          _buildStatCard(
                            "Stock (Qty)",
                            _currentItem.quantity.toString(),
                            LucideIcons.package,
                            _currentItem.quantity <=
                                    (_currentItem.maxQuantity * 0.20)
                                ? Colors.red
                                : Colors.blue,
                            _stockController,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildProductSpecsBox(),
                      const SizedBox(height: 24),
                      _buildDetailsBox(),
                      const SizedBox(height: 24),
                      _buildTransactionHistoryBox(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (!_isEditing) _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      backgroundColor: const Color(0xFF1E293B),
      leading: IconButton(
        icon: const Icon(LucideIcons.chevronLeft, color: Colors.white),
        onPressed: widget.onBack,
      ),
      actions: [
        if (_isSaving)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
          )
        else if (_isEditing)
          IconButton(
            icon: const Icon(LucideIcons.check, color: Colors.greenAccent),
            onPressed: _handleSave,
          )
        else if (widget.controller.currentUserRole?.toLowerCase() == 'admin')
          IconButton(
            icon: const Icon(LucideIcons.pencil, color: Colors.white, size: 20),
            onPressed: () => setState(() => _isEditing = true),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: GestureDetector(
          onTap: _isEditing ? _pickImage : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildImage(),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                  ),
                ),
              ),
              if (_isEditing)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.camera,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentItem.category.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _currentItem.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    final imageUrl = _newImageUrl ?? _currentItem.imageUrl;
    if (kIsWeb || imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey.shade200,
          child: const Icon(
            Icons.image_not_supported,
            color: Colors.grey,
            size: 50,
          ),
        ),
      );
    } else {
      return Image.file(
        File(imageUrl),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey.shade200,
          child: const Icon(
            Icons.image_not_supported,
            color: Colors.grey,
            size: 50,
          ),
        ),
      );
    }
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    TextEditingController controller,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  _isEditing
                      ? TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        )
                      : Text(
                          value,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductSpecsBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.info, size: 16, color: Colors.grey),
              SizedBox(width: 8),
              Text(
                "Specifications",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildField(
                  "Manufacturer",
                  _manufacturerController,
                  _currentItem.manufacturer ?? "N/A",
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildField(
                  "Model",
                  _modelController,
                  _currentItem.model ?? "N/A",
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildField(
            "Product Size",
            _sizeController,
            _currentItem.productSize ?? "Standard",
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.tag, size: 16, color: Colors.grey),
              SizedBox(width: 8),
              Text(
                "Inventory Info",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildField("SKU", _skuController, _currentItem.sku, isReadOnly: true),
          const SizedBox(height: 16),
          _buildField(
            "Description",
            _descController,
            _currentItem.description,
            isMultiline: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionHistoryBox() {
    final recentHistory = _transactionHistory.take(5).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(LucideIcons.history, size: 16, color: Colors.grey),
                  SizedBox(width: 8),
                  Text(
                    "Transaction History",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (_transactionHistory.length > 5)
                TextButton(
                  onPressed: _showAllTransactionsModal,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Row(
                    children: [
                      Text(
                        "View All",
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        LucideIcons.chevronRight,
                        size: 14,
                        color: Colors.orange,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingHistory)
            const Center(child: CircularProgressIndicator())
          else if (_transactionHistory.isEmpty)
            const Center(
              child: Text(
                "No transaction history found.",
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentHistory.length,
              itemBuilder: (context, index) =>
                  _buildTransactionTile(recentHistory[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(Map<String, dynamic> transaction) {
    final date = DateTime.parse(transaction['created_at']).toLocal();
    final formattedDate =
        "${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    final quantityChange = transaction['quantity_change'];
    final isPositive = quantityChange > 0;
    final type = transaction['transaction_type'] as String;
    final profileInfo = transaction['profiles'];
    final userName = profileInfo != null
        ? profileInfo['name']
        : (transaction['user_name'] ?? 'Unknown');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isPositive
              ? Colors.green.withOpacity(0.1)
              : Colors.red.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isPositive ? LucideIcons.plus : LucideIcons.minus,
          color: isPositive ? Colors.green : Colors.red,
          size: 16,
        ),
      ),
      title: Text(
        "${isPositive ? '+' : ''}$quantityChange  •  ${type.replaceAll('_', ' ').capitalize()}",
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      subtitle: Text(
        "By $userName  •  $formattedDate",
        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          "Qty: ${transaction['new_quantity']}",
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _showAllTransactionsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "All Transactions",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          _currentItem.name,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "${_transactionHistory.length} records",
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: Colors.grey.shade200),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  itemCount: _transactionHistory.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: Colors.grey.shade100),
                  itemBuilder: (context, index) =>
                      _buildTransactionTile(_transactionHistory[index]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    String displayValue, {
    bool isMultiline = false,
    bool isReadOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        (_isEditing && !isReadOnly)
            ? TextField(
                controller: controller,
                maxLines: isMultiline ? null : 1,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
              )
            : Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  displayValue.isEmpty ? "N/A" : displayValue,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
      ],
    );
  }

  Widget _buildBottomActions() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            if (widget.controller.currentUserRole?.toLowerCase() ==
                'admin') ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showDeleteDialog,
                  icon: const Icon(LucideIcons.trash2, size: 18),
                  label: const Text("Delete"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Item?"),
        content: Text("Remove \"${_currentItem.name}\" from inventory?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete(_currentItem.id);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) {
      return "";
    }
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}