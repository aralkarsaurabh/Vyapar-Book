import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/themes.dart';
import '../../services/report_service.dart';

class CustomerLedgerReport extends StatefulWidget {
  final String? initialCustomerId;

  const CustomerLedgerReport({super.key, this.initialCustomerId});

  @override
  State<CustomerLedgerReport> createState() => _CustomerLedgerReportState();
}

class _CustomerLedgerReportState extends State<CustomerLedgerReport> {
  final _reportService = ReportService();
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 2);
  final _dateFormat = DateFormat('dd MMM yyyy');

  List<Map<String, String>> _customers = [];
  String? _selectedCustomerId;
  PartyLedgerData? _data;
  bool _isLoading = false;
  bool _isLoadingCustomers = true;

  late DateTime _startDate;
  late DateTime _endDate;

  int _currentPage = 0;
  final int _itemsPerPage = 15;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    if (now.month >= 4) {
      _startDate = DateTime(now.year, 4, 1);
    } else {
      _startDate = DateTime(now.year - 1, 4, 1);
    }
    _endDate = now;
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    final customers = await _reportService.getCustomerList();
    if (mounted) {
      setState(() {
        _customers = customers;
        _isLoadingCustomers = false;
        if (widget.initialCustomerId != null) {
          _selectedCustomerId = widget.initialCustomerId;
          _loadReport();
        }
      });
    }
  }

  Future<void> _loadReport() async {
    if (_selectedCustomerId == null) return;
    setState(() => _isLoading = true);
    final data = await _reportService.getCustomerLedger(
      customerId: _selectedCustomerId!,
      startDate: _startDate,
      endDate: _endDate,
    );
    if (mounted) {
      setState(() {
        _data = data;
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
            // Header
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
                      Text('Customer Ledger', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      SizedBox(height: 4),
                      Text('All transactions for a specific customer with running balance', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildFilters(),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoadingCustomers
                  ? const Center(child: CircularProgressIndicator())
                  : _selectedCustomerId == null
                      ? _buildSelectPrompt()
                      : _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _data == null || _data!.items.isEmpty
                              ? _buildEmptyState()
                              : _buildLedger(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(
        children: [
          Row(
            children: [
              // Customer selector
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  value: _selectedCustomerId,
                  decoration: InputDecoration(
                    labelText: 'Select Customer',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: _customers.map((c) {
                    return DropdownMenuItem<String>(value: c['id'], child: Text(c['name'] ?? '', overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedCustomerId = value);
                    _loadReport();
                  },
                ),
              ),
              const SizedBox(width: 16),
              _buildDateField('From', _startDate, _pickStartDate),
              const SizedBox(width: 16),
              _buildDateField('To', _endDate, _pickEndDate),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Quick: ', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              _buildPresetButton('This Month', 'thisMonth'),
              const SizedBox(width: 8),
              _buildPresetButton('Last Month', 'lastMonth'),
              const SizedBox(width: 8),
              _buildPresetButton('This Quarter', 'thisQuarter'),
              const SizedBox(width: 8),
              _buildPresetButton('This Year', 'thisYear'),
            ],
          ),
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

  Widget _buildSelectPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('Select a Customer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Choose a customer from the dropdown to view their ledger', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('No transactions found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('No transactions found for this customer in the selected period', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildLedger() {
    final data = _data!;
    final totalPages = (data.items.length / _itemsPerPage).ceil();
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, data.items.length);
    final pageItems = data.items.sublist(startIndex, endIndex);

    return Column(
      children: [
        // Summary cards
        _buildSummaryCards(data),
        const SizedBox(height: 16),
        // Table
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: Column(
              children: [
                // Table header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      _headerCell('Date', 2),
                      _headerCell('Particular', 3),
                      _headerCell('Reference', 3),
                      _headerCell('Debit', 2, align: TextAlign.right),
                      _headerCell('Credit', 2, align: TextAlign.right),
                      _headerCell('Balance', 2, align: TextAlign.right),
                    ],
                  ),
                ),
                // Opening balance row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.background, border: Border(bottom: BorderSide(color: AppColors.border))),
                  child: Row(
                    children: [
                      _dataCell('', 2),
                      _dataCell('Opening Balance', 3, bold: true),
                      _dataCell('', 3),
                      _dataCell('', 2),
                      _dataCell('', 2),
                      _dataCell(_currencyFormat.format(data.openingBalance), 2, align: TextAlign.right, bold: true),
                    ],
                  ),
                ),
                // Data rows
                Expanded(
                  child: ListView.builder(
                    itemCount: pageItems.length,
                    itemBuilder: (context, index) {
                      final item = pageItems[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5)))),
                        child: Row(
                          children: [
                            _dataCell(_dateFormat.format(item.date), 2),
                            _dataCell(item.particular, 3, color: _getTypeColor(item.type)),
                            _dataCell(item.reference, 3),
                            _dataCell(item.debit > 0 ? _currencyFormat.format(item.debit) : '-', 2, align: TextAlign.right),
                            _dataCell(item.credit > 0 ? _currencyFormat.format(item.credit) : '-', 2, align: TextAlign.right),
                            _dataCell(_currencyFormat.format(item.balance), 2, align: TextAlign.right, bold: true),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // Closing balance row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                    border: Border(top: BorderSide(color: AppColors.border, width: 2)),
                  ),
                  child: Row(
                    children: [
                      _dataCell('', 2),
                      _dataCell('Closing Balance', 3, bold: true),
                      _dataCell('', 3),
                      _dataCell(_currencyFormat.format(data.totalDebit), 2, align: TextAlign.right, bold: true),
                      _dataCell(_currencyFormat.format(data.totalCredit), 2, align: TextAlign.right, bold: true),
                      _dataCell(_currencyFormat.format(data.closingBalance), 2, align: TextAlign.right, bold: true, color: data.closingBalance > 0 ? AppColors.error : AppColors.success),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Pagination
        if (totalPages > 1) ...[
          const SizedBox(height: 12),
          _buildPagination(totalPages),
        ],
      ],
    );
  }

  Widget _buildSummaryCards(PartyLedgerData data) {
    return Row(
      children: [
        _buildSummaryCard('Total Invoiced', data.totalDebit, AppColors.info, Icons.receipt),
        const SizedBox(width: 12),
        _buildSummaryCard('Total Received', data.totalCredit, AppColors.success, Icons.payments),
        const SizedBox(width: 12),
        _buildSummaryCard('Outstanding', data.closingBalance, data.closingBalance > 0 ? AppColors.error : AppColors.success, Icons.account_balance_wallet),
      ],
    );
  }

  Widget _buildSummaryCard(String label, double amount, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(_currencyFormat.format(amount.abs()), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'invoice':
        return AppColors.info;
      case 'payment':
        return AppColors.success;
      case 'credit_note':
        return AppColors.warning;
      default:
        return AppColors.textPrimary;
    }
  }

  Widget _headerCell(String text, int flex, {TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(text, textAlign: align, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
    );
  }

  Widget _dataCell(String text, int flex, {TextAlign align = TextAlign.left, bool bold = false, Color? color}) {
    return Expanded(
      flex: flex,
      child: Text(text, textAlign: align, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w600 : FontWeight.normal, color: color ?? AppColors.textPrimary), overflow: TextOverflow.ellipsis),
    );
  }

  Widget _buildPagination(int totalPages) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
          icon: const Icon(Icons.chevron_left),
          iconSize: 20,
        ),
        Text('Page ${_currentPage + 1} of $totalPages', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        IconButton(
          onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
          icon: const Icon(Icons.chevron_right),
          iconSize: 20,
        ),
      ],
    );
  }
}
