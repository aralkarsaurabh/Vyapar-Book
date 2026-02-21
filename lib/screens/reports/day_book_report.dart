import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/themes.dart';
import '../../services/report_service.dart';

class DayBookReport extends StatefulWidget {
  const DayBookReport({super.key});

  @override
  State<DayBookReport> createState() => _DayBookReportState();
}

class _DayBookReportState extends State<DayBookReport> {
  final _reportService = ReportService();
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 2);
  final _dateFormat = DateFormat('dd MMM yyyy');

  List<DayBookEntry> _entries = [];
  bool _isLoading = false;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    final entries = await _reportService.getDayBook(date: _selectedDate);
    if (mounted) {
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
      _loadReport();
    }
  }

  void _goToPreviousDay() {
    setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
    _loadReport();
  }

  void _goToNextDay() {
    final tomorrow = _selectedDate.add(const Duration(days: 1));
    if (!tomorrow.isAfter(DateTime.now())) {
      setState(() => _selectedDate = tomorrow);
      _loadReport();
    }
  }

  void _goToToday() {
    setState(() => _selectedDate = DateTime.now());
    _loadReport();
  }

  String _formatReferenceType(String type) {
    switch (type) {
      case 'sales_invoice': return 'Sales Invoice';
      case 'payment_received': return 'Payment Received';
      case 'purchase_bill': return 'Purchase Bill';
      case 'payment_made': return 'Payment Made';
      case 'credit_note': return 'Credit Note';
      case 'debit_note': return 'Debit Note';
      case 'opening_balance': return 'Opening Balance';
      case 'adjustment': return 'Adjustment';
      default: return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Grand totals
    double grandDebit = 0, grandCredit = 0;
    for (final entry in _entries) {
      grandDebit += entry.totalDebit;
      grandCredit += entry.totalCredit;
    }

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
                  style: IconButton.styleFrom(backgroundColor: AppColors.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.border))),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Day Book', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      SizedBox(height: 4),
                      Text('All transactions on a specific date', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Date selector
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _goToPreviousDay,
                    icon: const Icon(Icons.chevron_left),
                    style: IconButton.styleFrom(backgroundColor: AppColors.background, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Text(_dateFormat.format(_selectedDate), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: !_selectedDate.add(const Duration(days: 1)).isAfter(DateTime.now()) ? _goToNextDay : null,
                    icon: const Icon(Icons.chevron_right),
                    style: IconButton.styleFrom(backgroundColor: AppColors.background, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton(
                    onPressed: _goToToday,
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                    child: const Text('Today'),
                  ),
                  const Spacer(),
                  Text('${_entries.length} entries', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Entries
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _entries.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          itemCount: _entries.length + 1, // +1 for grand totals
                          itemBuilder: (context, index) {
                            if (index == _entries.length) {
                              return _buildGrandTotals(grandDebit, grandCredit);
                            }
                            return _buildEntryCard(_entries[index]);
                          },
                        ),
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
          Icon(Icons.event_note, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('No transactions on this date', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Try selecting a different date', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildEntryCard(DayBookEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Entry header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(entry.entryNumber, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(entry.narration, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(6)),
                  child: Text(_formatReferenceType(entry.referenceType), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ),
                if (entry.referenceNumber.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(entry.referenceNumber, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          // Lines header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5)))),
            child: const Row(
              children: [
                Expanded(flex: 5, child: Text('Account', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                Expanded(flex: 2, child: Text('Debit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('Credit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.right)),
              ],
            ),
          ),
          // Lines
          ...entry.lines.map((line) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(flex: 5, child: Text(line.accountName, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary))),
                Expanded(flex: 2, child: Text(line.debit > 0 ? _currencyFormat.format(line.debit) : '', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text(line.credit > 0 ? _currencyFormat.format(line.credit) : '', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary), textAlign: TextAlign.right)),
              ],
            ),
          )),
          // Entry total
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                const Expanded(flex: 5, child: Text('Total', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                Expanded(flex: 2, child: Text(_currencyFormat.format(entry.totalDebit), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text(_currencyFormat.format(entry.totalCredit), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary), textAlign: TextAlign.right)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrandTotals(double grandDebit, double grandCredit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Expanded(flex: 5, child: Text('GRAND TOTAL', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary))),
          Expanded(flex: 2, child: Text(_currencyFormat.format(grandDebit), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary), textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text(_currencyFormat.format(grandCredit), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
