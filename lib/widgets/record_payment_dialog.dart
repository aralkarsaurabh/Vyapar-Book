import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../config/themes.dart';
import '../models/account.dart';
import '../models/payment.dart';
import '../services/invoice_service.dart';
import '../services/payment_service.dart';
import '../services/accounting_service.dart';

class RecordPaymentDialog extends StatefulWidget {
  final Invoice invoice;

  const RecordPaymentDialog({
    super.key,
    required this.invoice,
  });

  /// Show the dialog and return true if payment was recorded
  static Future<bool?> show(BuildContext context, Invoice invoice) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => RecordPaymentDialog(invoice: invoice),
    );
  }

  @override
  State<RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends State<RecordPaymentDialog> {
  final _paymentService = PaymentService();
  final _accountingService = AccountingService();
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  bool _isLoading = true;
  bool _isSaving = false;

  // Payment details
  DateTime _paymentDate = DateTime.now();
  final _noteController = TextEditingController();

  // Payment modes
  Account? _cashAccount;
  List<Account> _bankAccounts = [];
  double _cashAmount = 0;
  final Map<String, double> _bankAmounts = {}; // accountId -> amount
  final Map<String, TextEditingController> _amountControllers = {};

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  @override
  void dispose() {
    _noteController.dispose();
    for (final controller in _amountControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);

    try {
      // Get cash account
      _cashAccount = await _accountingService.getCashAccount();

      // Get bank accounts
      _bankAccounts = await _accountingService.getBankAccounts();

      // Initialize controllers
      if (_cashAccount != null) {
        _amountControllers['cash'] = TextEditingController(text: '0');
      }
      for (final bank in _bankAccounts) {
        if (bank.id != null) {
          _amountControllers[bank.id!] = TextEditingController(text: '0');
          _bankAmounts[bank.id!] = 0;
        }
      }

      // If full amount and only one payment mode, pre-fill
      if (_bankAccounts.isEmpty && _cashAccount != null) {
        _cashAmount = widget.invoice.amountDue;
        _amountControllers['cash']?.text = widget.invoice.amountDue.toStringAsFixed(0);
      }
    } catch (e) {
      debugPrint('Error loading accounts: $e');
    }

    setState(() => _isLoading = false);
  }

  double get _totalPaymentAmount {
    double total = _cashAmount;
    for (final amount in _bankAmounts.values) {
      total += amount;
    }
    return total;
  }

  bool get _isValid {
    return _totalPaymentAmount > 0 && _totalPaymentAmount <= widget.invoice.amountDue;
  }

  void _setFullAmount() {
    // Clear all amounts first
    _cashAmount = 0;
    _amountControllers['cash']?.text = '0';
    for (final id in _bankAmounts.keys) {
      _bankAmounts[id] = 0;
      _amountControllers[id]?.text = '0';
    }

    // Set full amount to first available mode
    if (_cashAccount != null && _amountControllers.containsKey('cash')) {
      _cashAmount = widget.invoice.amountDue;
      _amountControllers['cash']?.text = widget.invoice.amountDue.toStringAsFixed(0);
    } else if (_bankAccounts.isNotEmpty) {
      final firstBank = _bankAccounts.firstWhere((b) => b.id != null, orElse: () => _bankAccounts.first);
      if (firstBank.id != null) {
        _bankAmounts[firstBank.id!] = widget.invoice.amountDue;
        _amountControllers[firstBank.id]?.text = widget.invoice.amountDue.toStringAsFixed(0);
      }
    }

    setState(() {});
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: widget.invoice.invoiceDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _paymentDate = picked);
    }
  }

  Future<void> _savePayment() async {
    if (!_isValid) return;

    setState(() => _isSaving = true);

    try {
      // Build payment modes
      final modes = <PaymentMode>[];

      if (_cashAmount > 0 && _cashAccount != null) {
        modes.add(PaymentMode(
          type: 'cash',
          bankAccountId: _cashAccount!.id,
          bankName: 'Cash',
          amount: _cashAmount,
        ));
      }

      for (final bank in _bankAccounts) {
        final amount = _bankAmounts[bank.id] ?? 0;
        if (amount > 0) {
          modes.add(PaymentMode(
            type: 'bank',
            bankAccountId: bank.id,
            bankName: bank.name,
            amount: amount,
          ));
        }
      }

      final payment = Payment(
        invoiceId: widget.invoice.id!,
        invoiceNumber: widget.invoice.invoiceNumber,
        customerId: widget.invoice.customerId,
        customerName: widget.invoice.customerName,
        paymentDate: _paymentDate,
        modes: modes,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );

      final paymentId = await _paymentService.recordPayment(payment);

      if (paymentId != null && mounted) {
        Navigator.of(context).pop(true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to record payment'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.payments, color: AppColors.success, size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Record Payment',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Payment received from customer',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Invoice Info
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              children: [
                                _buildInfoRow('Invoice', widget.invoice.invoiceNumber ?? '-'),
                                const SizedBox(height: 8),
                                _buildInfoRow('Customer', widget.invoice.customerName ?? '-'),
                                const Divider(height: 24),
                                _buildInfoRow('Invoice Amount', _currencyFormat.format(widget.invoice.grandTotal)),
                                const SizedBox(height: 8),
                                _buildInfoRow('Already Paid', _currencyFormat.format(widget.invoice.amountPaid)),
                                const SizedBox(height: 8),
                                _buildInfoRow(
                                  'Balance Due',
                                  _currencyFormat.format(widget.invoice.amountDue),
                                  valueStyle: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.error,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Payment Date
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Payment Date',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    InkWell(
                                      onTap: _selectDate,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: AppColors.border),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.calendar_today, size: 18, color: AppColors.textSecondary),
                                            const SizedBox(width: 12),
                                            Text(
                                              DateFormat('dd MMM yyyy').format(_paymentDate),
                                              style: const TextStyle(fontSize: 15),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Full Amount button
                              Padding(
                                padding: const EdgeInsets.only(top: 24),
                                child: OutlinedButton.icon(
                                  onPressed: _setFullAmount,
                                  icon: const Icon(Icons.payments, size: 18),
                                  label: const Text('Full Amount'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Payment Mode
                          const Text(
                            'Payment Mode',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),

                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                // Cash
                                if (_cashAccount != null && _amountControllers.containsKey('cash'))
                                  _buildPaymentModeRow(
                                    icon: Icons.money,
                                    label: 'Cash',
                                    amount: _cashAmount,
                                    controller: _amountControllers['cash']!,
                                    onChanged: (value) {
                                      setState(() {
                                        _cashAmount = double.tryParse(value) ?? 0;
                                      });
                                    },
                                  ),

                                // Bank accounts
                                ..._bankAccounts
                                    .where((bank) => bank.id != null && _amountControllers.containsKey(bank.id))
                                    .map((bank) => _buildPaymentModeRow(
                                      icon: Icons.account_balance,
                                      label: bank.name ?? 'Bank',
                                      amount: _bankAmounts[bank.id] ?? 0,
                                      controller: _amountControllers[bank.id]!,
                                      onChanged: (value) {
                                        setState(() {
                                          _bankAmounts[bank.id!] = double.tryParse(value) ?? 0;
                                        });
                                      },
                                      isLast: bank == _bankAccounts.last && _cashAccount == null,
                                    )),
                              ],
                            ),
                          ),

                          // Total
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _isValid
                                  ? AppColors.success.withOpacity(0.1)
                                  : _totalPaymentAmount > widget.invoice.amountDue
                                      ? AppColors.error.withOpacity(0.1)
                                      : AppColors.background,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _isValid
                                          ? Icons.check_circle
                                          : _totalPaymentAmount > widget.invoice.amountDue
                                              ? Icons.error
                                              : Icons.info,
                                      color: _isValid
                                          ? AppColors.success
                                          : _totalPaymentAmount > widget.invoice.amountDue
                                              ? AppColors.error
                                              : AppColors.textSecondary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Total Payment:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  _currencyFormat.format(_totalPaymentAmount),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _isValid
                                        ? AppColors.success
                                        : _totalPaymentAmount > widget.invoice.amountDue
                                            ? AppColors.error
                                            : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (_totalPaymentAmount > widget.invoice.amountDue)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'Payment amount cannot exceed balance due',
                                style: TextStyle(color: AppColors.error, fontSize: 12),
                              ),
                            ),

                          const SizedBox(height: 24),

                          // Note
                          const Text(
                            'Note (Optional)',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _noteController,
                            decoration: const InputDecoration(
                              hintText: 'e.g., Customer paid cash + NEFT',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),
                        ],
                      ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSaving || !_isValid ? null : _savePayment,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check),
                    label: Text(_isSaving ? 'Saving...' : 'Save Payment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {TextStyle? valueStyle}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        Text(
          value,
          style: valueStyle ?? const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary),
        ),
      ],
    );
  }

  Widget _buildPaymentModeRow({
    required IconData icon,
    required String label,
    required double amount,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Text('₹ ', style: TextStyle(color: AppColors.textSecondary)),
          SizedBox(
            width: 120,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
