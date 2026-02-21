import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/themes.dart';
import '../../services/report_service.dart';
import '../../services/report_pdf_service.dart';

class VendorWisePurchasesReport extends StatefulWidget {
  const VendorWisePurchasesReport({super.key});

  @override
  State<VendorWisePurchasesReport> createState() => _VendorWisePurchasesReportState();
}

class _VendorWisePurchasesReportState extends State<VendorWisePurchasesReport> {
  final _reportService = ReportService();
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final _dateFormat = DateFormat('dd MMM yyyy');

  List<VendorWisePurchaseItem> _items = [];
  bool _isLoading = false;
  bool _isExporting = false;

  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = now;
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    final items = await _reportService.getVendorWisePurchases(
      startDate: _startDate,
      endDate: _endDate,
    );
    if (mounted) {
      setState(() {
        _items = items;
        _isLoading = false;
      });
    }
  }

  void _setPreset(String preset) {
    final now = DateTime.now();
    switch (preset) {
      case 'thisMonth':
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = now;
        break;
      case 'lastMonth':
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        _startDate = lastMonth;
        _endDate = DateTime(now.year, now.month, 0);
        break;
      case 'thisQuarter':
        final quarterStart = ((now.month - 1) ~/ 3) * 3 + 1;
        _startDate = DateTime(now.year, quarterStart, 1);
        _endDate = now;
        break;
      case 'thisYear':
        if (now.month >= 4) {
          _startDate = DateTime(now.year, 4, 1);
        } else {
          _startDate = DateTime(now.year - 1, 4, 1);
        }
        _endDate = now;
        break;
    }
    setState(() {});
    _loadReport();
  }

  Future<void> _pickStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _startDate = date);
      _loadReport();
    }
  }

  Future<void> _pickEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _endDate = date);
      _loadReport();
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);
    try {
      final items = _items.map((item) => {
        'vendorName': item.vendorName,
        'billCount': item.billCount,
        'purchaseAmount': item.purchaseAmount,
        'gstAmount': item.gstAmount,
        'totalAmount': item.totalAmount,
      }).toList();

      final pdfBytes = await ReportPdfService.generateReportPdf(
        reportType: 'vendor_wise_purchases',
        items: items,
        startDate: _startDate,
        endDate: _endDate,
      );

      final savedPath = await ReportPdfService.saveReportPdf(pdfBytes, 'vendor_wise_purchases.pdf');

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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Vendor-wise Purchases', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      SizedBox(height: 4),
                      Text('Purchase breakdown per vendor', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
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
            _buildDateFilters(),
            const SizedBox(height: 16),
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

  Widget _buildDateFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _buildDateField('From', _startDate, _pickStartDate),
          const SizedBox(width: 16),
          _buildDateField('To', _endDate, _pickEndDate),
          const SizedBox(width: 24),
          _buildPresetButton('This Month', 'thisMonth'),
          const SizedBox(width: 8),
          _buildPresetButton('Last Month', 'lastMonth'),
          const SizedBox(width: 8),
          _buildPresetButton('This Quarter', 'thisQuarter'),
          const SizedBox(width: 8),
          _buildPresetButton('This Year', 'thisYear'),
        ],
      ),
    );
  }

  Widget _buildDateField(String label, DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$label: ', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            Text(_dateFormat.format(date), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(width: 8),
            const Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetButton(String label, String preset) {
    return OutlinedButton(
      onPressed: () => _setPreset(preset),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 12),
        minimumSize: Size.zero,
      ),
      child: Text(label),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.store, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('No purchase data found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Try adjusting the date range', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildTable() {
    int totalCount = 0;
    double totalPurchases = 0, totalGst = 0, totalAmount = 0;
    for (final item in _items) {
      totalCount += item.billCount;
      totalPurchases += item.purchaseAmount;
      totalGst += item.gstAmount;
      totalAmount += item.totalAmount;
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
                Expanded(flex: 1, child: Text('Bills', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text('Purchase Amount', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('GST', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('Total', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.right)),
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
                      Expanded(flex: 1, child: Text('${item.billCount}', style: const TextStyle(fontSize: 13), textAlign: TextAlign.center)),
                      Expanded(flex: 2, child: Text(_currencyFormat.format(item.purchaseAmount), style: const TextStyle(fontSize: 13), textAlign: TextAlign.right)),
                      Expanded(flex: 2, child: Text(_currencyFormat.format(item.gstAmount), style: const TextStyle(fontSize: 13), textAlign: TextAlign.right)),
                      Expanded(flex: 2, child: Text(_currencyFormat.format(item.totalAmount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
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
              color: AppColors.info.withOpacity(0.05),
              border: Border(top: BorderSide(color: AppColors.border, width: 2)),
            ),
            child: Row(
              children: [
                const Expanded(flex: 3, child: Text('TOTAL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                Expanded(flex: 1, child: Text('$totalCount', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text(_currencyFormat.format(totalPurchases), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text(_currencyFormat.format(totalGst), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text(_currencyFormat.format(totalAmount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.info), textAlign: TextAlign.right)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
