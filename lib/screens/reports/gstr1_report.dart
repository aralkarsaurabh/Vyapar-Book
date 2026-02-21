import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/themes.dart';
import '../../services/report_service.dart';
import '../../services/report_pdf_service.dart';

class Gstr1Report extends StatefulWidget {
  const Gstr1Report({super.key});

  @override
  State<Gstr1Report> createState() => _Gstr1ReportState();
}

class _Gstr1ReportState extends State<Gstr1Report> {
  final _reportService = ReportService();
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 2);
  final _dateFormat = DateFormat('dd MMM yyyy');

  Gstr1Data? _data;
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
    final data = await _reportService.getGstr1Data(startDate: _startDate, endDate: _endDate);
    if (mounted) {
      setState(() {
        _data = data;
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
    final date = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (date != null) {
      setState(() => _startDate = date);
      _loadReport();
    }
  }

  Future<void> _pickEndDate() async {
    final date = await showDatePicker(context: context, initialDate: _endDate, firstDate: _startDate, lastDate: DateTime.now());
    if (date != null) {
      setState(() => _endDate = date);
      _loadReport();
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);
    try {
      if (_data == null) return;
      final items = <Map<String, dynamic>>[];
      for (final inv in _data!.b2bInvoices) {
        items.add({
          'section': 'B2B',
          'customerGstin': inv.customerGstin,
          'invoiceNumber': inv.invoiceNumber,
          'invoiceDate': inv.invoiceDate.toIso8601String(),
          'customerName': inv.customerName,
          'taxableAmount': inv.taxableAmount,
          'cgst': inv.cgst,
          'sgst': inv.sgst,
          'igst': inv.igst,
          'total': inv.total,
        });
      }
      for (final inv in _data!.b2cInvoices) {
        items.add({
          'section': 'B2C',
          'customerGstin': '',
          'invoiceNumber': inv.invoiceNumber,
          'invoiceDate': inv.invoiceDate.toIso8601String(),
          'customerName': inv.customerName,
          'taxableAmount': inv.taxableAmount,
          'cgst': inv.cgst,
          'sgst': inv.sgst,
          'igst': inv.igst,
          'total': inv.total,
        });
      }

      final pdfBytes = await ReportPdfService.generateReportPdf(
        reportType: 'gstr1',
        items: items,
        startDate: _startDate,
        endDate: _endDate,
      );

      final savedPath = await ReportPdfService.saveReportPdf(pdfBytes, 'gstr1_report.pdf');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF saved to: $savedPath'), backgroundColor: AppColors.success, duration: const Duration(seconds: 4)),
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
            Row(
              children: [
                IconButton(
                  onPressed: () => context.go('/dashboard/reports'),
                  icon: const Icon(Icons.arrow_back),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.border)),
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GSTR-1 Sales Report', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      SizedBox(height: 4),
                      Text('B2B and B2C sales breakdown for GSTR-1 filing', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _data == null || _isExporting ? null : _exportPdf,
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
            const SizedBox(height: 24),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _data == null
                      ? const Center(child: Text('No data'))
                      : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
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
        decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
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
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), textStyle: const TextStyle(fontSize: 12), minimumSize: Size.zero),
      child: Text(label),
    );
  }

  Widget _buildContent() {
    final d = _data!;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards
          Row(
            children: [
              _buildSummaryCard('B2B Invoices', d.b2bInvoices.length, d.b2bTotalAmount, AppColors.primary),
              const SizedBox(width: 16),
              _buildSummaryCard('B2C Invoices', d.b2cInvoices.length, d.b2cTotalAmount, AppColors.info),
              const SizedBox(width: 16),
              _buildSummaryCard('Total Invoices', d.b2bInvoices.length + d.b2cInvoices.length, d.b2bTotalAmount + d.b2cTotalAmount, AppColors.success),
            ],
          ),
          const SizedBox(height: 24),

          // B2B Section
          _buildSectionHeader('B2B Supplies (With GSTIN)', Icons.business, AppColors.primary, '${d.b2bInvoices.length} invoices'),
          const SizedBox(height: 8),
          if (d.b2bInvoices.isEmpty)
            _buildEmptySection('No B2B invoices in this period')
          else
            _buildInvoiceTable(d.b2bInvoices, showGstin: true),
          const SizedBox(height: 24),

          // B2C Section
          _buildSectionHeader('B2C Supplies (Without GSTIN)', Icons.person, AppColors.info, '${d.b2cInvoices.length} invoices'),
          const SizedBox(height: 8),
          if (d.b2cInvoices.isEmpty)
            _buildEmptySection('No B2C invoices in this period')
          else
            _buildInvoiceTable(d.b2cInvoices, showGstin: false),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, int count, double amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Text(_currencyFormat.format(amount), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text('$count invoices', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color, String subtitle) {
    return Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const Spacer(),
        Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildEmptySection(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Center(child: Text(message, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
    );
  }

  Widget _buildInvoiceTable(List<Gstr1InvoiceItem> invoices, {required bool showGstin}) {
    double totalTaxable = 0, totalCgst = 0, totalSgst = 0, totalIgst = 0, totalAmount = 0;
    for (final inv in invoices) {
      totalTaxable += inv.taxableAmount;
      totalCgst += inv.cgst;
      totalSgst += inv.sgst;
      totalIgst += inv.igst;
      totalAmount += inv.total;
    }

    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Row(
              children: [
                if (showGstin) const Expanded(flex: 3, child: Text('GSTIN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                const Expanded(flex: 2, child: Text('Invoice No', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                Expanded(flex: showGstin ? 2 : 3, child: const Text('Customer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                const Expanded(flex: 2, child: Text('Taxable', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                const Expanded(flex: 1, child: Text('CGST', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                const Expanded(flex: 1, child: Text('SGST', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                const Expanded(flex: 1, child: Text('IGST', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                const Expanded(flex: 2, child: Text('Total', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.right)),
              ],
            ),
          ),
          // Rows
          ...invoices.map((inv) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5)))),
                child: Row(
                  children: [
                    if (showGstin) Expanded(flex: 3, child: Text(inv.customerGstin, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis)),
                    Expanded(flex: 2, child: Text(inv.invoiceNumber, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                    Expanded(flex: showGstin ? 2 : 3, child: Text(inv.customerName, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                    Expanded(flex: 2, child: Text(_currencyFormat.format(inv.taxableAmount), style: const TextStyle(fontSize: 12), textAlign: TextAlign.right)),
                    Expanded(flex: 1, child: Text(_currencyFormat.format(inv.cgst), style: const TextStyle(fontSize: 12), textAlign: TextAlign.right)),
                    Expanded(flex: 1, child: Text(_currencyFormat.format(inv.sgst), style: const TextStyle(fontSize: 12), textAlign: TextAlign.right)),
                    Expanded(flex: 1, child: Text(_currencyFormat.format(inv.igst), style: const TextStyle(fontSize: 12), textAlign: TextAlign.right)),
                    Expanded(flex: 2, child: Text(_currencyFormat.format(inv.total), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                  ],
                ),
              )),
          // Total
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              border: Border(top: BorderSide(color: AppColors.border, width: 2)),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
            ),
            child: Row(
              children: [
                if (showGstin) const Expanded(flex: 3, child: SizedBox()),
                const Expanded(flex: 2, child: Text('TOTAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                Expanded(flex: showGstin ? 2 : 3, child: const SizedBox()),
                Expanded(flex: 2, child: Text(_currencyFormat.format(totalTaxable), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                Expanded(flex: 1, child: Text(_currencyFormat.format(totalCgst), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                Expanded(flex: 1, child: Text(_currencyFormat.format(totalSgst), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                Expanded(flex: 1, child: Text(_currencyFormat.format(totalIgst), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text(_currencyFormat.format(totalAmount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
