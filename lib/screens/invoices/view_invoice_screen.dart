import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/themes.dart';
import '../../services/invoice_service.dart';
import '../../services/invoice_pdf_service.dart';
import '../../services/payment_service.dart';
import '../../models/payment.dart';
import '../../widgets/send_to_user_dialog.dart';
import '../../widgets/record_payment_dialog.dart';

class ViewInvoiceScreen extends StatefulWidget {
  final String invoiceId;

  const ViewInvoiceScreen({super.key, required this.invoiceId});

  @override
  State<ViewInvoiceScreen> createState() => _ViewInvoiceScreenState();
}

class _ViewInvoiceScreenState extends State<ViewInvoiceScreen> {
  final _invoiceService = InvoiceService();
  final _paymentService = PaymentService();
  bool _isLoading = true;
  bool _isGeneratingPdf = false;
  Invoice? _invoice;
  List<Payment> _payments = [];

  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final _dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _loadInvoice();
  }

  Future<void> _loadInvoice() async {
    setState(() => _isLoading = true);
    final invoice = await _invoiceService.getInvoiceById(widget.invoiceId);
    List<Payment> payments = [];
    if (invoice != null) {
      payments = await _paymentService.getPaymentsForInvoiceOnce(invoice.id!);
    }
    setState(() {
      _invoice = invoice;
      _payments = payments;
      _isLoading = false;
    });
  }

  Future<void> _downloadPdf() async {
    if (_invoice == null) return;

    setState(() => _isGeneratingPdf = true);

    try {
      final pdfBytes = await InvoicePdfService.generateInvoicePdf(_invoice!);
      final filename = '${_invoice!.invoiceNumber?.replaceAll('/', '-') ?? 'invoice'}.pdf';

      // Save to Documents/VyaparBook/Invoices/
      final savedPath = await InvoicePdfService.saveInvoicePdf(pdfBytes, filename);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved to: $savedPath'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  Future<void> _sendToVyaparUser() async {
    if (_invoice == null) return;

    final result = await SendToUserDialog.show(
      context,
      documentType: 'invoice',
      documentId: _invoice!.id!,
      documentData: _invoice!.toMap(),
      documentNumber: _invoice!.invoiceNumber,
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invoice sent successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _recordPayment() async {
    if (_invoice == null) return;

    // Check if invoice is already fully paid
    if (_invoice!.paymentStatus == PaymentStatus.paid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This invoice is already fully paid'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final result = await RecordPaymentDialog.show(context, _invoice!);

    if (result == true && mounted) {
      // Reload invoice to get updated payment status
      await _loadInvoice();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment recorded successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _deleteInvoice() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: Text('Are you sure you want to delete "${_invoice?.invoiceNumber}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _invoiceService.deleteInvoice(_invoice!.id!);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invoice deleted successfully'), backgroundColor: AppColors.success),
          );
          context.go('/dashboard/invoices');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete invoice'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: AppColors.background,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_invoice == null) {
      return Container(
        color: AppColors.background,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              const Text('Invoice not found', style: TextStyle(fontSize: 18, color: AppColors.textPrimary)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/dashboard/invoices'),
                child: const Text('Back to Invoices'),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: AppColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                IconButton(
                  onPressed: () => context.go('/dashboard/invoices'),
                  icon: const Icon(Icons.arrow_back),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _invoice!.invoiceNumber ?? 'Invoice',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _invoice!.invoiceType == 'GST'
                                  ? AppColors.primary.withOpacity(0.1)
                                  : AppColors.warning.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _invoice!.invoiceType ?? '-',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _invoice!.invoiceType == 'GST'
                                    ? AppColors.primary
                                    : AppColors.warning,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildPaymentStatusBadge(_invoice!.paymentStatus),
                        ],
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isGeneratingPdf ? null : _downloadPdf,
                  icon: _isGeneratingPdf
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.picture_as_pdf),
                  label: Text(_isGeneratingPdf ? 'Generating...' : 'Download PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
                const SizedBox(width: 12),
                // Record Payment button
                if (_invoice!.paymentStatus != PaymentStatus.paid)
                  ElevatedButton.icon(
                    onPressed: _recordPayment,
                    icon: const Icon(Icons.payments),
                    label: const Text('Record Payment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.info,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                  ),
                if (_invoice!.paymentStatus != PaymentStatus.paid)
                  const SizedBox(width: 12),
                // Send to Vyapar User button
                OutlinedButton.icon(
                  onPressed: () => _sendToVyaparUser(),
                  icon: Icon(Icons.send, color: AppColors.info),
                  label: Text('Send to Vyapar User', style: TextStyle(color: AppColors.info)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.info),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _deleteInvoice,
                  icon: const Icon(Icons.delete, color: AppColors.error),
                  label: const Text('Delete', style: TextStyle(color: AppColors.error)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => context.go('/dashboard/invoices/edit/${_invoice!.id}'),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Invoice Details Section
            _buildSection(
              title: 'Invoice Details',
              icon: Icons.receipt,
              child: _buildInvoiceDetailsSection(),
            ),
            const SizedBox(height: 24),

            // Line Items Section
            _buildSection(
              title: 'Line Items',
              icon: Icons.list_alt,
              child: _buildLineItemsSection(),
            ),
            const SizedBox(height: 24),

            // Totals Section
            _buildSection(
              title: 'Totals',
              icon: Icons.calculate,
              child: _buildTotalsSection(),
            ),
            const SizedBox(height: 24),

            // Additional Details Section
            if ((_invoice!.notes?.isNotEmpty ?? false) || (_invoice!.termsAndConditions?.isNotEmpty ?? false))
              _buildSection(
                title: 'Additional Details',
                icon: Icons.note_add,
                child: _buildAdditionalDetailsSection(),
              ),
            const SizedBox(height: 24),

            // Payment History Section
            if (_payments.isNotEmpty)
              _buildSection(
                title: 'Payment History',
                icon: Icons.history,
                child: _buildPaymentHistorySection(),
              ),
            if (_payments.isNotEmpty)
              const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String label;
    IconData icon;

    switch (status) {
      case PaymentStatus.paid:
        bgColor = AppColors.success.withOpacity(0.1);
        textColor = AppColors.success;
        label = 'PAID';
        icon = Icons.check_circle;
        break;
      case PaymentStatus.partial:
        bgColor = AppColors.warning.withOpacity(0.1);
        textColor = AppColors.warning;
        label = 'PARTIAL';
        icon = Icons.timelapse;
        break;
      case PaymentStatus.unpaid:
      default:
        bgColor = AppColors.error.withOpacity(0.1);
        textColor = AppColors.error;
        label = 'UNPAID';
        icon = Icons.pending;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceDetailsSection() {
    return Wrap(
      spacing: 32,
      runSpacing: 16,
      children: [
        _buildInfoItem('Customer', _invoice!.customerName),
        _buildInfoItem('Place of Supply', _invoice!.placeOfSupply),
        _buildInfoItem('Invoice Date', _invoice!.invoiceDate != null ? _dateFormat.format(_invoice!.invoiceDate!) : null),
        _buildInfoItem('Credit Period', CreditPeriod.getLabel(_invoice!.creditPeriodDays)),
        _buildInfoItem('Due Date', _invoice!.dueDate != null ? _dateFormat.format(_invoice!.dueDate!) : null),
        _buildInfoItem('Invoice Type', _invoice!.invoiceType),
        _buildInfoItem('Amount Paid', _currencyFormat.format(_invoice!.amountPaid)),
        _buildInfoItem('Amount Due', _currencyFormat.format(_invoice!.amountDue)),
        if (_invoice!.referenceNumber?.isNotEmpty ?? false)
          _buildInfoItem('Reference (Quotation)', _invoice!.referenceNumber),
      ],
    );
  }

  Widget _buildLineItemsSection() {
    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              SizedBox(width: 40, child: Text('#', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
              Expanded(flex: 3, child: Text('Item', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
              SizedBox(width: 100, child: Text('HSN/SAC', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
              SizedBox(width: 70, child: Text('Qty', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.center)),
              SizedBox(width: 100, child: Text('Rate', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.right)),
              SizedBox(width: 90, child: Text('GST %', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.center)),
              SizedBox(width: 120, child: Text('Total', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.right)),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Line Items
        ...List.generate(_invoice!.lineItems.length, (index) {
          final item = _invoice!.lineItems[index];
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 40, child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.w500))),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title ?? '-', style: const TextStyle(fontWeight: FontWeight.w500)),
                      if (item.description?.isNotEmpty ?? false)
                        Text(item.description!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                SizedBox(width: 100, child: Text(item.hsnSacCode ?? '-', style: const TextStyle(fontSize: 14))),
                SizedBox(width: 70, child: Text(item.quantity.toString(), style: const TextStyle(fontSize: 14), textAlign: TextAlign.center)),
                SizedBox(width: 100, child: Text(_currencyFormat.format(item.rate), style: const TextStyle(fontSize: 14), textAlign: TextAlign.right)),
                SizedBox(width: 90, child: Text('${item.gstPercentage.toInt()}%', style: const TextStyle(fontSize: 14), textAlign: TextAlign.center)),
                SizedBox(width: 120, child: Text(_currencyFormat.format(item.total), style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14), textAlign: TextAlign.right)),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTotalsSection() {
    return Column(
      children: [
        _buildTotalRow('Subtotal', _currencyFormat.format(_invoice!.subtotal)),
        if (_invoice!.hasDiscount) ...[
          const Divider(),
          _buildTotalRow(
            'Discount ${_invoice!.discountType == 'percentage' ? '(${_invoice!.discountValue}%)' : ''}',
            '- ${_currencyFormat.format(_invoice!.discountAmount)}',
            isDiscount: true,
          ),
        ],
        const Divider(),
        _buildTotalRow('Grand Total', _currencyFormat.format(_invoice!.grandTotal), isGrandTotal: true),
      ],
    );
  }

  Widget _buildTotalRow(String label, String value, {bool isGrandTotal = false, bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isGrandTotal ? 18 : 14,
              fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.w500,
              color: isDiscount ? AppColors.error : AppColors.textPrimary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isGrandTotal ? 18 : 14,
              fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.w500,
              color: isDiscount ? AppColors.error : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_invoice!.notes?.isNotEmpty ?? false) ...[
          const Text('Notes', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(_invoice!.notes!, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
        ],
        if (_invoice!.termsAndConditions?.isNotEmpty ?? false) ...[
          const Text('Terms and Conditions', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(_invoice!.termsAndConditions!, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ],
    );
  }

  Widget _buildPaymentHistorySection() {
    // Calculate running balance
    double runningBalance = _invoice!.grandTotal;

    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              SizedBox(width: 100, child: Text('Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
              Expanded(flex: 2, child: Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
              SizedBox(width: 120, child: Text('Amount', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.right)),
              SizedBox(width: 120, child: Text('Balance', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.right)),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Payment rows
        ...List.generate(_payments.length, (index) {
          final payment = _payments[index];
          runningBalance -= payment.totalAmount;

          // Build payment mode description
          final modeDescriptions = <String>[];
          for (final mode in payment.modes) {
            if (mode.amount > 0) {
              final name = mode.isCash ? 'Cash' : (mode.bankName ?? 'Bank');
              modeDescriptions.add('$name: ${_currencyFormat.format(mode.amount)}');
            }
          }

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    _dateFormat.format(payment.paymentDate),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...modeDescriptions.map((desc) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(desc, style: const TextStyle(fontSize: 14)),
                          )),
                      if (payment.note?.isNotEmpty ?? false)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            payment.note!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Text(
                    _currencyFormat.format(payment.totalAmount),
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: AppColors.success,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Text(
                    runningBalance <= 0 ? '${_currencyFormat.format(0)} (PAID)' : _currencyFormat.format(runningBalance),
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: runningBalance <= 0 ? AppColors.success : AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildInfoItem(String label, String? value) {
    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(value?.isNotEmpty == true ? value! : '-', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
