import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../logic/inventory_controller.dart';
import 'widgets/app_toast.dart';
import 'widgets/app_dialog.dart';

// Data Models
class MeasurementUnit {
  String id;
  String name;
  String symbol;

  MeasurementUnit({required this.id, required this.name, required this.symbol});
}

class SystemSettingsPage extends StatefulWidget {
  final InventoryController controller;
  const SystemSettingsPage({super.key, required this.controller});

  @override
  State<SystemSettingsPage> createState() => _SystemSettingsPageState();
}

class _SystemSettingsPageState extends State<SystemSettingsPage> {
  bool _isLoading = true;
  List<MeasurementUnit> _measurements = [];

  // Global Threshold State
  final TextEditingController _lowPercentCtrl = TextEditingController();
  final TextEditingController _criticalPercentCtrl = TextEditingController();
  String? _thresholdError;
  bool _isSavingThresholds = false;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  @override
  void dispose() {
    _lowPercentCtrl.dispose();
    _criticalPercentCtrl.dispose();
    super.dispose();
  }

  // Shows 20 instead of 20.0 in the text fields.
  String _formatPct(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  // The controller owns the measurements list (availableMeasurements) and
  // keeps it up to date after every add/update/delete, so the page just
  // rebuilds its local view models from it.
  List<MeasurementUnit> _measurementsFromController() {
    return widget.controller.availableMeasurements
        .map(
          (m) => MeasurementUnit(
            id: m['id'].toString(),
            name: m['name'] as String,
            symbol: m['symbol'] as String,
          ),
        )
        .toList();
  }

  Future<void> _fetchSettings() async {
    try {
      // Thresholds + measurements are both loaded by the controller.
      // Note: loadSystemSettings() swallows its own errors and keeps the
      // default values (20 / 10), so a failed fetch shows defaults
      // rather than an error toast.
      await widget.controller.loadSystemSettings();
      if (!mounted) return;

      _lowPercentCtrl.text = _formatPct(widget.controller.globalLowStockPct);
      _criticalPercentCtrl.text = _formatPct(
        widget.controller.globalCriticalPct,
      );

      setState(() {
        _measurements = _measurementsFromController();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showToast("Error loading settings: $e", isError: true);
      }
    }
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    isError
        ? AppToast.error(context, message)
        : AppToast.success(context, message);
  }

  Future<void> _saveGlobalThresholds() async {
    setState(() => _thresholdError = null);

    final lowVal = double.tryParse(_lowPercentCtrl.text);
    final critVal = double.tryParse(_criticalPercentCtrl.text);

    if (lowVal == null || critVal == null) {
      setState(() => _thresholdError = "Percentages must be valid numbers.");
      return;
    }
    if (critVal <= 0 || lowVal > 100) {
      setState(
        () => _thresholdError =
            "Values must be between 0 and 100 (critical must be above 0).",
      );
      return;
    }

    setState(() => _isSavingThresholds = true);

    try {
      // Controller upserts the global settings row AND updates its own
      // globalLowStockPct / globalCriticalPct, so ItemCard and the
      // inventory page pick up the new values without a refetch.
      await widget.controller.updateGlobalThresholds(lowVal, critVal);

      if (mounted) {
        setState(() => _isSavingThresholds = false);
        _showToast("Global thresholds updated successfully");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSavingThresholds = false;
          _thresholdError = "Failed to save: $e";
        });
      }
    }
  }

