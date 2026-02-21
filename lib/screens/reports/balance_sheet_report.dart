import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/themes.dart';
import '../../services/report_service.dart';

class BalanceSheetReport extends StatefulWidget {
  const BalanceSheetReport({super.key});

  @override
  State<BalanceSheetReport> createState() => _BalanceSheetReportState();
}

class _BalanceSheetReportState extends State<BalanceSheetReport> {
  final _reportService = ReportService();
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 2);
  final _dateFormat = DateFormat('dd MMM yyyy');

  BalanceSheetData? _data;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    final data = await _reportService.getBalanceSheet();
    if (mounted) {
      setState(() {
        _data = data;
        _isLoading = false;
      });
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
                  style: IconButton.styleFrom(backgroundColor: AppColors.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.border))),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Balance Sheet', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text('As on ${_dateFormat.format(DateTime.now())}', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (!_isLoading && _data != null)
                  _buildBalanceIndicator(),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _data == null
                      ? _buildEmptyState()
                      : _buildBalanceSheet(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceIndicator() {
    final data = _data!;
    final totalLiabilitiesAndEquity = data.totalLiabilities + data.totalEquity;
    final isBalanced = (data.totalAssets - totalLiabilitiesAndEquity).abs() < 0.01;

    return Container(
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('No data available', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Balance sheet data will appear once transactions are recorded', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildBalanceSheet() {
    final data = _data!;
    final totalLiabilitiesAndEquity = data.totalLiabilities + data.totalEquity;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Title card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                const Text('BALANCE SHEET', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text('As on ${_dateFormat.format(DateTime.now())}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Two-column layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: ASSETS
              Expanded(
                child: _buildAssetsSide(data),
              ),
              const SizedBox(width: 16),
              // Right: LIABILITIES & EQUITY
              Expanded(
                child: _buildLiabilitiesEquitySide(data, totalLiabilitiesAndEquity),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Summary comparison
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text('Total Assets', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(_currencyFormat.format(data.totalAssets), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.info)),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: AppColors.border,
                ),
                Expanded(
                  child: Column(
                    children: [
                      const Text('Total Liabilities + Equity', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(_currencyFormat.format(totalLiabilitiesAndEquity), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetsSide(BalanceSheetData data) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: const Row(
              children: [
                Icon(Icons.account_balance_wallet, size: 18, color: AppColors.info),
                SizedBox(width: 8),
                Text('ASSETS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.info, letterSpacing: 0.5)),
              ],
            ),
          ),
          if (data.assetItems.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No assets', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
            )
          else
            ...data.assetItems.map((item) => _buildItem(item.accountName, item.amount)),
          // Total
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              border: Border(top: BorderSide(color: AppColors.border, width: 2)),
            ),
            child: Row(
              children: [
                const Expanded(child: Text('TOTAL ASSETS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                Text(_currencyFormat.format(data.totalAssets), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.info)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiabilitiesEquitySide(BalanceSheetData data, double total) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Liabilities header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: const Row(
              children: [
                Icon(Icons.credit_card, size: 18, color: AppColors.warning),
                SizedBox(width: 8),
                Text('LIABILITIES', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.warning, letterSpacing: 0.5)),
              ],
            ),
          ),
          if (data.liabilityItems.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No liabilities', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
            )
          else
            ...data.liabilityItems.map((item) => _buildItem(item.accountName, item.amount)),
          // Liabilities subtotal
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                const Expanded(child: Text('Total Liabilities', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                Text(_currencyFormat.format(data.totalLiabilities), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warning)),
              ],
            ),
          ),

          // Equity header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              border: Border(bottom: BorderSide(color: AppColors.border), top: BorderSide(color: AppColors.border)),
            ),
            child: const Row(
              children: [
                Icon(Icons.savings, size: 18, color: AppColors.primary),
                SizedBox(width: 8),
                Text('EQUITY', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 0.5)),
              ],
            ),
          ),
          if (data.equityItems.isEmpty && data.retainedEarnings == 0)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No equity', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
            )
          else ...[
            ...data.equityItems.map((item) => _buildItem(item.accountName, item.amount)),
            if (data.retainedEarnings != 0)
              _buildItem('Retained Earnings (P&L)', data.retainedEarnings),
          ],
          // Equity subtotal
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                const Expanded(child: Text('Total Equity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                Text(_currencyFormat.format(data.totalEquity), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ],
            ),
          ),

          // Grand total
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              border: Border(top: BorderSide(color: AppColors.border, width: 2)),
            ),
            child: Row(
              children: [
                const Expanded(child: Text('TOTAL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                Text(_currencyFormat.format(total), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(String name, double amount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          Expanded(child: Text(name, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary))),
          Text(_currencyFormat.format(amount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
