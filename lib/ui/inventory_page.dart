import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../data/inventory.dart';
import '../logic/inventory_controller.dart';
import 'add_item_page.dart';
import 'package:inventory_plus/ui/widgets/item_card.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:inventory_plus/ui/widgets/app_toast.dart';

class InventoryPage extends StatefulWidget {
  final InventoryController controller;
  final Function(InventoryItem) onSelectItem;

  const InventoryPage({
    super.key,
    required this.controller,
    required this.onSelectItem,
  });

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  String _searchQuery = "";
  String _selectedCategory = "All";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSystemSettings();
  }

  Future<void> _loadSystemSettings() async {
    try {
      await widget.controller.loadSystemSettings();
    } catch (e) {
      if (mounted)
        _showToast("Could not load stock thresholds: $e", isError: true);
    }
    if (mounted) setState(() {});
  }

  // --- UPPER RIGHT TOAST NOTIFICATION ---
  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    isError
        ? AppToast.error(context, message)
        : AppToast.success(context, message);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fetch categories and immediately remove 'Unassigned'
    final categories = widget.controller
        .getUniqueCategories()
        .where((category) => category.toLowerCase() != 'unassigned')
        .toList();

    final filteredInventory = widget.controller.filterInventory(
      query: _searchQuery,
      category: _selectedCategory,
    );

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(
              top: 16,
              bottom: 12,
              left: 16,
              right: 16,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Inventory List",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    if (widget.controller.isAdmin)
                      Row(
                        children: [
                          _buildHeaderButton(
                            icon: LucideIcons.download,
                            label: "Export Report",

                            onPressed: () => _showReportDialog(context),
                          ),
                          const SizedBox(width: 8),
                          _buildHeaderButton(
                            icon: LucideIcons.qrCode,
                            label: "QR Labels",

                            onPressed: () => _generateAndPrintQRLabels(context),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              final isDesktop =
                                  MediaQuery.of(context).size.width >= 600;
                              if (isDesktop) {
                                showDialog(
                                  context: context,
                                  builder: (context) => Dialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: SizedBox(
                                      width: 500,
                                      height: 750,
                                      child: AddItemPage(
                                        controller: widget.controller,
                                        onAdd: (newItem) {
                                          setState(() {});
                                          _showToast(
                                            '"${newItem.name}" added to inventory',
                                          );
                                        }
                                      ),
                                    ),
                                  ),
                                );
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddItemPage(
                                      controller: widget.controller,
                                      onAdd: (newItem) {
                                        setState(() {});
                                        _showToast(
                                          '"${newItem.name}" added to inventory',
                                        );
                                      }
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(LucideIcons.plus, size: 14),
                            label: const Text("New Item"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: "Search inventory...",
                    prefixIcon: const Icon(LucideIcons.search, size: 18),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final isSelected = _selectedCategory == category;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedCategory = category),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF1E293B)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredInventory.isNotEmpty
                ? ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredInventory.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildListHeader(filteredInventory.length);
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ItemCard(
                          item: filteredInventory[index - 1],
                          controller: widget.controller,
                          onClick: widget.onSelectItem,
                        ),
                      );
                    },
                  )
                : _buildEmptyState(),
          ),
        ],
      ),
    );
  }

  Widget _buildListHeader(int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "${_selectedCategory.toUpperCase()} ($count)",
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1.1,
            ),
          ),
          const Icon(LucideIcons.arrowUpDown, size: 14, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.package, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          const Text(
            "No items found",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // --- NEW UI HELPER FOR EXPORT BUTTONS ---
  Widget _buildHeaderButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 14, color: const Color(0xFF0F172A)),
          label: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.grey.shade300),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            backgroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  // --- MOVED LOGIC FROM SETTINGS PAGE ---
  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        String selectedPeriod = 'Daily';
        return StatefulBuilder(
          builder: (stateContext, setState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: 450,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Generate Inventory Report",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, color: Colors.grey),
                          onPressed: () => Navigator.pop(dialogContext),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Select the report type/period:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedPeriod,
                          isExpanded: true,
                          icon: const Icon(LucideIcons.chevronDown, size: 18),
                          items: ['Daily', 'Weekly', 'Monthly'].map((
                            String value,
                          ) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            if (newValue != null) {
                              setState(() {
                                selectedPeriod = newValue;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(stateContext),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black87,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 24,
                            ),
                          ),
                          child: const Text("Cancel"),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(stateContext);
                            _generateAndPrintInventoryReport(
                              context,
                              selectedPeriod,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 32,
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Generate PDF",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _generateAndPrintInventoryReport(
    BuildContext context,
    String period,
  ) async {
    final items = widget.controller.allItems;

    if (items.isEmpty) {
      _showToast("No inventory items found to generate report.", isError: true);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          const Center(child: CircularProgressIndicator()),
    );

    try {
      DateTime now = DateTime.now();
      DateTime cutoffDate;
      if (period == 'Daily') {
        cutoffDate = DateTime(now.year, now.month, now.day);
      } else if (period == 'Weekly') {
        cutoffDate = now.subtract(const Duration(days: 7));
      } else {
        cutoffDate = now.subtract(const Duration(days: 30));
      }

      final allTransactions = await widget.controller
          .fetchAllTransactionHistory();
      final periodTransactions = allTransactions.where((tx) {
        final txDate = DateTime.parse(tx['created_at']).toLocal();
        return txDate.isAfter(cutoffDate);
      }).toList();

      Map<String, int> issuedDetails = {};
      Map<String, int> receivedDetails = {};

      for (var tx in periodTransactions) {
        final productId = tx['product_id']?.toString();
        if (productId == null) continue; // e.g. 'delete' entries
        final qty = (tx['quantity_change'] as num).toInt();

        if (tx['transaction_type'] == 'checkout') {
          issuedDetails[productId] =
              (issuedDetails[productId] ?? 0) + qty.abs();
        } else if (tx['transaction_type'] == 'stock_in' ||
            tx['transaction_type'] == 'add') {
          receivedDetails[productId] = (receivedDetails[productId] ?? 0) + qty;
        }
      }

      double grandTotalValue = 0;
      double grandTotalItems = 0.0;

      final tableRows = <pw.TableRow>[];

      tableRows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children:
              [
                    'Item Code',
                    'Item Name',
                    'Beginning Qty',
                    'Received',
                    'Issued',
                    'Ending Qty',
                    'Unit Cost',
                    'Total Value',
                  ]
                  .map(
                    (text) => pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        text,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  )
                  .toList(),
        ),
      );

      for (var item in items) {
        final issued = issuedDetails[item.id] ?? 0;
        final received = receivedDetails[item.id] ?? 0;
        final num endingQty = item.quantity;
        final beginningQty = endingQty - received + issued;
        final totalValue = endingQty * item.price;

        grandTotalValue += totalValue;
        grandTotalItems += endingQty;

        tableRows.add(
          pw.TableRow(
            children: [
              item.sku,
              item.name,
              '$beginningQty ${item.unit}', // Added unit
              '$received',
              '$issued',
              '$endingQty ${item.unit}',    // Added unit
              _formatCurrency(item.price),  // Added commas
              _formatCurrency(totalValue),  // Added commas
            ]
                    .map(
                      (text) => pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          text,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                    )
                    .toList(),
          ),
        );
      }

      final doc = pw.Document();

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Inventory Summary Report',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Report Type: $period',
                          style: const pw.TextStyle(
                            fontSize: 14,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Date Generated: ${now.toString().split(' ')[0]}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(4),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(1.5),
                  5: const pw.FlexColumnWidth(1.5),
                  6: const pw.FlexColumnWidth(1.5),
                  7: const pw.FlexColumnWidth(2),
                },
                children: tableRows,
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Total Items in Stock (Ending): ${grandTotalItems.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Total Inventory Value: P${grandTotalValue.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ];
          },
        ),
      );

      final bytes = await doc.save();
      if (context.mounted) Navigator.pop(context);
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'Inventory_Report_${period}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );

      _showToast("Report generated");
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        _showToast("Error generating PDF: $e", isError: true);
      }
    }
  }

  Future<void> _generateAndPrintQRLabels(BuildContext context) async {
    final items = widget.controller.allItems;

    if (items.isEmpty) {
      _showToast("No inventory items found to generate labels.", isError: true);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          const Center(child: CircularProgressIndicator()),
    );

    try {
      final doc = pw.Document();
      const int itemsPerPage = 6;

      for (var i = 0; i < items.length; i += itemsPerPage) {
        final chunk = items.skip(i).take(itemsPerPage).toList();

        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            build: (pw.Context context) {
              return pw.Wrap(
                spacing: 20,
                runSpacing: 20,
                children: chunk.map((item) {
                  return pw.Container(
                    width: 240,
                    height: 240,
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey, width: 2),
                      borderRadius: pw.BorderRadius.circular(12),
                    ),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          item.name,
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          maxLines: 1,
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          "SKU: ${item.sku}",
                          style: const pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.black,
                          ),
                        ),
                        pw.SizedBox(height: 12),
                        pw.Expanded(
                          child: pw.BarcodeWidget(
                            barcode: pw.Barcode.qrCode(),
                            data: item.sku,
                            drawText: false,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          "Price: P${item.price.toStringAsFixed(2)}",
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        );
      }

      final bytes = await doc.save();
      if (context.mounted) Navigator.pop(context);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Inventory_QR_Labels.pdf',
      );

      _showToast("QR labels generated");
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        _showToast("Error generating PDF: $e", isError: true);
      }
    }
  }
  String _formatCurrency(double value) {
  RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
  String mathFunc(Match match) => '${match[1]},';
  return 'P${value.toStringAsFixed(2).replaceAllMapped(reg, mathFunc)}';
}
}
