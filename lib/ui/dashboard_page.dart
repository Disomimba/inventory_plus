import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../logic/inventory_controller.dart';
import '../data/inventory.dart';

class DashboardPage extends StatefulWidget {
  final InventoryController controller;
  const DashboardPage({super.key, required this.controller});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _aiRecommendation = "Tap refresh to generate AI insights.";
  bool _isLoadingAI = false;
  String _forecastingFilter = 'Season';
  String _forecastInsightText = "Loading forecast...";
  bool _isFetchingForecast = false;

  bool _isBulletedFormat = true;

  final String _groqApiUrl = "https://api.groq.com/openai/v1/chat/completions";

  @override
  void initState() {
    super.initState();
    _fetchAIRecommendations();
    _fetchForecast();
  }

  String _getCurrentMonth() {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[DateTime.now().month - 1];
  }

  Future<void> _fetchForecast() async {
    if (!mounted) return;
    setState(() => _isFetchingForecast = true);

    try {
      final currentMonth = _getCurrentMonth();
      String forecastingContext;
      String formatInstruction;

      if (_forecastingFilter == 'Season') {
        forecastingContext =
            "Focus purely on upcoming Philippine seasonal and climate shifts (e.g., entering the rainy/typhoon season or summer heat). Forecast demand ONLY for hardware, construction, plumbing, and maintenance materials (e.g., roof sealants, G.I. sheets, water hose, cement).";
      } else {
        forecastingContext =
            "Focus strictly on short-term hardware sales trends, local construction activities, and month-to-month demand patterns for building materials and tools.";
      }

      if (_isBulletedFormat) {
        formatInstruction =
            "Format the output as a professional, clean bulleted list using the '•' symbol. Recommend SPECIFIC HARDWARE ITEM NAMES in ALL CAPS for emphasis, followed by a brief 5-word reason. Example: '• ELASTOMERIC SEALANT: Approaching heavy rainy season.' DO NOT use markdown like asterisks (**).";
      } else {
        formatInstruction =
            "Format the output as a professional, concise executive summary paragraph (maximum 3 sentences). DO NOT list specific item names. Instead, explain the upcoming trend and recommend broad HARDWARE PRODUCT CATEGORIES (e.g., 'waterproofing materials', 'structural reinforcements'). DO NOT use markdown like asterisks (**).";
      }

      final prompt =
          """
      You are an AI Demand Forecasting system strictly for a small-to-medium hardware and construction supply store located in the Philippines. 
      The current month is $currentMonth.
      $forecastingContext
      $formatInstruction
      
      CRITICAL RULES:
      - ONLY suggest construction, plumbing, electrical, carpentry, and maintenance materials.
      - DO NOT suggest personal care (skincare), clothing, umbrellas, food, consumer electronics, or household appliances.
      - Do not include any conversational intro or outro text.
      """;

      final groqApiKey = dotenv.env['GROQ_API_KEY']?.trim() ?? '';

      if (groqApiKey.isEmpty) {
        if (!mounted) return;
        setState(() {
          _forecastInsightText = "API Key not found.";
          _isFetchingForecast = false;
        });
        return;
      }

      final response = await http.post(
        Uri.parse(_groqApiUrl),
        headers: {
          'Authorization': 'Bearer $groqApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": "llama-3.1-8b-instant",
          "messages": [
            {
              "role": "system",
              "content":
                  "You are a professional inventory forecaster for a traditional hardware and construction supply store in the Philippines.",
            },
            {"role": "user", "content": prompt},
          ],
          "temperature": 0.2,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String rawContent = data['choices'][0]['message']['content'].trim();
        String cleanContent = rawContent.replaceAll(RegExp(r'\*+'), '');

        setState(() {
          _forecastInsightText = cleanContent;
        });
      } else {
        setState(() {
          _forecastInsightText = "Error fetching forecast.";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _forecastInsightText = "Network error: $e");
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingForecast = false);
      }
    }
  }

  Future<void> _fetchAIRecommendations() async {
    if (!mounted) return;
    setState(() => _isLoadingAI = true);

    try {
      final allItems = widget.controller.filterInventory(
        query: "",
        category: "All",
      );

      final criticalItems = allItems
          .where((i) => i.quantity > 0 && i.quantity <= (i.maxQuantity * 0.10))
          .map(
            (i) =>
                "${i.name} (Current: ${i.quantity}, Max Capacity: ${i.maxQuantity})",
          )
          .join(', ');

      final deadItems = allItems
          .where((i) => i.quantity <= 0)
          .map((i) => "${i.name} (Max Capacity: ${i.maxQuantity})")
          .join(', ');

      final prompt =
          """
      I manage a hardware store. Here is my internal inventory data:
      Out-of-stock items: ${deadItems.isEmpty ? 'None' : deadItems}. 
      Critical Stock (under 10% capacity) items: ${criticalItems.isEmpty ? 'None' : criticalItems}.

      Provide a strict INTERNAL restocking action plan.
      Follow these strict rules:
      1. Use the '•' symbol for bullet points.
      2. Write specific ITEM NAMES in ALL CAPS. DO NOT use markdown formatting like asterisks (**).
      3. Create a single section titled "URGENT REPLENISH".
      4. List each item in this format:
         1. [ITEM NAME]
            - [Brief 1-sentence reason for urgency]
            - [Recommended replenishment quantity]
      5. End the message with a single paragraph of justification explaining why these specific items were prioritized to maximize store revenue and customer satisfaction.
      6. Keep it extremely brief. No conversational filler.
      """;

      final groqApiKey = dotenv.env['GROQ_API_KEY']?.trim() ?? '';

      if (groqApiKey.isEmpty) {
        if (!mounted) return;
        setState(() {
          _aiRecommendation = "API Key not found.";
          _isLoadingAI = false;
        });
        return;
      }

      final response = await http.post(
        Uri.parse(_groqApiUrl),
        headers: {
          'Authorization': 'Bearer $groqApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": "llama-3.1-8b-instant",
          "messages": [
            {
              "role": "system",
              "content":
                  "You are a professional inventory manager. You follow formatting instructions exactly.",
            },
            {"role": "user", "content": prompt},
          ],
          "temperature": 0.1,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String rawContent = data['choices'][0]['message']['content'].trim();
        String cleanContent = rawContent.replaceAll(RegExp(r'\*+'), '');

        setState(() {
          _aiRecommendation = cleanContent;
        });
      } else {
        setState(() => _aiRecommendation = "Error fetching insights.");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _aiRecommendation = "Network error: $e");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingAI = false);
      }
    }
  }

