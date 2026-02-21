import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/themes.dart';

class _ReportCard {
  final IconData icon;
  final String title;
  final String description;
  final String route;
  final Color color;

  _ReportCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.route,
    required this.color,
  });
}

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  List<_ReportCard> get _reports => [
        _ReportCard(
          icon: Icons.receipt_long,
          title: 'Sales Register',
          description: 'All invoices with date, customer, amount, and GST details',
          route: '/dashboard/reports/sales-register',
          color: AppColors.primary,
        ),
        _ReportCard(
          icon: Icons.shopping_bag,
          title: 'Purchase Register',
          description: 'All recorded bills with vendor, amount, and GST details',
          route: '/dashboard/reports/purchase-register',
          color: AppColors.info,
        ),
        _ReportCard(
          icon: Icons.account_balance_wallet,
          title: 'Outstanding Receivables',
          description: 'Unpaid invoices grouped by customer - money owed to you',
          route: '/dashboard/reports/outstanding-receivables',
          color: AppColors.success,
        ),
        _ReportCard(
          icon: Icons.payments,
          title: 'Outstanding Payables',
          description: 'Unpaid bills grouped by vendor - money you owe',
          route: '/dashboard/reports/outstanding-payables',
          color: AppColors.warning,
        ),
        _ReportCard(
          icon: Icons.people,
          title: 'Customer-wise Sales',
          description: 'Sales breakdown per customer with invoice count and totals',
          route: '/dashboard/reports/customer-wise-sales',
          color: AppColors.primary,
        ),
        _ReportCard(
          icon: Icons.store,
          title: 'Vendor-wise Purchases',
          description: 'Purchase breakdown per vendor with bill count and totals',
          route: '/dashboard/reports/vendor-wise-purchases',
          color: AppColors.info,
        ),
        _ReportCard(
          icon: Icons.schedule,
          title: 'Receivables Aging',
          description: 'Overdue analysis of unpaid invoices by aging buckets',
          route: '/dashboard/reports/receivables-aging',
          color: AppColors.error,
        ),
        _ReportCard(
          icon: Icons.timer,
          title: 'Payables Aging',
          description: 'Overdue analysis of unpaid bills by aging buckets',
          route: '/dashboard/reports/payables-aging',
          color: AppColors.warning,
        ),
        _ReportCard(
          icon: Icons.account_balance,
          title: 'GST Summary',
          description: 'Output GST vs Input GST with net tax liability',
          route: '/dashboard/reports/gst-summary',
          color: AppColors.primary,
        ),
        _ReportCard(
          icon: Icons.description,
          title: 'GSTR-1 Sales',
          description: 'B2B and B2C sales breakdown for GSTR-1 filing',
          route: '/dashboard/reports/gstr1',
          color: AppColors.info,
        ),
        _ReportCard(
          icon: Icons.summarize,
          title: 'GSTR-3B Summary',
          description: 'Summary return format for GSTR-3B filing',
          route: '/dashboard/reports/gstr3b',
          color: AppColors.success,
        ),
        _ReportCard(
          icon: Icons.person_search,
          title: 'Customer Ledger',
          description: 'All transactions for a specific customer with running balance',
          route: '/dashboard/reports/customer-ledger',
          color: AppColors.primary,
        ),
        _ReportCard(
          icon: Icons.store_mall_directory,
          title: 'Vendor Ledger',
          description: 'All transactions for a specific vendor with running balance',
          route: '/dashboard/reports/vendor-ledger',
          color: AppColors.info,
        ),
        _ReportCard(
          icon: Icons.menu_book,
          title: 'Ledger Report',
          description: 'All transactions for a specific account with running balance',
          route: '/dashboard/reports/ledger',
          color: AppColors.primary,
        ),
        _ReportCard(
          icon: Icons.account_balance_wallet,
          title: 'Cash Book',
          description: 'All cash receipts and payments with running balance',
          route: '/dashboard/reports/cash-book',
          color: AppColors.success,
        ),
        _ReportCard(
          icon: Icons.account_balance,
          title: 'Bank Book',
          description: 'All bank deposits and withdrawals per bank account',
          route: '/dashboard/reports/bank-book',
          color: AppColors.info,
        ),
        _ReportCard(
          icon: Icons.event_note,
          title: 'Day Book',
          description: 'All journal entries and transactions on a specific date',
          route: '/dashboard/reports/day-book',
          color: AppColors.warning,
        ),
        _ReportCard(
          icon: Icons.balance,
          title: 'Trial Balance',
          description: 'All accounts with debit and credit totals for verification',
          route: '/dashboard/reports/trial-balance',
          color: AppColors.primary,
        ),
        _ReportCard(
          icon: Icons.trending_up,
          title: 'Profit & Loss',
          description: 'Income minus expenses equals profit or loss for a period',
          route: '/dashboard/reports/profit-loss',
          color: AppColors.success,
        ),
        _ReportCard(
          icon: Icons.pie_chart,
          title: 'Balance Sheet',
          description: 'Assets, liabilities, and equity snapshot of your business',
          route: '/dashboard/reports/balance-sheet',
          color: AppColors.info,
        ),
      ];

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
            const Text(
              'Reports',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'View business reports and insights',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // Report cards grid
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.6,
                ),
                itemCount: _reports.length,
                itemBuilder: (context, index) {
                  final report = _reports[index];
                  return _buildReportCard(context, report);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(BuildContext context, _ReportCard report) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => context.go(report.route),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: report.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  report.icon,
                  color: report.color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                report.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  report.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'View Report',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: report.color,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward,
                    size: 14,
                    color: report.color,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
