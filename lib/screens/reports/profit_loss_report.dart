import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/themes.dart';
import '../../services/report_service.dart';

class ProfitLossReport extends StatefulWidget {
  const ProfitLossReport({super.key});

  @override
  State<ProfitLossReport> createState() => _ProfitLossReportState();
}

class _ProfitLossReportState extends State<ProfitLossReport> {
  final _reportService = ReportService();
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 2);
  final _dateFormat = DateFormat('dd MMM yyyy');

  ProfitLossData? _data;
  bool _isLoading = true;

  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Default to current financial year
    if (now.month >= 4) {
      _startDate = DateTime(now.year, 4, 1);
    } else {
      _startDate = DateTime(now.year - 1, 4, 1);
    }
    _endDate = now;
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    final data = await _reportService.getProfitAndLoss(
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
                      Text('Profit & Loss Statement', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      SizedBox(height: 4),
                      Text('Income minus expenses equals profit or loss', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
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
                  : _data == null
                      ? _buildEmptyState()
                      : _buildStatement(),
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
          Icon(Icons.trending_up, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('No data available', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Income and expense data will appear once transactions are recorded', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildStatement() {
    final data = _data!;
    final isProfit = data.netProfit >= 0;

    return SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                children: [
                  const Text('PROFIT & LOSS STATEMENT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text('${_dateFormat.format(_startDate)} to ${_dateFormat.format(_endDate)}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),

            // INCOME Section
            _buildSectionHeader('INCOME', Icons.trending_up, AppColors.success),
            if (data.incomeItems.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Text('No income recorded', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
              )
            else
              ...data.incomeItems.map((item) => _buildLineItem(
                item.accountName,
                item.amount,
                isContra: item.subType == 'sales_return',
              )),
            _buildSubTotal('Total Income', data.totalIncome, AppColors.success),

            const Divider(height: 1),

            // EXPENSES Section
            _buildSectionHeader('EXPENSES', Icons.trending_down, AppColors.error),
            if (data.expenseItems.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Text('No expenses recorded', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
              )
            else
              ...data.expenseItems.map((item) => _buildLineItem(
                item.accountName,
                item.amount,
                isContra: item.subType == 'purchase_return',
              )),
            _buildSubTotal('Total Expenses', data.totalExpenses, AppColors.error),

            // NET PROFIT / LOSS
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isProfit ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: AppColors.border, width: 2)),
              ),
              child: Row(
                children: [
                  Icon(isProfit ? Icons.arrow_upward : Icons.arrow_downward, size: 20, color: isProfit ? AppColors.success : AppColors.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isProfit ? 'NET PROFIT' : 'NET LOSS',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isProfit ? AppColors.success : AppColors.error),
                    ),
                  ),
                  Text(
                    _currencyFormat.format(data.netProfit.abs()),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isProfit ? AppColors.success : AppColors.error),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildLineItem(String name, double amount, {bool isContra = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          if (isContra) const SizedBox(width: 20),
          Expanded(
            child: Text(
              isContra ? 'Less: $name' : name,
              style: TextStyle(
                fontSize: 13,
                color: isContra ? AppColors.textSecondary : AppColors.textPrimary,
                fontStyle: isContra ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
          Text(
            isContra && amount > 0 ? '(${_currencyFormat.format(amount)})' : _currencyFormat.format(amount.abs()),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isContra ? AppColors.textSecondary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTotal(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
          Text(_currencyFormat.format(amount.abs()), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
