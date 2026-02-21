import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/themes.dart';
import '../../services/report_service.dart';
import '../../services/report_pdf_service.dart';

class Gstr3bReport extends StatefulWidget {
  const Gstr3bReport({super.key});

  @override
  State<Gstr3bReport> createState() => _Gstr3bReportState();
}

class _Gstr3bReportState extends State<Gstr3bReport> {
  final _reportService = ReportService();
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 2);
  final _dateFormat = DateFormat('dd MMM yyyy');

  Gstr3bData? _data;
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
    final data = await _reportService.getGstr3bData(startDate: _startDate, endDate: _endDate);
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
      final d = _data!;
      final items = [
        {
          'nature': 'Outward taxable supplies (other than zero rated, nil rated and exempted)',
          'taxableValue': d.outwardTaxable,
          'igst': d.outwardIgst,
          'cgst': d.outwardCgst,
          'sgst': d.outwardSgst,
        },
        {
          'nature': 'Inward supplies liable to reverse charge',
          'taxableValue': 0.0,
          'igst': 0.0,
          'cgst': 0.0,
          'sgst': 0.0,
        },
        {
          'nature': 'Eligible ITC - All other ITC',
          'taxableValue': d.inputTaxable,
          'igst': d.inputIgst,
          'cgst': d.inputCgst,
          'sgst': d.inputSgst,
        },
      ];

      final pdfBytes = await ReportPdfService.generateReportPdf(
        reportType: 'gstr3b',
        items: items,
        startDate: _startDate,
        endDate: _endDate,
      );

      final savedPath = await ReportPdfService.saveReportPdf(pdfBytes, 'gstr3b_report.pdf');

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
                      Text('GSTR-3B Summary', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      SizedBox(height: 4),
                      Text('Summary return format for GSTR-3B filing', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
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
        // Table 3.1 - Outward Supplies
        _buildTableSection(
          number: '3.1',
          title: 'Details of Outward Supplies and Inward Supplies Liable to Reverse Charge',
          headers: ['Nature of Supplies', 'Total Taxable Value', 'Integrated Tax', 'Central Tax', 'State/UT Tax'],
          rows: [
            ['(a) Outward taxable supplies\n(other than zero rated, nil rated and exempted)', d.outwardTaxable, d.outwardIgst, d.outwardCgst, d.outwardSgst],
            ['(b) Outward taxable supplies\n(zero rated)', 0.0, 0.0, 0.0, 0.0],
            ['(c) Other outward supplies\n(nil rated, exempted)', 0.0, 0.0, 0.0, 0.0],
            ['(d) Inward supplies\n(liable to reverse charge)', 0.0, 0.0, 0.0, 0.0],
            ['(e) Non-GST outward supplies', 0.0, 0.0, 0.0, 0.0],
          ],
        ),
        const SizedBox(height: 24),

        // Table 4 - Eligible ITC
        _buildTableSection(
          number: '4',
          title: 'Eligible ITC',
          headers: ['Details', 'Total Taxable Value', 'Integrated Tax', 'Central Tax', 'State/UT Tax'],
          rows: [
            ['(A) ITC Available\n(1) Import of goods', 0.0, 0.0, 0.0, 0.0],
            ['(2) Import of services', 0.0, 0.0, 0.0, 0.0],
            ['(3) Inward supplies liable to\nreverse charge', 0.0, 0.0, 0.0, 0.0],
            ['(4) Inward supplies from ISD', 0.0, 0.0, 0.0, 0.0],
            ['(5) All other ITC', d.inputTaxable, d.inputIgst, d.inputCgst, d.inputSgst],
          ],
        ),
        const SizedBox(height: 24),

        // Tax Liability Summary
        _buildNetLiabilitySection(d),
      ],
    );
  }

  Widget _buildTableSection({
    required String number,
    required String title,
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              border: Border(bottom: BorderSide(color: AppColors.border)),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
                  child: Text(number, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
              ],
            ),
          ),
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Row(
              children: headers.asMap().entries.map((entry) {
                final isFirst = entry.key == 0;
                return Expanded(
                  flex: isFirst ? 4 : 2,
                  child: Text(
                    entry.value,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    textAlign: isFirst ? TextAlign.left : TextAlign.right,
                  ),
                );
              }).toList(),
            ),
          ),
          // Data rows
          ...rows.map((row) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5)))),
                child: Row(
                  children: row.asMap().entries.map((entry) {
                    final isFirst = entry.key == 0;
                    if (isFirst) {
                      return Expanded(flex: 4, child: Text(entry.value.toString(), style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.3)));
                    }
                    final val = (entry.value as double);
                    return Expanded(
                      flex: 2,
                      child: Text(
                        val > 0 ? _currencyFormat.format(val) : '-',
                        style: TextStyle(fontSize: 12, color: val > 0 ? AppColors.textPrimary : AppColors.textSecondary),
                        textAlign: TextAlign.right,
                      ),
                    );
                  }).toList(),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildNetLiabilitySection(Gstr3bData d) {
    final netIgst = d.outwardIgst - d.inputIgst;
    final netCgst = d.outwardCgst - d.inputCgst;
    final netSgst = d.outwardSgst - d.inputSgst;
    final netTotal = netIgst + netCgst + netSgst;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: netTotal > 0 ? AppColors.error.withOpacity(0.5) : AppColors.success.withOpacity(0.5), width: 2),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: (netTotal > 0 ? AppColors.error : AppColors.success).withOpacity(0.05),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Icon(netTotal > 0 ? Icons.payment : Icons.savings, color: netTotal > 0 ? AppColors.error : AppColors.success, size: 20),
                const SizedBox(width: 12),
                const Expanded(child: Text('Net Tax Liability (Output - Input)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                Text(
                  netTotal > 0 ? 'TAX PAYABLE' : 'ITC AVAILABLE',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: netTotal > 0 ? AppColors.error : AppColors.success),
                ),
              ],
            ),
          ),
          _buildLiabilityRow('Integrated Tax (IGST)', d.outwardIgst, d.inputIgst, netIgst),
          _buildLiabilityRow('Central Tax (CGST)', d.outwardCgst, d.inputCgst, netCgst),
          _buildLiabilityRow('State/UT Tax (SGST)', d.outwardSgst, d.inputSgst, netSgst),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: (netTotal > 0 ? AppColors.error : AppColors.success).withOpacity(0.05),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(10), bottomRight: Radius.circular(10)),
              border: Border(top: BorderSide(color: AppColors.border, width: 2)),
            ),
            child: Row(
              children: [
                const Expanded(flex: 3, child: Text('TOTAL', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text(_currencyFormat.format(d.outwardIgst + d.outwardCgst + d.outwardSgst), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text(_currencyFormat.format(d.inputIgst + d.inputCgst + d.inputSgst), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                Expanded(
                  flex: 2,
                  child: Text(
                    _currencyFormat.format(netTotal.abs()),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: netTotal > 0 ? AppColors.error : AppColors.success),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiabilityRow(String label, double output, double input, double net) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5)))),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary))),
          Expanded(flex: 2, child: Text(_currencyFormat.format(output), style: const TextStyle(fontSize: 13, color: AppColors.error), textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text(_currencyFormat.format(input), style: const TextStyle(fontSize: 13, color: AppColors.success), textAlign: TextAlign.right)),
          Expanded(
            flex: 2,
            child: Text(
              _currencyFormat.format(net.abs()),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: net > 0 ? AppColors.error : AppColors.success),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
