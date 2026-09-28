import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../data/inventory.dart';
import '../logic/inventory_controller.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;

class AddItemPage extends StatefulWidget {
  final InventoryController controller;
  final Function(InventoryItem) onAdd;

  const AddItemPage({super.key, required this.controller, required this.onAdd});

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _categoryController = TextEditingController();
  final _descController = TextEditingController();

  final _manufacturerController = TextEditingController();
  final _modelController = TextEditingController();
  final _sizeController = TextEditingController();

  
  String? _imageUrl;
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  // State to hold the selected unit of measurement
  String _selectedUnit = 'pcs';
  bool _isCustomUnit = false; // Add this
  final _customUnitController = TextEditingController(); // Add this

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _categoryController.dispose();
    _descController.dispose();
    _manufacturerController.dispose();
    _modelController.dispose();
    _sizeController.dispose();
    _customUnitController.dispose(); // Add this
    super.dispose();
  }

  Future<void> _pickImage() async {
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
                    _imageUrl = photo.path;
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
                    _imageUrl = image.path;
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
  String _generateAutoSKU() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final math.Random rnd = math.Random();
    return 'SKU-' + String.fromCharCodes(Iterable.generate(
        8, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
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
                _imageUrl = urlController.text;
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

  void _submitData() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fix the errors before saving."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? finalImageUrl = _imageUrl;

      if (_imageUrl != null && !_imageUrl!.startsWith('http')) {
        final String fileName = _nameController.text.isNotEmpty
            ? '${_nameController.text}_image.jpg'
            : 'product_image.jpg';
        String? uploadedUrl;
        if (kIsWeb && _selectedImage != null) {
          final bytes = await _selectedImage!.readAsBytes();
          uploadedUrl = await widget.controller.uploadImageBytes(
            bytes,
            fileName,
          );
        } else {
          final File imageFile = File(_imageUrl!);
          uploadedUrl = await widget.controller.uploadProductImage(
            imageFile,
            fileName,
          );
        }
        if (uploadedUrl != null) finalImageUrl = uploadedUrl;
      }
      final String autoGeneratedSku = _generateAutoSKU();

      final newItem = widget.controller.createNewItem(
        name: _nameController.text.trim(),
        sku: autoGeneratedSku,
        price: _priceController.text.trim(),
        quantity: _quantityController.text.trim(),
        maxQuantity: '0', // Default empty value
        category: _categoryController.text.trim(),
        description: _descController.text.trim(),
        manufacturer: _manufacturerController.text.trim(),
        model: _modelController.text.trim(),
        productSize: _sizeController.text.trim(),
        shelfLevel: '', // Default empty value
        binNumber: '', // Default empty value
        imageUrl: finalImageUrl ?? '',
        unit: _selectedUnit,
      );

      await widget.controller.addItem(newItem);
      if (mounted) {
        widget.onAdd(newItem);
        Navigator.pop(context);
      }
    } catch (e) {
      String errorMessage = "Error: $e";
      if (e is PostgrestException && e.code == '23505') {
        errorMessage =
            "An item with this SKU already exists! Please enter a unique SKU.";
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text(
          "Add New Product",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildImageHeader(),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle("General Information"),
                          _buildTextField(
                            _nameController,
                            "Product Name",
                            LucideIcons.package,
                            customValidator: (v) => v!.trim().length < 2
                                ? 'Enter a valid name (min 2 chars)'
                                : null,
                          ),
                          
                          const SizedBox(height: 24),
                          _buildSectionTitle("Technical Specifications"),
                          _buildTextField(
                            _manufacturerController,
                            "Brand / Manufacturer",
                            LucideIcons.factory,
                            isRequired: false,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  _modelController,
                                  "Model #",
                                  LucideIcons.info,
                                  isRequired: false,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTextField(
                                  _sizeController,
                                  "Size",
                                  LucideIcons.maximize,
                                  isRequired: false,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),
                          _buildSectionTitle("Pricing & Inventory"),

                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  _priceController,
                                  "Price (₱)",
                                  LucideIcons.banknote,
                                  isNumber: true,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTextField(
                                  _categoryController,
                                  "Category",
                                  LucideIcons.tag,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          _buildTextField(
                            _quantityController,
                            "Initial Stock",
                            LucideIcons.archive,
                            isNumber: true,
                          ),
                          
                          const SizedBox(height: 16),
                          _buildUnitDropdown(),

                          const SizedBox(height: 16),
                          _buildTextField(
                            _descController,
                            "Detailed Description",
                            LucideIcons.fileText,
                            isMultiline: true,
                            isRequired: false,
                          ),

                          const SizedBox(height: 40),
                          _buildSaveButton(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildUnitDropdown() {
    final Map<String, String> unitLabels = {
      'pcs': 'Pieces (pcs)',
      'box': 'Boxes (box)',
      'pack': 'Packs (pack)',
      'kl': 'Kilos (kl)',
      'g': 'Grams (g)',
      'L': 'Liters (L)',
      'm': 'Meters (m)',
      'other': 'Other (Custom)', // <-- Added 'Other' option
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedUnit,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: "Unit of Measure",
            helperText: "Sets POS rules: Whole numbers (Pieces) vs. Decimals (Kilos).",
            helperMaxLines: 2,
            helperStyle: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
            prefixIcon: const Icon(LucideIcons.scale, size: 18, color: Colors.orange),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.orange, width: 2)),
          ),
          items: unitLabels.entries.map((entry) {
            return DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value, style: const TextStyle(fontSize: 14)),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedUnit = val;
                _isCustomUnit = (val == 'other'); // <-- Toggles the custom field
              });
            }
          },
        ),
        
        // <-- This displays the custom text field if 'Other' is selected
        if (_isCustomUnit) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _customUnitController,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please specify unit' : null,
            decoration: InputDecoration(
              hintText: "Enter custom unit (e.g., mm, mL, pair)",
              prefixIcon: const Icon(LucideIcons.penTool, size: 18, color: Colors.orange),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.orange, width: 2)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
              fontSize: 13,
            ),
          ),
          const Expanded(
            child: Divider(indent: 10, color: Colors.orange, thickness: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildImageHeader() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: double.infinity,
        height: 180,
        color: const Color(0xFF1E293B),
        child: _imageUrl != null
            ? ((kIsWeb || _imageUrl!.startsWith('http'))
                  ? Image.network(_imageUrl!, fit: BoxFit.cover)
                  : Image.file(File(_imageUrl!), fit: BoxFit.cover))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.imagePlus,
                    color: Colors.white.withOpacity(0.3),
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Tap to Add Product Photo",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _submitData,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const Text(
          "Save to Database",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isNumber = false,
    bool isMultiline = false,
    bool isRequired = true,
    String? Function(String?)? customValidator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : (isMultiline ? TextInputType.multiline : TextInputType.text),
      maxLines: isMultiline ? 3 : 1,
      validator:
          customValidator ??
          (value) {
            if (isRequired && (value == null || value.trim().isEmpty)) {
              return 'Required';
            }
            if (isNumber &&
                value != null &&
                value.trim().isNotEmpty &&
                double.tryParse(value.trim()) == null) {
              return 'Must be a number';
            }
            return null;
          },
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        prefixIcon: Icon(icon, size: 18, color: Colors.orange),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.orange, width: 2),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
    );
  }
}