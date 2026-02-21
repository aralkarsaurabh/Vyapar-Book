import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/themes.dart';
import '../../services/report_service.dart';

class TrialBalanceReport extends StatefulWidget {
  const TrialBalanceReport({super.key});

  @override
  State<TrialBalanceReport> createState() => _TrialBalanceReportState();
}

class _TrialBalanceReportState extends State<TrialBalanceReport> {
  final _reportService = ReportService();
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 2);
  final _dateFormat = DateFormat('dd MMM yyyy');

  List<TrialBalanceItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    final items = await _reportService.getTrialBalance();
    if (mounted) {
      setState(() {
        _items = items;
        _isLoading = false;
      });
    }
  }

  String _formatType(String type) {
    switch (type) {
      case 'asset': return 'Asset';
      case 'liability': return 'Liability';
      case 'income': return 'Income';
      case 'expense': return 'Expense';
      case 'equity': return 'Equity';
      default: return type;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'asset': return AppColors.info;
      case 'liability': return AppColors.warning;
      case 'income': return AppColors.success;
      case 'expense': return AppColors.error;
      case 'equity': return AppColors.primary;
      default: return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    double totalDebit = 0, totalCredit = 0;
    for (final item in _items) {
      totalDebit += item.debitBalance;
      totalCredit += item.creditBalance;
    }
    final isBalanced = (totalDebit - totalCredit).abs() < 0.01;

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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Trial Balance', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text('As on ${_dateFormat.format(DateTime.now())}', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (!_isLoading && _items.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isBalanced ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isBalanced ? Icons.check_circle : Icons.warning, size: 16, color: isBalanced ? AppColors.success : AppColors.error),
                        const SizedBox(width: 8),
                        Text(isBalanced ? 'BALANCED' : 'NOT BALANCED', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isBalanced ? AppColors.success : AppColors.error)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? _buildEmptyState()
                      : _buildTable(totalDebit, totalCredit),
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
          Icon(Icons.balance, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('No account balances found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Accounts will appear here once transactions are recorded', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildTable(double totalDebit, double totalCredit) {
    // Group items by type
    final typeOrder = ['asset', 'liability', 'income', 'expense', 'equity'];
    final grouped = <String, List<TrialBalanceItem>>{};
    for (final item in _items) {
      grouped.putIfAbsent(item.accountType, () => []).add(item);
    }

    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: const Row(
              children: [
                Expanded(flex: 1, child: Text('Code', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                Expanded(flex: 4, child: Text('Account Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                Expanded(flex: 2, child: Text('Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                Expanded(flex: 2, child: Text('Debit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('Credit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.right)),
              ],
            ),
          ),
          // Rows grouped by type
          Expanded(
            child: ListView(
              children: [
                for (final type in typeOrder)
                  if (grouped.containsKey(type))
                    ...grouped[type]!.map((item) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5)))),
                      child: Row(
                        children: [
                          Expanded(flex: 1, child: Text(item.accountCode, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'monospace'))),
                          Expanded(flex: 4, child: Text(item.accountName, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary))),
                          Expanded(flex: 2, child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: _typeColor(item.accountType).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                            child: Text(_formatType(item.accountType), style: TextStyle(fontSize: 11, color: _typeColor(item.accountType), fontWeight: FontWeight.w500), textAlign: TextAlign.center),
                          )),
                          Expanded(flex: 2, child: Text(item.debitBalance > 0 ? _currencyFormat.format(item.debitBalance) : '', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary), textAlign: TextAlign.right)),
                          Expanded(flex: 2, child: Text(item.creditBalance > 0 ? _currencyFormat.format(item.creditBalance) : '', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary), textAlign: TextAlign.right)),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          // Totals
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              border: Border(top: BorderSide(color: AppColors.border, width: 2)),
            ),
            child: Row(
              children: [
                const Expanded(flex: 1, child: SizedBox()),
                const Expanded(flex: 4, child: Text('TOTAL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                const Expanded(flex: 2, child: SizedBox()),
                Expanded(flex: 2, child: Text(_currencyFormat.format(totalDebit), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text(_currencyFormat.format(totalCredit), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary), textAlign: TextAlign.right)),
              ],
            ),
          ),
          // Info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(
              children: [
                Text('${_items.length} accounts with non-zero balances', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const Spacer(),
                Text('Difference: ${_currencyFormat.format((totalDebit - totalCredit).abs())}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: (totalDebit - totalCredit).abs() < 0.01 ? AppColors.success : AppColors.error)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