  // ─── Modal Triggers ────────────────────────────────────────────────────────

  void _showRestockModal(InventoryItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _RestockModalContent(
          item: item,
          onConfirmRestock: (double addedQty) async {
            // 1. Update the quantity locally on the UI (Step 1 fix makes this work)
            setState(() {
              item.quantity += addedQty;
            });

            // 2. Send the update to your controller to save to your database.
            // You'll need to uncomment and adjust this to match your actual controller method.
            // await widget.controller.updateItemQuantity(item.id, item.quantity);

            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Successfully added $addedQty ${item.unit} to ${item.name}',
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  void _showAllAlertsModal(List<InventoryItem> items) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "All Critical Items",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      "Current: ${item.quantity} ${item.unit}",
                      style: const TextStyle(color: Colors.red),
                    ),
                    trailing: ElevatedButton.icon(
                      onPressed: () => _showRestockModal(item),
                      icon: const Icon(Icons.add_shopping_cart, size: 16),
                      label: const Text("Restock"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade50,
                        foregroundColor: Colors.orange.shade900,
                        elevation: 0,
                      ),
                    ),
                    onTap: () => _showRestockModal(item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Build Method ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final allItems = widget.controller.filterInventory(
      query: "",
      category: "All",
    );
    final totalItems = allItems.length;

    final deadStockItems = allItems
        .where((item) => item.quantity <= 0)
        .toList();
    final criticalStockItems = allItems
        .where(
          (item) =>
              item.quantity > 0 && item.quantity <= (item.maxQuantity * 0.10),
        )
        .toList();
    final lowStockItems = allItems
        .where(
          (item) =>
              item.quantity > (item.maxQuantity * 0.10) &&
              item.quantity <= (item.maxQuantity * 0.20),
        )
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Analytics & Forecasting Dashboard",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 24),

            LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;

                return GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    mainAxisExtent: 120,
                  ),
                  children: [
                    _buildStatCard(
                      "Total Monitored SKUs",
                      totalItems.toString(),
                      LucideIcons.package,
                      Colors.blue,
                    ),
                    _buildStatCard(
                      "Low Stock (20% Threshold)",
                      lowStockItems.length.toString(),
                      LucideIcons.pencil,
                      Colors.orange,
                    ),
                    _buildStatCard(
                      "Critical Stock (10% Threshold)",
                      criticalStockItems.length.toString(),
                      LucideIcons.triangleAlert,
                      Colors.red,
                    ),
                    _buildStatCard(
                      "Dead Stock (0 Qty)",
                      deadStockItems.length.toString(),
                      Icons.cancel_outlined,
                      Colors.blueGrey,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 800;
                final halfWidth = (constraints.maxWidth / 2) - 12;

                return Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: [
                    // LEFT COLUMN
                    SizedBox(
                      width: isDesktop ? halfWidth : double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildActionableAlerts(criticalStockItems),
                          const SizedBox(height: 24),
                          _buildForecastingChart(),
                        ],
                      ),
                    ),
                    // RIGHT COLUMN
                    SizedBox(
                      width: isDesktop ? halfWidth : double.infinity,
                      child: _buildAIRecommendations(),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ─── UI Components ─────────────────────────────────────────────────────────

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

Widget _buildForecastingChart() {
    String insightTitle = _forecastingFilter == 'Season'
        ? "Seasonal High-Demand Predictions"
        : "Next Month Demand Predictions";

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // LEFT SIDE: Icon and Title (Flexible so it shrinks/truncates if needed)
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.trendingUp,
                      color: Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        "AI Demand Forecasting",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis, // Truncates text if screen is too small
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              
              // RIGHT SIDE: Compact/Shrunk Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 36, // Shrunk height
                    width: 36,  // Shrunk width
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero, // Removes default padding to fit smaller box
                      icon: Icon(
                        _isBulletedFormat
                            ? LucideIcons.alignHorizontalJustifyStart400
                            : LucideIcons.list,
                        color: Colors.blue.shade700,
                        size: 18,
                      ),
                      tooltip: _isBulletedFormat
                          ? "Switch to Paragraph Format"
                          : "Switch to Bulleted List",
                      onPressed: () {
                        setState(() => _isBulletedFormat = !_isBulletedFormat);
                        _fetchForecast();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 36, // Matches the icon button height
                    padding: const EdgeInsets.symmetric(horizontal: 8), // Reduced padding
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _forecastingFilter,
                        isDense: true, // Makes the dropdown inherently more compact
                        items: <String>['Season', 'Month'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          if (newValue != null &&
                              newValue != _forecastingFilter) {
                            setState(() => _forecastingFilter = newValue);
                            _fetchForecast();
                          }
                        },
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "Uses contextual market data to forecast future demand and optimize restocking.",
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            height: 250,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insightTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.blue.shade900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _isFetchingForecast
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.blue,
                            ),
                          ),
                        )
                      : SizedBox(
                          width: double.infinity,
                          height: double.infinity,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Text(
                              _forecastInsightText,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF334155),
                                height: 1.6,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildActionableAlerts(List<InventoryItem> criticalItems) {
    final showViewAll = criticalItems.length > 5;
    final itemsToShow = criticalItems.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(LucideIcons.triangleAlert, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Restock Priority",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              if (showViewAll)
                TextButton(
                  onPressed: () => _showAllAlertsModal(criticalItems),
                  child: const Text(
                    "View All",
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 24),
          if (criticalItems.isEmpty)
            const Text(
              "No critical stock alerts at this time.",
              style: TextStyle(color: Colors.grey),
            )
          else
            ...itemsToShow.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _showRestockModal(item),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "${item.quantity} ${item.unit}",
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAIRecommendations() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                children: [
                  const Icon(LucideIcons.sparkles, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text(
                    "AI Restocking Recommendation",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  ),
                ],
              ),
              ),
              IconButton(
                icon: const Icon(
                  LucideIcons.refreshCw,
                  color: Colors.orange,
                  size: 16,
                ),
                onPressed: _isLoadingAI ? null : _fetchAIRecommendations,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: _isLoadingAI
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(color: Colors.orange),
                    ),
                  )
                : Text(
                    _aiRecommendation,
                    style: const TextStyle(
                      color: Color(0xFFE2E8F0),
                      fontSize: 13,
                      height: 1.6,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Restock Modal Content Widget
// ─────────────────────────────────────────────────────────────────────────────

class _RestockModalContent extends StatefulWidget {
  final InventoryItem item;
  final Function(double) onConfirmRestock;

  const _RestockModalContent({
    required this.item,
    required this.onConfirmRestock,
  });

  @override
  State<_RestockModalContent> createState() => _RestockModalContentState();
}

class _RestockModalContentState extends State<_RestockModalContent> {
  late double _amountToAdd;

  @override
  void initState() {
    super.initState();
    bool isSolid = _isSolidItem(widget.item.unit);
    _amountToAdd = isSolid ? 1.0 : 0.25; // Default restock starting amount
  }

  bool _isSolidItem(String unit) {
    final u = unit.toLowerCase();
    return u == 'pcs' || u == 'box' || u == 'pack' || u == '';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Restock Item",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Current Stock: ${widget.item.quantity} ${widget.item.unit}",
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      "Price: ₱${widget.item.price.toStringAsFixed(2)}",
                      style: const TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Quantity to Add:",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Center(
            child: _DashboardQuantityStepper(
              initialValue: _amountToAdd,
              unit: widget.item.unit,
              onChanged: (newVal) {
                setState(() {
                  _amountToAdd = newVal;
                });
              },
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Cancel"),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _amountToAdd > 0
                      ? () => widget.onConfirmRestock(_amountToAdd)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Confirm Restock",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard Quantity Stepper (Supports both solid and fractional measurements)
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardQuantityStepper extends StatefulWidget {
  final double initialValue;
  final String unit;
  final ValueChanged<double> onChanged;

  const _DashboardQuantityStepper({
    required this.initialValue,
    required this.unit,
    required this.onChanged,
  });

  @override
  State<_DashboardQuantityStepper> createState() =>
      _DashboardQuantityStepperState();
}

class _DashboardQuantityStepperState extends State<_DashboardQuantityStepper> {
  late TextEditingController _controller;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _formatDisplay(widget.initialValue),
    );
  }

  @override
  void didUpdateWidget(covariant _DashboardQuantityStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue && !_isFocused) {
      _controller.text = _formatDisplay(widget.initialValue);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isSolidItem() {
    final u = widget.unit.toLowerCase();
    return u == 'pcs' || u == 'box' || u == 'pack' || u == '';
  }

  String _formatDisplay(double val) {
    if (_isSolidItem()) return val.toInt().toString();
    return val.truncateToDouble() == val
        ? val.toInt().toString()
        : val
              .toString()
              .replaceAll(RegExp(r'0*$'), '')
              .replaceAll(RegExp(r'\.$'), '');
  }

  String _getFractionLabel(double val) {
    if (val == 0) return "0";
    int whole = val.truncate();
    double decimal = val - whole;

    String fraction = "";
    if ((decimal - 0.25).abs() < 0.001) {
      fraction = "1/4";
    } else if ((decimal - 0.50).abs() < 0.001)
      fraction = "1/2";
    else if ((decimal - 0.75).abs() < 0.001)
      fraction = "3/4";

    if (fraction.isNotEmpty) {
      return whole == 0 ? fraction : "$whole $fraction";
    }

    if (decimal == 0) return whole.toString();
    final formatted = val
        .toStringAsFixed(3)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
    return formatted;
  }

  void _submit() {
    final val = double.tryParse(_controller.text);
    if (val != null && val >= 0) {
      widget.onChanged(_isSolidItem() ? val.truncateToDouble() : val);
    } else {
      _controller.text = _formatDisplay(widget.initialValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSolid = _isSolidItem();
    final step = isSolid ? 1.0 : 0.25;
    final fractionLabel = !isSolid
        ? _getFractionLabel(widget.initialValue)
        : "";

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(
            Icons.remove_circle_outline,
            color: Colors.orange,
            size: 32,
          ),
          onPressed: () {
            if (widget.initialValue > step) {
              widget.onChanged(widget.initialValue - step);
            } else if (widget.initialValue > 0) {
              widget.onChanged(0);
            }
          },
        ),
        SizedBox(
          width: 80,
          child: Focus(
            onFocusChange: (hasFocus) {
              setState(() => _isFocused = hasFocus);
              if (!hasFocus) _submit();
            },
            child: TextField(
              controller: _controller,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              keyboardType: TextInputType.numberWithOptions(decimal: !isSolid),
              inputFormatters: isSolid
                  ? [FilteringTextInputFormatter.digitsOnly]
                  : [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              onChanged: (val) {
                final parsed = double.tryParse(val);
                if (parsed != null && parsed >= 0) {
                  widget.onChanged(
                    isSolid ? parsed.truncateToDouble() : parsed,
                  );
                }
              },
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.orange),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.orange, width: 2),
                ),
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(
            Icons.add_circle_outline,
            color: Colors.orange,
            size: 32,
          ),
          onPressed: () => widget.onChanged(widget.initialValue + step),
        ),
        if (!isSolid)
          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Text(
              fractionLabel.isNotEmpty
                  ? "$fractionLabel ${widget.unit}"
                  : widget.unit,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
                fontSize: 14,
              ),
            ),
          ),
      ],
    );
  }
}