  void _showMeasurementModal([MeasurementUnit? existing]) {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final symbolCtrl = TextEditingController(text: existing?.symbol ?? '');
  String? nameError;
  String? symbolError;
  bool saving = false;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setModalState) {
        Future<void> validateAndSave() async {
          final name = nameCtrl.text.trim();
          final symbol = symbolCtrl.text.trim();

          setModalState(() {
            nameError = name.isEmpty ? "Measurement name is required" : null;
            symbolError = symbol.isEmpty ? "Symbol/Unit is required" : null;
          });
          if (name.isEmpty || symbol.isEmpty) return;

          setModalState(() => saving = true);
          try {
            if (existing == null) {
              await widget.controller.addMeasurement(name, symbol);
              _showToast("Measurement added successfully");
            } else {
              await widget.controller.updateMeasurement(
                existing.id,
                name,
                symbol,
              );
              _showToast("Measurement updated successfully");
            }

            if (mounted) {
              setState(() => _measurements = _measurementsFromController());
            }
            if (dialogContext.mounted) Navigator.pop(dialogContext);
          } catch (e) {
            setModalState(() => saving = false);
            _showToast("Failed to save measurement: $e", isError: true);
          }
        }

        InputDecoration deco(String label, String? error) => InputDecoration(
          labelText: label,
          errorText: error,
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.orange, width: 2),
          ),
        );

        return AppDialog(
          icon: LucideIcons.ruler,
          color: Colors.orange,
          title: existing == null ? "Add Measurement" : "Edit Measurement",
          subtitle: existing?.name,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: deco("Measurement Name (e.g. Pieces)", nameError),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: symbolCtrl,
                decoration: deco("Symbol / Unit (e.g. pcs)", symbolError),
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: saving ? null : validateAndSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      "Save",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        );
      },
    ),
  );
}

  void _confirmDelete(MeasurementUnit item) {
    showDialog(
      context: context,
      builder: (ctx) => AppDialog(
        icon: LucideIcons.trash2,
        color: Colors.red.shade600,
        title: "Delete Measurement?",
        subtitle: item.name,
        child: Text(
          "Are you sure you want to remove '${item.name}'? Existing inventory using this unit will not be altered.",
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black87,
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await widget.controller.deleteMeasurement(item.id);
                if (mounted) {
                  setState(() => _measurements = _measurementsFromController());
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _showToast("Measurement deleted", isError: true);
              } catch (e) {
                if (ctx.mounted) Navigator.pop(ctx);
                _showToast("Failed to delete measurement: $e", isError: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              "Delete",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── UI BUILDER ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "System Settings",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Manage global configurations and core data",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 32),

                  // ─── SECTION 1: GLOBAL STOCK THRESHOLDS ─────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                LucideIcons.triangleAlert,
                                color: Colors.red.shade600,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Global Stock Thresholds",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "Set the percentage of an item's usual stock level that triggers stock alerts.",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        if (_thresholdError != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Text(
                              _thresholdError!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Low Stock Level (%)",
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _lowPercentCtrl,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d*\.?\d*'),
                                      ),
                                    ],
                                    decoration: InputDecoration(
                                      suffixText: '%',
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Critical Stock Level (%)",
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _criticalPercentCtrl,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d*\.?\d*'),
                                      ),
                                    ],
                                    decoration: InputDecoration(
                                      suffixText: '%',
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _isSavingThresholds
                                    ? null
                                    : _saveGlobalThresholds,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                ),
                                child: _isSavingThresholds
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        "Save Thresholds",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ─── SECTION 2: MEASUREMENT UNITS ────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      LucideIcons.ruler,
                                      color: Colors.blue.shade600,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  const Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Measurement Units",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        "Manage available units for inventory items.",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _showMeasurementModal(),
                                icon: const Icon(
                                  LucideIcons.plus,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  "Add Unit",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),

                        if (_measurements.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(40.0),
                            child: Center(
                              child: Text(
                                "No measurement units found.",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _measurements.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = _measurements[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24.0,
                                  vertical: 16.0,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              "Symbol: ${item.symbol}",
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            LucideIcons.pencil,
                                            size: 18,
                                            color: Colors.grey.shade600,
                                          ),
                                          onPressed: () =>
                                              _showMeasurementModal(item),
                                          tooltip: "Edit",
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            LucideIcons.trash2,
                                            size: 18,
                                            color: Colors.red.shade400,
                                          ),
                                          onPressed: () => _confirmDelete(item),
                                          tooltip: "Delete",
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
