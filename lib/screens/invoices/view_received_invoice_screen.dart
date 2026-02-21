import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/themes.dart';
import '../../services/shared_document_service.dart';
import '../../services/invoice_service.dart';
import '../../services/invoice_pdf_service.dart';
import '../../services/vendor_payment_service.dart';
import '../../models/vendor_payment.dart';
import '../../widgets/record_bill_dialog.dart';
import '../../widgets/make_payment_dialog.dart';

class ViewReceivedInvoiceScreen extends StatefulWidget {
  final String sharedDocumentId;

  const ViewReceivedInvoiceScreen({super.key, required this.sharedDocumentId});

  @override
  State<ViewReceivedInvoiceScreen> createState() => _ViewReceivedInvoiceScreenState();
}

class _ViewReceivedInvoiceScreenState extends State<ViewReceivedInvoiceScreen> {
  final _sharedDocumentService = SharedDocumentService();
  final _vendorPaymentService = VendorPaymentService();
  bool _isLoading = true;
  bool _isGeneratingPdf = false;
  SharedDocument? _sharedDocument;
  Invoice? _invoice;
  List<VendorPayment> _payments = [];

  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final _dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    setState(() => _isLoading = true);

    final sharedDoc = await _sharedDocumentService.getSharedDocumentById(widget.sharedDocumentId);

