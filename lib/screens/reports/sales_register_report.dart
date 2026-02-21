import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/themes.dart';
import '../../services/report_service.dart';
import '../../services/report_pdf_service.dart';

class SalesRegisterReport extends StatefulWidget {
  const SalesRegisterReport({super.key});

  @override
  State<SalesRegisterReport> createState() => _SalesRegisterReportState();
}

class _SalesRegisterReportState extends State<SalesRegisterReport> {
  final _reportService = ReportService();
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final _dateFormat = DateFormat('dd MMM yyyy');

  List<SalesRegisterItem> _items = [];
  bool _isLoading = false;
  bool _isExporting = false;
  int _currentPage = 0;
  final int _itemsPerPage = 10;

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
    final items = await _reportService.getSalesRegister(
      startDate: _startDate,
      endDate: _endDate,
    );
    if (mounted) {
      setState(() {
        _items = items;
        _isLoading = false;
        _currentPage = 0;
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
        // Indian financial year: April to March
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
        'invoiceDate': item.invoiceDate.toIso8601String(),
        'invoiceNumber': item.invoiceNumber,
        'customerName': item.customerName,
        'taxableAmount': item.taxableAmount,
        'cgst': item.cgst,
        'sgst': item.sgst,
        'igst': item.igst,
        'total': item.total,
      }).toList();

      final pdfBytes = await ReportPdfService.generateReportPdf(
        reportType: 'sales_register',
        items: items,
        startDate: _startDate,
        endDate: _endDate,
      );

      final savedPath = await ReportPdfService.saveReportPdf(pdfBytes, 'sales_register.pdf');

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
                      Text(
                        'Sales Register',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'All invoices with date, customer, amount, and GST details',
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _items.isEmpty || _isExporting ? null : _exportPdf,
                  icon: _isExporting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.picture_as_pdf, size: 18),
                  label: Text(_isExporting ? 'Generating...' : 'Export PDF'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Date filters
            _buildDateFilters(),
            const SizedBox(height: 16),

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
          // Start date
          _buildDateField('From', _startDate, _pickStartDate),
          const SizedBox(width: 16),
          _buildDateField('To', _endDate, _pickEndDate),
          const SizedBox(width: 24),
          // Presets
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
            Text(
              '$label: ',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            Text(
              _dateFormat.format(date),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
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
          Icon(Icons.receipt_long, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text(
            'No invoices found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting the date range',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    final totalPages = (_items.length / _itemsPerPage).ceil();
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = min(startIndex + _itemsPerPage, _items.length);
    final pageItems = _items.sublist(startIndex, endIndex);

    // Calculate totals for all items
    double totalTaxable = 0, totalCgst = 0, totalSgst = 0, totalIgst = 0, totalAmount = 0;
    for (final item in _items) {
      totalTaxable += item.taxableAmount;
      totalCgst += item.cgst;
      totalSgst += item.sgst;
      totalIgst += item.igst;
      totalAmount += item.total;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text('Date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                Expanded(flex: 2, child: Text('Invoice No', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                Expanded(flex: 3, child: Text('Customer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                Expanded(flex: 2, child: Text('Taxable Amt', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('CGST', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('SGST', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('IGST', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('Total', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.right)),
              ],
            ),
          ),
          // Table rows
          Expanded(
            child: ListView.builder(
              itemCount: pageItems.length,
              itemBuilder: (context, index) {
                final item = pageItems[index];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5))),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text(_dateFormat.format(item.invoiceDate), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
                      Expanded(flex: 2, child: Text(item.invoiceNumber, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
                      Expanded(flex: 3, child: Text(item.customerName, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis)),
                      Expanded(flex: 2, child: Text(_currencyFormat.format(item.taxableAmount), style: const TextStyle(fontSize: 13, color: AppColors.textPrimary), textAlign: TextAlign.right)),
                      Expanded(flex: 2, child: Text(_currencyFormat.format(item.cgst), style: const TextStyle(fontSize: 13, color: AppColors.textPrimary), textAlign: TextAlign.right)),
                      Expanded(flex: 2, child: Text(_currencyFormat.format(item.sgst), style: const TextStyle(fontSize: 13, color: AppColors.textPrimary), textAlign: TextAlign.right)),
                      Expanded(flex: 2, child: Text(_currencyFormat.format(item.igst), style: const TextStyle(fontSize: 13, color: AppColors.textPrimary), textAlign: TextAlign.right)),
                      Expanded(flex: 2, child: Text(_currencyFormat.format(item.total), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary), textAlign: TextAlign.right)),
                    ],
                  ),
                );
              },
            ),
          ),
          // Totals row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              border: Border(top: BorderSide(color: AppColors.border, width: 2)),
            ),
            child: Row(
              children: [
                const Expanded(flex: 2, child: SizedBox()),
                const Expanded(flex: 2, child: SizedBox()),
                const Expanded(flex: 3, child: Text('TOTAL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                Expanded(flex: 2, child: Text(_currencyFormat.format(totalTaxable), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text(_currencyFormat.format(totalCgst), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text(_currencyFormat.format(totalSgst), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text(_currencyFormat.format(totalIgst), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text(_currencyFormat.format(totalAmount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary), textAlign: TextAlign.right)),
              ],
            ),
          ),
          // Pagination
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${startIndex + 1}-$endIndex of ${_items.length} invoices',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                      icon: const Icon(Icons.chevron_left, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.background,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Page ${_currentPage + 1} of $totalPages',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                    IconButton(
                      onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                      icon: const Icon(Icons.chevron_right, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.background,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
