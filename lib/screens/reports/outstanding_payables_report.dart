import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/themes.dart';
import '../../services/report_service.dart';
import '../../services/report_pdf_service.dart';

class OutstandingPayablesReport extends StatefulWidget {
  const OutstandingPayablesReport({super.key});

  @override
  State<OutstandingPayablesReport> createState() => _OutstandingPayablesReportState();
}

class _OutstandingPayablesReportState extends State<OutstandingPayablesReport> {
  final _reportService = ReportService();
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final _dateFormat = DateFormat('dd MMM yyyy');

  List<OutstandingPayableItem> _items = [];
  bool _isLoading = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    final items = await _reportService.getOutstandingPayables();
    if (mounted) {
      setState(() {
        _items = items;
        _isLoading = false;
      });
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);
    try {
      final items = _items.map((item) => {
        'vendorName': item.vendorName,
        'totalBilled': item.totalBilled,
        'amountPaid': item.amountPaid,
        'outstanding': item.outstanding,
        'billCount': item.billCount,
      }).toList();

      final pdfBytes = await ReportPdfService.generateReportPdf(
        reportType: 'outstanding_payables',
        items: items,
      );

      final savedPath = await ReportPdfService.saveReportPdf(pdfBytes, 'outstanding_payables.pdf');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved to: $savedPath'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export PDF: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                IconButton(
                  onPressed: () => context.go('/dashboard/reports'),
                  icon: const Icon(Icons.arrow_back),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Outstanding Payables', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text('As on ${_dateFormat.format(DateTime.now())} - money you owe', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _loadReport,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _items.isEmpty || _isExporting ? null : _exportPdf,
                  icon: _isExporting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.picture_as_pdf, size: 18),
                  label: Text(_isExporting ? 'Generating...' : 'Export PDF'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Summary cards
            if (!_isLoading && _items.isNotEmpty) ...[
              _buildSummaryCards(),
              const SizedBox(height: 16),
            ],

            // Table
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? _buildEmptyState()
                      : _buildTable(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    double totalBilled = 0, totalPaid = 0, totalOutstanding = 0;
    for (final item in _items) {
      totalBilled += item.totalBilled;
      totalPaid += item.amountPaid;
      totalOutstanding += item.outstanding;
    }

    return Row(
      children: [
        _buildSummaryCard('Total Billed', totalBilled, AppColors.primary),
        const SizedBox(width: 16),
        _buildSummaryCard('Amount Paid', totalPaid, AppColors.success),
        const SizedBox(width: 16),
        _buildSummaryCard('Outstanding', totalOutstanding, AppColors.warning),
        const SizedBox(width: 16),
        _buildSummaryCard('Vendors', _items.length.toDouble(), AppColors.info, isCount: true),
      ],
    );
  }

  Widget _buildSummaryCard(String label, double value, Color color, {bool isCount = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Text(
              isCount ? '${value.toInt()}' : _currencyFormat.format(value),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: AppColors.success.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('No outstanding payables', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('All bills have been paid', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildTable() {
    double totalBilled = 0, totalPaid = 0, totalOutstanding = 0;
    int totalCount = 0;
    for (final item in _items) {
      totalBilled += item.totalBilled;
      totalPaid += item.amountPaid;
      totalOutstanding += item.outstanding;
      totalCount += item.billCount;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('Vendor', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                Expanded(flex: 2, child: Text('Total Billed', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('Amount Paid', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('Outstanding', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                Expanded(flex: 1, child: Text('Bills', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.center)),
              ],
            ),
          ),
          // Rows
          Expanded(
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5)))),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.vendorName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
                            if (item.vendorVyaparId.isNotEmpty)
                              Text(item.vendorVyaparId, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Expanded(flex: 2, child: Text(_currencyFormat.format(item.totalBilled), style: const TextStyle(fontSize: 13), textAlign: TextAlign.right)),
                      Expanded(flex: 2, child: Text(_currencyFormat.format(item.amountPaid), style: const TextStyle(fontSize: 13, color: AppColors.success), textAlign: TextAlign.right)),
                      Expanded(flex: 2, child: Text(_currencyFormat.format(item.outstanding), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.warning), textAlign: TextAlign.right)),
                      Expanded(flex: 1, child: Text('${item.billCount}', style: const TextStyle(fontSize: 13), textAlign: TextAlign.center)),
                    ],
                  ),
                );
              },
            ),
          ),
          // Totals
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.05),
              border: Border(top: BorderSide(color: AppColors.border, width: 2)),
            ),
            child: Row(
              children: [
                const Expanded(flex: 3, child: Text('TOTAL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                Expanded(flex: 2, child: Text(_currencyFormat.format(totalBilled), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text(_currencyFormat.format(totalPaid), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.success), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text(_currencyFormat.format(totalOutstanding), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.warning), textAlign: TextAlign.right)),
                Expanded(flex: 1, child: Text('$totalCount', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
