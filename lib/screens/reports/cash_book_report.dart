import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/themes.dart';
import '../../services/report_service.dart';

class CashBookReport extends StatefulWidget {
  const CashBookReport({super.key});

  @override
  State<CashBookReport> createState() => _CashBookReportState();
}

class _CashBookReportState extends State<CashBookReport> {
  final _reportService = ReportService();
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 2);
  final _dateFormat = DateFormat('dd MMM yyyy');

  LedgerData? _ledgerData;
  bool _isLoading = true;
  int _currentPage = 0;
  final int _itemsPerPage = 15;

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
    final cashAccountId = await _reportService.getCashAccountId();
    if (cashAccountId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final data = await _reportService.getLedger(
      accountId: cashAccountId,
      startDate: _startDate,
      endDate: _endDate,
    );
    if (mounted) {
      setState(() {
        _ledgerData = data;
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
    if (date != null) { setState(() => _startDate = date); _loadReport(); }
  }

  Future<void> _pickEndDate() async {
    final date = await showDatePicker(context: context, initialDate: _endDate, firstDate: _startDate, lastDate: DateTime.now());
    if (date != null) { setState(() => _endDate = date); _loadReport(); }
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
                  style: IconButton.styleFrom(backgroundColor: AppColors.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.border))),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cash Book', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      SizedBox(height: 4),
                      Text('All cash receipts and payments', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildDateFilters(),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _ledgerData == null || _ledgerData!.items.isEmpty
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('No cash transactions found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Try adjusting the date range', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildTable() {
    final items = _ledgerData!.items;
    final totalPages = (items.length / _itemsPerPage).ceil();
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = min(startIndex + _itemsPerPage, items.length);
    final pageItems = items.sublist(startIndex, endIndex);

    double totalDebit = 0, totalCredit = 0;
    for (final item in items) { totalDebit += item.debit; totalCredit += item.credit; }

    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        children: [
          // Opening balance
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(color: AppColors.background, border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Row(
              children: [
                const Expanded(flex: 2, child: SizedBox()),
                const Expanded(flex: 4, child: Text('Opening Balance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                const Expanded(flex: 2, child: SizedBox()),
                const Expanded(flex: 2, child: SizedBox()),
                Expanded(flex: 2, child: Text(_currencyFormat.format(_ledgerData!.openingBalance), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary), textAlign: TextAlign.right)),
              ],
            ),
          ),
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text('Date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                Expanded(flex: 4, child: Text('Particular', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                Expanded(flex: 2, child: Text('Received', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('Paid', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('Balance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.right)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: pageItems.length,
              itemBuilder: (context, index) {
                final item = pageItems[index];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5)))),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text(_dateFormat.format(item.date), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
                      Expanded(flex: 4, child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.particular, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
                          if (item.reference.isNotEmpty) Text(item.reference, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      )),
                      Expanded(flex: 2, child: Text(item.debit > 0 ? _currencyFormat.format(item.debit) : '', style: TextStyle(fontSize: 13, color: item.debit > 0 ? AppColors.success : AppColors.textPrimary), textAlign: TextAlign.right)),
                      Expanded(flex: 2, child: Text(item.credit > 0 ? _currencyFormat.format(item.credit) : '', style: TextStyle(fontSize: 13, color: item.credit > 0 ? AppColors.error : AppColors.textPrimary), textAlign: TextAlign.right)),
                      Expanded(flex: 2, child: Text(_currencyFormat.format(item.balance), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary), textAlign: TextAlign.right)),
                    ],
                  ),
                );
              },
            ),
          ),
          // Totals
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.05), border: Border(top: BorderSide(color: AppColors.border, width: 2))),
            child: Row(
              children: [
                const Expanded(flex: 2, child: SizedBox()),
                const Expanded(flex: 4, child: Text('Closing Balance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                Expanded(flex: 2, child: Text(_currencyFormat.format(totalDebit), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text(_currencyFormat.format(totalCredit), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text(_currencyFormat.format(_ledgerData!.closingBalance), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary), textAlign: TextAlign.right)),
              ],
            ),
          ),
          // Pagination
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Showing ${startIndex + 1}-$endIndex of ${items.length} entries', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                Row(
                  children: [
                    IconButton(onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null, icon: const Icon(Icons.chevron_left, size: 20), style: IconButton.styleFrom(backgroundColor: AppColors.background, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), margin: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)), child: Text('Page ${_currentPage + 1} of $totalPages', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                    IconButton(onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null, icon: const Icon(Icons.chevron_right, size: 20), style: IconButton.styleFrom(backgroundColor: AppColors.background, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
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
