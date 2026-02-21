import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/themes.dart';
import '../../services/report_service.dart';
import '../../services/report_pdf_service.dart';

class GstSummaryReport extends StatefulWidget {
  const GstSummaryReport({super.key});

  @override
  State<GstSummaryReport> createState() => _GstSummaryReportState();
}

class _GstSummaryReportState extends State<GstSummaryReport> {
  final _reportService = ReportService();
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 2);
  final _dateFormat = DateFormat('dd MMM yyyy');

  GstSummaryData? _data;
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
    final data = await _reportService.getGstSummary(
      startDate: _startDate,
      endDate: _endDate,
    );
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
      if (_data == null) return;
      final d = _data!;
      final items = [
        {
          'description': 'Output CGST (on Sales)',
          'outputAmount': d.outputCgst,
          'inputAmount': 0.0,
          'netAmount': d.outputCgst,
        },
        {
          'description': 'Output SGST (on Sales)',
          'outputAmount': d.outputSgst,
          'inputAmount': 0.0,
          'netAmount': d.outputSgst,
        },
        {
          'description': 'Output IGST (on Sales)',
          'outputAmount': d.outputIgst,
          'inputAmount': 0.0,
          'netAmount': d.outputIgst,
        },
        {
          'description': 'Input CGST (on Purchases)',
          'outputAmount': 0.0,
          'inputAmount': d.inputCgst,
          'netAmount': -d.inputCgst,
        },
        {
          'description': 'Input SGST (on Purchases)',
          'outputAmount': 0.0,
          'inputAmount': d.inputSgst,
          'netAmount': -d.inputSgst,
        },
        {
          'description': 'Input IGST (on Purchases)',
          'outputAmount': 0.0,
          'inputAmount': d.inputIgst,
          'netAmount': -d.inputIgst,
        },
      ];

      final pdfBytes = await ReportPdfService.generateReportPdf(
        reportType: 'gst_summary',
        items: items,
        startDate: _startDate,
        endDate: _endDate,
      );

      final savedPath = await ReportPdfService.saveReportPdf(pdfBytes, 'gst_summary.pdf');

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
                      Text('GST Summary', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      SizedBox(height: 4),
                      Text('Output GST vs Input GST - Net tax liability', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
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
                      : SingleChildScrollView(child: _buildContent()),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary cards
        Row(
          children: [
            _buildSummaryCard('Total Output GST', d.totalOutput, AppColors.error, 'Collected on sales'),
            const SizedBox(width: 16),
            _buildSummaryCard('Total Input GST', d.totalInput, AppColors.success, 'Paid on purchases'),
            const SizedBox(width: 16),
            _buildSummaryCard('Net GST Payable', d.netPayable, d.netPayable > 0 ? AppColors.error : AppColors.success, d.netPayable > 0 ? 'Payable to Govt' : 'Refundable / Credit'),
          ],
        ),
        const SizedBox(height: 24),

        // Output GST Table
        _buildGstTable(
          title: 'Output GST (Collected on Sales)',
          icon: Icons.arrow_upward,
          color: AppColors.error,
          rows: [
            _GstRow('CGST', d.outputCgst),
            _GstRow('SGST', d.outputSgst),
            _GstRow('IGST', d.outputIgst),
          ],
          total: d.totalOutput,
          subtitle: '${d.salesInvoiceCount} invoices',
        ),
        const SizedBox(height: 16),

        // Input GST Table
        _buildGstTable(
          title: 'Input GST (Paid on Purchases)',
          icon: Icons.arrow_downward,
          color: AppColors.success,
          rows: [
            _GstRow('CGST', d.inputCgst),
            _GstRow('SGST', d.inputSgst),
            _GstRow('IGST', d.inputIgst),
          ],
          total: d.totalInput,
          subtitle: '${d.purchaseBillCount} bills',
        ),
        const SizedBox(height: 16),

        // Net Payable
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: d.netPayable > 0 ? AppColors.error.withOpacity(0.05) : AppColors.success.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: d.netPayable > 0 ? AppColors.error.withOpacity(0.3) : AppColors.success.withOpacity(0.3), width: 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('NET GST LIABILITY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(
                    d.netPayable > 0 ? 'Amount payable to the government' : 'Input credit available',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
              Text(
                _currencyFormat.format(d.netPayable.abs()),
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: d.netPayable > 0 ? AppColors.error : AppColors.success),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Breakdown table
        _buildBreakdownTable(d),
      ],
    );
  }

  Widget _buildSummaryCard(String label, double value, Color color, String sublabel) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Text(_currencyFormat.format(value), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(sublabel, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildGstTable({
    required String title,
    required IconData icon,
    required Color color,
    required List<_GstRow> rows,
    required double total,
    required String subtitle,
  }) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          ...rows.map((r) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5)))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(r.label, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                    Text(_currencyFormat.format(r.amount), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
              )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                Text(_currencyFormat.format(total), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownTable(GstSummaryData d) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text('Tax Component', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                Expanded(flex: 2, child: Text('Output (Sales)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('Input (Purchases)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('Net Payable', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.right)),
              ],
            ),
          ),
          _buildBreakdownRow('CGST', d.outputCgst, d.inputCgst),
          _buildBreakdownRow('SGST', d.outputSgst, d.inputSgst),
          _buildBreakdownRow('IGST', d.outputIgst, d.inputIgst),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              border: Border(top: BorderSide(color: AppColors.border, width: 2)),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Expanded(flex: 2, child: Text('TOTAL', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                Expanded(flex: 2, child: Text(_currencyFormat.format(d.totalOutput), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.error), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text(_currencyFormat.format(d.totalInput), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.success), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text(_currencyFormat.format(d.netPayable), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: d.netPayable > 0 ? AppColors.error : AppColors.success), textAlign: TextAlign.right)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String label, double output, double input) {
    final net = output - input;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5)))),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary))),
          Expanded(flex: 2, child: Text(_currencyFormat.format(output), style: const TextStyle(fontSize: 13, color: AppColors.error), textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text(_currencyFormat.format(input), style: const TextStyle(fontSize: 13, color: AppColors.success), textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text(_currencyFormat.format(net), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: net > 0 ? AppColors.error : AppColors.success), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _GstRow {
  final String label;
  final double amount;
  _GstRow(this.label, this.amount);
}
