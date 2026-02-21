import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/themes.dart';
import '../../services/report_service.dart';

class DashboardHome extends StatefulWidget {
  const DashboardHome({super.key});

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  final _reportService = ReportService();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);
  final _dateFormat = DateFormat('dd MMM yyyy');

  bool _isLoading = true;

  // Summary metrics
  double _todaySales = 0;
  int _todayInvoiceCount = 0;
  double _monthSales = 0;
  int _monthInvoiceCount = 0;
  double _totalReceivables = 0;
  int _receivableInvoiceCount = 0;
  double _totalPayables = 0;
  int _payableBillCount = 0;
  double _gstLiability = 0;
  double _netProfit = 0;

  // Aging alerts
  int _overdueCount = 0;
  double _overdueAmount = 0;

  // Recent activity
  List<Map<String, dynamic>> _recentActivity = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    await Future.wait([
      _loadSalesMetrics(),
      _loadReceivables(),
      _loadPayables(),
      _loadGstLiability(),
      _loadProfitLoss(),
      _loadAgingAlerts(),
      _loadRecentActivity(),
    ]);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSalesMetrics() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);

    // Today's sales
    final todayItems = await _reportService.getSalesRegister(
      startDate: todayStart,
      endDate: now,
    );
    _todaySales = todayItems.fold(0.0, (sum, item) => sum + item.total);
    _todayInvoiceCount = todayItems.length;

    // This month's sales
    final monthItems = await _reportService.getSalesRegister(
      startDate: monthStart,
      endDate: now,
    );
    _monthSales = monthItems.fold(0.0, (sum, item) => sum + item.total);
    _monthInvoiceCount = monthItems.length;
  }

  Future<void> _loadReceivables() async {
    final items = await _reportService.getOutstandingReceivables();
    _totalReceivables = items.fold(0.0, (sum, item) => sum + item.outstanding);
    _receivableInvoiceCount = items.fold(0, (sum, item) => sum + item.invoiceCount);
  }

  Future<void> _loadPayables() async {
    final items = await _reportService.getOutstandingPayables();
    _totalPayables = items.fold(0.0, (sum, item) => sum + item.outstanding);
    _payableBillCount = items.fold(0, (sum, item) => sum + item.billCount);
  }

  Future<void> _loadGstLiability() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final gstData = await _reportService.getGstSummary(
      startDate: monthStart,
      endDate: now,
    );
    _gstLiability = gstData?.netPayable ?? 0;
  }

  Future<void> _loadProfitLoss() async {
    final now = DateTime.now();
    DateTime fyStart;
    if (now.month >= 4) {
      fyStart = DateTime(now.year, 4, 1);
    } else {
      fyStart = DateTime(now.year - 1, 4, 1);
    }
    final plData = await _reportService.getProfitAndLoss(
      startDate: fyStart,
      endDate: now,
    );
    _netProfit = plData?.netProfit ?? 0;
  }

  Future<void> _loadAgingAlerts() async {
    final agingItems = await _reportService.getReceivablesAging();
    _overdueCount = 0;
    _overdueAmount = 0;
    for (final item in agingItems) {
      final overdue = item.overdue1to30 + item.overdue31to60 + item.overdue60plus;
      if (overdue > 0) {
        _overdueCount += item.invoiceCount;
        _overdueAmount += overdue;
      }
    }
  }

  Future<void> _loadRecentActivity() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final snapshot = await _firestore
          .collection('journalEntries')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(8)
          .get();

      _recentActivity = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'narration': data['narration'] ?? '',
          'referenceType': data['referenceType'] ?? '',
          'referenceNumber': data['referenceNumber'] ?? '',
          'totalDebit': (data['totalDebit'] as num?)?.toDouble() ?? 0,
          'date': (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        };
      }).toList();
    } catch (e) {
      _recentActivity = [];
    }
  }

  String _formatReferenceType(String type) {
    switch (type) {
      case 'sales_invoice': return 'Invoice';
      case 'payment_received': return 'Payment In';
      case 'purchase_bill': return 'Bill';
      case 'payment_made': return 'Payment Out';
      case 'credit_note': return 'Credit Note';
      case 'debit_note': return 'Debit Note';
      default: return type;
    }
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'sales_invoice': return Icons.receipt;
      case 'payment_received': return Icons.arrow_downward;
      case 'purchase_bill': return Icons.shopping_bag;
      case 'payment_made': return Icons.arrow_upward;
      case 'credit_note': return Icons.note_alt;
      case 'debit_note': return Icons.receipt_long;
      default: return Icons.circle;
    }
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'sales_invoice': return AppColors.primary;
      case 'payment_received': return AppColors.success;
      case 'purchase_bill': return AppColors.warning;
      case 'payment_made': return AppColors.error;
      case 'credit_note': return AppColors.info;
      case 'debit_note': return AppColors.warning;
      default: return AppColors.textSecondary;
    }
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    final diff = today.difference(dateOnly).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    return _dateFormat.format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Dashboard', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              SizedBox(height: 4),
                              Text('Your business at a glance', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _loadDashboardData,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Refresh'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Summary metric cards - Row 1 (3 cards)
                    Row(
                      children: [
                        Expanded(child: _buildMetricCard(
                          title: "Today's Sales",
                          amount: _todaySales,
                          subtitle: '$_todayInvoiceCount invoices',
                          icon: Icons.today,
                          color: AppColors.primary,
                        )),
                        const SizedBox(width: 16),
                        Expanded(child: _buildMetricCard(
                          title: 'This Month',
                          amount: _monthSales,
                          subtitle: '$_monthInvoiceCount invoices',
                          icon: Icons.calendar_month,
                          color: AppColors.info,
                        )),
                        const SizedBox(width: 16),
                        Expanded(child: _buildMetricCard(
                          title: 'Receivables',
                          amount: _totalReceivables,
                          subtitle: '$_receivableInvoiceCount unpaid invoices',
                          icon: Icons.account_balance_wallet,
                          color: AppColors.success,
                        )),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Summary metric cards - Row 2 (3 cards)
                    Row(
                      children: [
                        Expanded(child: _buildMetricCard(
                          title: 'Payables',
                          amount: _totalPayables,
                          subtitle: '$_payableBillCount unpaid bills',
                          icon: Icons.payments,
                          color: AppColors.warning,
                        )),
                        const SizedBox(width: 16),
                        Expanded(child: _buildMetricCard(
                          title: 'GST Liability',
                          amount: _gstLiability,
                          subtitle: 'This month',
                          icon: Icons.account_balance,
                          color: AppColors.error,
                        )),
                        const SizedBox(width: 16),
                        Expanded(child: _buildMetricCard(
                          title: 'Net Profit',
                          amount: _netProfit,
                          subtitle: 'This financial year',
                          icon: Icons.trending_up,
                          color: _netProfit >= 0 ? AppColors.success : AppColors.error,
                          showSign: true,
                        )),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Middle row: Aging Alert + Quick Actions
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _buildAgingAlert()),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: _buildQuickActions()),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Recent Activity
                    _buildRecentActivity(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required double amount,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool showSign = false,
  }) {
    String formattedAmount;
    if (showSign && amount < 0) {
      formattedAmount = '-${_currencyFormat.format(amount.abs())}';
    } else {
      formattedAmount = _currencyFormat.format(amount.abs());
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            formattedAmount,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildAgingAlert() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _overdueAmount > 0
                      ? AppColors.warning.withOpacity(0.1)
                      : AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _overdueAmount > 0 ? Icons.warning_amber : Icons.check_circle,
                  color: _overdueAmount > 0 ? AppColors.warning : AppColors.success,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Aging Alert', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ),
              if (_overdueAmount > 0)
                OutlinedButton(
                  onPressed: () => context.go('/dashboard/reports/receivables-aging'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('View Report'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_overdueAmount > 0) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _currencyFormat.format(_overdueAmount),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.warning),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$_overdueCount invoices',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warning),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Overdue receivables need follow-up',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ] else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                  SizedBox(width: 12),
                  Text('No overdue invoices. All good!', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.success)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.flash_on, size: 20, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          _buildActionButton(
            icon: Icons.receipt,
            label: 'New Invoice',
            color: AppColors.primary,
            onTap: () => context.go('/dashboard/invoices/create'),
          ),
          const SizedBox(height: 8),
          _buildActionButton(
            icon: Icons.description,
            label: 'New Quotation',
            color: AppColors.info,
            onTap: () => context.go('/dashboard/quotations/create'),
          ),
          const SizedBox(height: 8),
          _buildActionButton(
            icon: Icons.person_add,
            label: 'Add Customer',
            color: AppColors.success,
            onTap: () => context.go('/dashboard/customers/add'),
          ),
          const SizedBox(height: 8),
          _buildActionButton(
            icon: Icons.assessment,
            label: 'View Reports',
            color: AppColors.warning,
            onTap: () => context.go('/dashboard/reports'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.05),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
              ),
              Icon(Icons.arrow_forward_ios, size: 12, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history, size: 20, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Text('Recent Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          if (_recentActivity.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Icon(Icons.inbox, size: 40, color: AppColors.textSecondary),
                  SizedBox(height: 8),
                  Text('No recent activity', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  SizedBox(height: 4),
                  Text('Transactions will appear here as you create invoices and record payments', style: TextStyle(fontSize: 12, color: AppColors.textSecondary), textAlign: TextAlign.center),
                ],
              ),
            )
          else
            ...List.generate(_recentActivity.length, (index) {
              final activity = _recentActivity[index];
              final type = activity['referenceType'] as String;
              final isLast = index == _recentActivity.length - 1;

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: isLast ? null : Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5))),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _getActivityColor(type).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(_getActivityIcon(type), color: _getActivityColor(type), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity['narration'] as String,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: _getActivityColor(type).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _formatReferenceType(type),
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _getActivityColor(type)),
                                ),
                              ),
                              if ((activity['referenceNumber'] as String).isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Text(
                                  activity['referenceNumber'] as String,
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _currencyFormat.format(activity['totalDebit'] as double),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatRelativeDate(activity['date'] as DateTime),
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