    if (sharedDoc != null) {
      // Mark as viewed
      await _sharedDocumentService.markAsViewed(widget.sharedDocumentId);

      // Reconstruct invoice from snapshot
      final invoice = Invoice.fromMap(sharedDoc.documentSnapshot, sharedDoc.documentId);

      // Load payments if bill is recorded
      List<VendorPayment> payments = [];
      if (sharedDoc.isRecorded) {
        payments = await _vendorPaymentService.getPaymentsForBillOnce(widget.sharedDocumentId);
      }

      setState(() {
        _sharedDocument = sharedDoc;
        _invoice = invoice;
        _payments = payments;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _recordBill() async {
    if (_sharedDocument == null || _invoice == null) return;

    final result = await RecordBillDialog.show(
      context,
      _sharedDocument!,
      _invoice!,
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bill recorded successfully'),
          backgroundColor: AppColors.success,
        ),
      );
      // Reload to get updated status
      _loadDocument();
    }
  }

  Future<void> _makePayment() async {
    if (_sharedDocument == null || _invoice == null) return;

    final result = await MakePaymentDialog.show(
      context,
      _sharedDocument!,
      _invoice!,
      amountDue: _sharedDocument!.effectiveAmountDue,
      amountPaid: _sharedDocument!.amountPaid,
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment recorded successfully'),
          backgroundColor: AppColors.success,
        ),
      );
      // Reload to get updated status
      _loadDocument();
    }
  }

  Future<void> _downloadPdf() async {
    if (_invoice == null) return;

    setState(() => _isGeneratingPdf = true);

    try {
      final pdfBytes = await InvoicePdfService.generateInvoicePdf(_invoice!);
      final filename = '${_invoice!.invoiceNumber?.replaceAll('/', '-') ?? 'invoice'}.pdf';

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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: AppColors.background,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_sharedDocument == null || _invoice == null) {
      return Container(
        color: AppColors.background,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              const Text('Document not found', style: TextStyle(fontSize: 18, color: AppColors.textPrimary)),
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
                              color: AppColors.info.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.move_to_inbox, size: 14, color: AppColors.info),
                                const SizedBox(width: 4),
                                Text(
                                  'Received',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.info,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
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
                          // Recording status badge
                          if (_sharedDocument!.isRecorded) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, size: 14, color: AppColors.success),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Recorded',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          // Payment status badge
                          if (_sharedDocument!.isRecorded) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _sharedDocument!.isPaid
                                    ? AppColors.success.withOpacity(0.1)
                                    : _sharedDocument!.isPartiallyPaid
                                        ? AppColors.warning.withOpacity(0.1)
                                        : AppColors.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _sharedDocument!.isPaid
                                    ? 'PAID'
                                    : _sharedDocument!.isPartiallyPaid
                                        ? 'PARTIAL'
                                        : 'UNPAID',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: _sharedDocument!.isPaid
                                      ? AppColors.success
                                      : _sharedDocument!.isPartiallyPaid
                                          ? AppColors.warning
                                          : AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Action buttons based on status
                if (!_sharedDocument!.isRecorded) ...[
                  ElevatedButton.icon(
                    onPressed: _recordBill,
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Record Bill'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.info,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                ] else if (!_sharedDocument!.isPaid) ...[
                  ElevatedButton.icon(
                    onPressed: _makePayment,
                    icon: const Icon(Icons.payment),
                    label: const Text('Make Payment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // Create Debit Note button (only if bill is recorded)
                if (_sharedDocument!.isRecorded) ...[
                  OutlinedButton.icon(
                    onPressed: () => context.go('/dashboard/debit-notes/create?billId=${widget.sharedDocumentId}'),
                    icon: const Icon(Icons.note_alt),
                    label: const Text('Create Debit Note'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.warning,
                      side: BorderSide(color: AppColors.warning),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
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
              ],
            ),
            const SizedBox(height: 24),

            // Sender Info
            _buildSection(
              title: 'Received From',
              icon: Icons.business,
              child: _buildSenderInfoSection(),
            ),
            const SizedBox(height: 24),

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

            // Payment Summary Section (if bill is recorded)
            if (_sharedDocument!.isRecorded) ...[
              const SizedBox(height: 24),
              _buildSection(
                title: 'Payment Summary',
                icon: Icons.account_balance_wallet,
                child: _buildPaymentSummarySection(),
              ),
            ],

            // Payment History Section (if there are payments)
            if (_payments.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildSection(
                title: 'Payment History',
                icon: Icons.history,
                child: _buildPaymentHistorySection(),
              ),
            ],

            if (_invoice!.notes?.isNotEmpty == true || _invoice!.termsAndConditions?.isNotEmpty == true) ...[
              const SizedBox(height: 24),
              _buildSection(
                title: 'Additional Details',
                icon: Icons.notes,
                child: _buildAdditionalDetailsSection(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required IconData icon, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildSenderInfoSection() {
    return Column(
      children: [
        _buildDetailRow('Company', _sharedDocument!.senderCompanyName ?? 'Unknown'),
        _buildDetailRow('Vyapar ID', _sharedDocument!.senderVyaparId),
        _buildDetailRow('Received On', _sharedDocument!.sharedAt != null
            ? _dateFormat.format(_sharedDocument!.sharedAt!)
            : '-'),
      ],
    );
  }

  Widget _buildInvoiceDetailsSection() {
    return Column(
      children: [
        _buildDetailRow('Customer', _invoice!.customerName ?? '-'),
        _buildDetailRow('Place of Supply', _invoice!.placeOfSupply ?? '-'),
        _buildDetailRow('Invoice Date', _invoice!.invoiceDate != null
            ? _dateFormat.format(_invoice!.invoiceDate!)
            : '-'),
        _buildDetailRow('Due Date', _invoice!.dueDate != null
            ? _dateFormat.format(_invoice!.dueDate!)
            : '-'),
        _buildDetailRow('Type', _invoice!.invoiceType ?? '-'),
        if (_invoice!.referenceNumber?.isNotEmpty == true)
          _buildDetailRow('Reference', _invoice!.referenceNumber!),
      ],
    );
  }

  Widget _buildLineItemsSection() {
    if (_invoice!.lineItems.isEmpty) {
      return const Center(
        child: Text('No line items', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: const Row(
            children: [
              SizedBox(width: 40, child: Text('#', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
              Expanded(flex: 3, child: Text('Item', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
              Expanded(flex: 1, child: Text('HSN/SAC', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
              Expanded(flex: 1, child: Text('Qty', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary), textAlign: TextAlign.center)),
              Expanded(flex: 1, child: Text('Rate', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary), textAlign: TextAlign.right)),
              Expanded(flex: 1, child: Text('GST %', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary), textAlign: TextAlign.center)),
              Expanded(flex: 1, child: Text('Total', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary), textAlign: TextAlign.right)),
            ],
          ),
        ),
        // Rows
        ...List.generate(_invoice!.lineItems.length, (index) {
          final item = _invoice!.lineItems[index];
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5))),
            ),
            child: Row(
              children: [
                SizedBox(width: 40, child: Text('${index + 1}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title ?? '-', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                      if (item.description?.isNotEmpty == true)
                        Text(item.description!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Expanded(flex: 1, child: Text(item.hsnSacCode ?? '-', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                Expanded(flex: 1, child: Text('${item.quantity} ${item.unitOfMeasure ?? ''}', style: const TextStyle(fontSize: 13), textAlign: TextAlign.center)),
                Expanded(flex: 1, child: Text(_currencyFormat.format(item.rate), style: const TextStyle(fontSize: 13), textAlign: TextAlign.right)),
                Expanded(flex: 1, child: Text('${item.gstPercentage}%', style: const TextStyle(fontSize: 13), textAlign: TextAlign.center)),
                Expanded(flex: 1, child: Text(_currencyFormat.format(item.total), style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13), textAlign: TextAlign.right)),
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
        if (_invoice!.hasDiscount && _invoice!.discountAmount > 0)
          _buildTotalRow(
            'Discount ${_invoice!.discountType == 'percentage' ? '(${_invoice!.discountValue}%)' : ''}',
            '-${_currencyFormat.format(_invoice!.discountAmount)}',
            isDiscount: true,
          ),
        if (_invoice!.cgstTotal > 0) _buildTotalRow('CGST', _currencyFormat.format(_invoice!.cgstTotal)),
        if (_invoice!.sgstTotal > 0) _buildTotalRow('SGST', _currencyFormat.format(_invoice!.sgstTotal)),
        if (_invoice!.igstTotal > 0) _buildTotalRow('IGST', _currencyFormat.format(_invoice!.igstTotal)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border, width: 2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Grand Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              Text(_currencyFormat.format(_invoice!.grandTotal), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdditionalDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_invoice!.notes?.isNotEmpty == true) ...[
          const Text('Notes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(_invoice!.notes!, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
        ],
        if (_invoice!.termsAndConditions?.isNotEmpty == true) ...[
          const Text('Terms & Conditions', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(_invoice!.termsAndConditions!, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
        ],
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: isDiscount ? AppColors.success : AppColors.textSecondary)),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDiscount ? AppColors.success : AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildPaymentSummarySection() {
    return Column(
      children: [
        _buildDetailRow('Bill Amount', _currencyFormat.format(_invoice!.grandTotal)),
        _buildDetailRow('Amount Paid', _currencyFormat.format(_sharedDocument!.amountPaid)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _sharedDocument!.isPaid
                ? AppColors.success.withOpacity(0.1)
                : _sharedDocument!.isPartiallyPaid
                    ? AppColors.warning.withOpacity(0.1)
                    : AppColors.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Balance Due',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _sharedDocument!.isPaid
                      ? AppColors.success
                      : _sharedDocument!.isPartiallyPaid
                          ? AppColors.warning
                          : AppColors.error,
                ),
              ),
              Text(
                _currencyFormat.format(_sharedDocument!.effectiveAmountDue),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _sharedDocument!.isPaid
                      ? AppColors.success
                      : _sharedDocument!.isPartiallyPaid
                          ? AppColors.warning
                          : AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentHistorySection() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: const Row(
            children: [
              Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
              Expanded(flex: 3, child: Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
              Expanded(flex: 2, child: Text('Amount', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary), textAlign: TextAlign.right)),
            ],
          ),
        ),
        // Payment rows
        ..._payments.map((payment) => _buildPaymentRow(payment)),
      ],
    );
  }

  Widget _buildPaymentRow(VendorPayment payment) {
    // Build payment mode description
    final modeDescriptions = <String>[];
    for (final mode in payment.modes) {
      if (mode.amount > 0) {
        final label = mode.isCash ? 'Cash' : (mode.bankName ?? 'Bank');
        modeDescriptions.add('$label: ${_currencyFormat.format(mode.amount)}');
      }
    }
    final modeText = modeDescriptions.join('\n');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              _dateFormat.format(payment.paymentDate),
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  modeText,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                if (payment.note != null && payment.note!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      payment.note!,
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withOpacity(0.7), fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _currencyFormat.format(payment.totalAmount),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.success),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
