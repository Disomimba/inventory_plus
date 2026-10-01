import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'report_period_text.dart';

/// One row of the inventory report table - a single product.
class InventoryReportEntry {
  final String sku;
  final String name;
  final String unit;
  final double beginningQty;
  final double received;
  final double issued;
  final double endingQty;
  final double unitCost;

  const InventoryReportEntry({
    required this.sku,
    required this.name,
    required this.unit,
    required this.beginningQty,
    required this.received,
    required this.issued,
    required this.endingQty,
    required this.unitCost,
  });

  double get totalValue => endingQty * unitCost;
}

/// Builds a professional, multi-page inventory summary PDF.
/// Same structure as [SalesReportGenerator]; knows nothing about Supabase.
class InventoryReportGenerator {
  InventoryReportGenerator._();

  static Future<Uint8List> generate({
    required String period, // 'Daily' | 'Weekly' | 'Monthly'
    required DateTime periodStart,
    required DateTime periodEnd, // pass an already-clamped end date
    required DateTime generatedAt,
    required String generatedBy,
    required List<InventoryReportEntry> items,
    String businessName = 'SPRJ Paint Center',
    String businessAddress = 'San Pedro, Laguna',
  }) async {
    final doc = pw.Document();

    final double totalReceived = items.fold(0.0, (s, e) => s + e.received);
    final double totalIssued = items.fold(0.0, (s, e) => s + e.issued);
    final double totalValue = items.fold(0.0, (s, e) => s + e.totalValue);
    final int withMovement =
        items.where((e) => e.received > 0 || e.issued > 0).length;
    final int outOfStock = items.where((e) => e.endingQty <= 0).length;

    final reportRef =
        'IR-${generatedAt.year}${_two(generatedAt.month)}'
        '${_two(generatedAt.day)}-${_two(generatedAt.hour)}'
        '${_two(generatedAt.minute)}${_two(generatedAt.second)}';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
        header: (context) => _header(
          context: context,
          businessName: businessName,
          businessAddress: businessAddress,
          period: period,
          periodStart: periodStart,
          periodEnd: periodEnd,
          reportRef: reportRef,
          generatedAt: generatedAt,
        ),
        footer: (context) => _footer(
          context: context,
          generatedBy: generatedBy,
          generatedAt: generatedAt,
        ),
        build: (context) => [
          _summaryBox(
            itemCount: items.length,
            totalReceived: totalReceived,
            totalIssued: totalIssued,
            totalValue: totalValue,
            withMovement: withMovement,
            outOfStock: outOfStock,
          ),
          pw.SizedBox(height: 16),
          _table(context, items),
          pw.SizedBox(height: 4),
          _totalsRow(totalReceived, totalIssued, totalValue),
          pw.SizedBox(height: 32),
          _signatureBlock(),
        ],
      ),
    );

    return doc.save();
  }

  // --- Header / Footer ---------------------------------------------------

  static pw.Widget _header({
    required pw.Context context,
    required String businessName,
    required String businessAddress,
    required String period,
    required DateTime periodStart,
    required DateTime periodEnd,
    required String reportRef,
    required DateTime generatedAt,
  }) {
    if (context.pageNumber == 1) {
      final asOf = ReportPeriodText.asOf(generatedAt, periodEnd);
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    businessName,
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    businessAddress,
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
              pw.Text(
                'Report Ref: $reportRef',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Inventory Summary Report',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '$period Report:  ${ReportPeriodText.label(period, periodStart, periodEnd)}',
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
          ),
          if (asOf != null) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              asOf,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ],
          pw.SizedBox(height: 12),
          pw.Divider(color: PdfColors.grey400, thickness: 1),
        ],
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              '$businessName - Inventory Summary Report (continued)',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              reportRef,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: PdfColors.grey300, thickness: 0.5),
      ],
    );
  }

  static pw.Widget _footer({
    required pw.Context context,
    required String generatedBy,
    required DateTime generatedAt,
  }) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey300, thickness: 0.5),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated by $generatedBy on ${_formatDateTime(generatedAt)}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
      ],
    );
  }

  // --- Summary box -------------------------------------------------------

  static pw.Widget _summaryBox({
    required int itemCount,
    required double totalReceived,
    required double totalIssued,
    required double totalValue,
    required int withMovement,
    required int outOfStock,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _summaryLine('Total Items Tracked', '$itemCount'),
                _summaryLine('Total Units Received', _qty(totalReceived)),
                _summaryLine('Total Units Issued', _qty(totalIssued)),
                pw.SizedBox(height: 6),
                pw.Text(
                  'INVENTORY VALUE: ${_currency(totalValue)}',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green800,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 24),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'STOCK STATUS',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 6),
                _summaryLine('Items With Movement', '$withMovement'),
                _summaryLine('Items Without Movement', '${itemCount - withMovement}'),
                _summaryLine(
                  'Out of Stock',
                  '$outOfStock',
                  color: outOfStock > 0 ? PdfColors.red700 : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _summaryLine(String label, String value, {PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // --- Table -------------------------------------------------------------

  static pw.Widget _table(pw.Context context, List<InventoryReportEntry> items) {
    final headers = [
      'Item Code',
      'Item Name',
      'Beginning',
      'Received',
      'Issued',
      'Ending',
      'Unit Cost',
      'Total Value',
    ];

    final data = items.map((e) {
      return [
        e.sku,
        e.name,
        '${_qty(e.beginningQty)} ${e.unit}',
        e.received > 0 ? _qty(e.received) : '-',
        e.issued > 0 ? _qty(e.issued) : '-',
        '${_qty(e.endingQty)} ${e.unit}',
        _currency(e.unitCost),
        _currency(e.totalValue),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      context: context,
      headers: headers,
      data: data,
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 9,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      headerPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      cellAlignments: const {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.centerRight,
        7: pw.Alignment.centerRight,
      },
      columnWidths: {
        0: const pw.FlexColumnWidth(1.6),
        1: const pw.FlexColumnWidth(3.4),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(1.2),
        5: const pw.FlexColumnWidth(1.5),
        6: const pw.FlexColumnWidth(1.4),
        7: const pw.FlexColumnWidth(1.7),
      },
    );
  }

  static pw.Widget _totalsRow(
    double totalReceived,
    double totalIssued,
    double totalValue,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey700, width: 1),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text(
            'TOTAL   Received: ${_qty(totalReceived)}    '
            'Issued: ${_qty(totalIssued)}    '
            'Inventory Value: ',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.Text(
            _currency(totalValue),
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // --- Signature block ---------------------------------------------------

  static pw.Widget _signatureBlock() {
    pw.Widget line(String label) {
      return pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(height: 24),
            pw.Container(height: 1, color: PdfColors.grey500),
            pw.SizedBox(height: 4),
            pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ],
        ),
      );
    }

    return pw.Row(
      children: [
        line('Prepared by'),
        pw.SizedBox(width: 24),
        line('Reviewed by'),
        pw.SizedBox(width: 24),
        line('Approved by'),
      ],
    );
  }

  // --- Formatting helpers ------------------------------------------------

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _qty(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  // "P" instead of the peso glyph: PDF core fonts don't include it.
  static String _currency(double value) {
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final withCommas = value
        .toStringAsFixed(2)
        .replaceAllMapped(reg, (m) => '${m[1]},');
    return 'P$withCommas';
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _formatDateTime(DateTime d) {
    final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final period = d.hour >= 12 ? 'PM' : 'AM';
    return '${_months[d.month - 1]} ${d.day}, ${d.year}, $hour:${_two(d.minute)} $period';
  }

  static String _formatDate(DateTime d) =>
      '${_months[d.month - 1]} ${d.day}, ${d.year}';

  static String _formatRange(DateTime start, DateTime end) {
    if (_isSameDay(start, end)) return _formatDate(start);
    return '${_formatDate(start)} - ${_formatDate(end)}';
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}