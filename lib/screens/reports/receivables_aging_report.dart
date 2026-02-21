import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/themes.dart';
import '../../services/report_service.dart';
import '../../services/report_pdf_service.dart';

class ReceivablesAgingReport extends StatefulWidget {
  const ReceivablesAgingReport({super.key});

  @override
  State<ReceivablesAgingReport> createState() => _ReceivablesAgingReportState();
}

class _ReceivablesAgingReportState extends State<ReceivablesAgingReport> {
  final _reportService = ReportService();
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 2);
  final _dateFormat = DateFormat('dd MMM yyyy');

  List<ReceivablesAgingItem> _items = [];
  bool _isLoading = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    final items = await _reportService.getReceivablesAging();
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
        'customerName': item.customerName,
        'totalOutstanding': item.totalOutstanding,
        'current': item.current,
        'overdue1to30': item.overdue1to30,
        'overdue31to60': item.overdue31to60,
        'overdue60plus': item.overdue60plus,
        'invoiceCount': item.invoiceCount,
      }).toList();

      final pdfBytes = await ReportPdfService.generateReportPdf(
        reportType: 'receivables_aging',
        items: items,
      );

      final savedPath = await ReportPdfService.saveReportPdf(pdfBytes, 'receivables_aging.pdf');

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
                      const Text('Receivables Aging', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text('As on ${_dateFormat.format(DateTime.now())} - overdue analysis by aging buckets', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
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
    double totalOutstanding = 0, totalCurrent = 0, total1to30 = 0, total31to60 = 0, total60plus = 0;
    for (final item in _items) {
      totalOutstanding += item.totalOutstanding;
      totalCurrent += item.current;
      total1to30 += item.overdue1to30;
      total31to60 += item.overdue31to60;
      total60plus += item.overdue60plus;
    }

    return Row(
      children: [
        _buildSummaryCard('Total Outstanding', totalOutstanding, AppColors.error),
        const SizedBox(width: 12),
        _buildSummaryCard('Current (Not Due)', totalCurrent, AppColors.success),
        const SizedBox(width: 12),
        _buildSummaryCard('1-30 Days Overdue', total1to30, AppColors.warning),
        const SizedBox(width: 12),
        _buildSummaryCard('31-60 Days Overdue', total31to60, AppColors.error),
        const SizedBox(width: 12),
        _buildSummaryCard('60+ Days Overdue', total60plus, AppColors.error),
      ],
    );
  }

  Widget _buildSummaryCard(String label, double value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Text(
              _currencyFormat.format(value),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color),
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
          const Text('No outstanding receivables', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('All invoices have been paid', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildTable() {
    double totalOutstanding = 0, totalCurrent = 0, total1to30 = 0, total31to60 = 0, total60plus = 0;
    int totalCount = 0;
    for (final item in _items) {
      totalOutstanding += item.totalOutstanding;
      totalCurrent += item.current;
      total1to30 += item.overdue1to30;
      total31to60 += item.overdue31to60;
      total60plus += item.overdue60plus;
      totalCount += item.invoiceCount;
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
                Expanded(flex: 3, child: Text('Customer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                Expanded(flex: 2, child: Text('Total', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('Current', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('1-30 Days', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('31-60 Days', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('60+ Days', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                Expanded(flex: 1, child: Text('Inv', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.center)),
              ],
            ),
          ),
          // Rows
          Expanded(
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final hasOverdue60 = item.overdue60plus > 0;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: hasOverdue60 ? AppColors.error.withOpacity(0.03) : null,
                    border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Flexible(child: Text(item.customerName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis)),
                            if (hasOverdue60) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.warning_amber, size: 16, color: AppColors.error),
                            ],
                          ],
                        ),
                      ),
                      Expanded(flex: 2, child: Text(_currencyFormat.format(item.totalOutstanding), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                      Expanded(flex: 2, child: Text(item.current > 0 ? _currencyFormat.format(item.current) : '-', style: const TextStyle(fontSize: 13, color: AppColors.success), textAlign: TextAlign.right)),
                      Expanded(flex: 2, child: Text(item.overdue1to30 > 0 ? _currencyFormat.format(item.overdue1to30) : '-', style: const TextStyle(fontSize: 13, color: AppColors.warning), textAlign: TextAlign.right)),
                      Expanded(flex: 2, child: Text(item.overdue31to60 > 0 ? _currencyFormat.format(item.overdue31to60) : '-', style: TextStyle(fontSize: 13, color: AppColors.error.withOpacity(0.8)), textAlign: TextAlign.right)),
                      Expanded(flex: 2, child: Text(item.overdue60plus > 0 ? _currencyFormat.format(item.overdue60plus) : '-', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.error), textAlign: TextAlign.right)),
                      Expanded(flex: 1, child: Text('${item.invoiceCount}', style: const TextStyle(fontSize: 13), textAlign: TextAlign.center)),
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
              color: AppColors.error.withOpacity(0.05),
              border: Border(top: BorderSide(color: AppColors.border, width: 2)),
            ),
            child: Row(
              children: [
                const Expanded(flex: 3, child: Text('TOTAL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                Expanded(flex: 2, child: Text(_currencyFormat.format(totalOutstanding), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text(_currencyFormat.format(totalCurrent), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.success), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text(_currencyFormat.format(total1to30), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.warning), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text(_currencyFormat.format(total31to60), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text(_currencyFormat.format(total60plus), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.error), textAlign: TextAlign.right)),
                Expanded(flex: 1, child: Text('$totalCount', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
              ],
            ),
          ),
          // Percentage row
          _buildPercentageRow(totalOutstanding, totalCurrent, total1to30, total31to60, total60plus),
        ],
      ),
    );
  }

  Widget _buildPercentageRow(double total, double current, double d1to30, double d31to60, double d60plus) {
    String pct(double val) => total > 0 ? '${(val / total * 100).toStringAsFixed(0)}%' : '-';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Expanded(flex: 3, child: Text('% of Total', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSecondary))),
          const Expanded(flex: 2, child: SizedBox()),
          Expanded(flex: 2, child: Text(pct(current), style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSecondary), textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text(pct(d1to30), style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSecondary), textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text(pct(d31to60), style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSecondary), textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text(pct(d60plus), style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSecondary), textAlign: TextAlign.right)),
          const Expanded(flex: 1, child: SizedBox()),
        ],
      ),
    );
  }
}
