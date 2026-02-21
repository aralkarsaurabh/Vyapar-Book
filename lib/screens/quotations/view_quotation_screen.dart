import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/themes.dart';
import '../../services/quotation_service.dart';
import '../../services/quotation_pdf_service.dart';
import '../../services/invoice_service.dart';
import '../../widgets/send_to_user_dialog.dart';

class ViewQuotationScreen extends StatefulWidget {
  final String quotationId;

  const ViewQuotationScreen({super.key, required this.quotationId});

  @override
  State<ViewQuotationScreen> createState() => _ViewQuotationScreenState();
}

class _ViewQuotationScreenState extends State<ViewQuotationScreen> {
  final _quotationService = QuotationService();
  final _invoiceService = InvoiceService();
  bool _isLoading = true;
  bool _isGeneratingPdf = false;
  bool _isConverting = false;
  Quotation? _quotation;

  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final _dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _loadQuotation();
  }

  Future<void> _loadQuotation() async {
    setState(() => _isLoading = true);
    final quotation = await _quotationService.getQuotationById(widget.quotationId);
    setState(() {
      _quotation = quotation;
      _isLoading = false;
    });
  }

  Future<void> _downloadPdf() async {
    if (_quotation == null) return;

    setState(() => _isGeneratingPdf = true);

    try {
      final pdfBytes = await QuotationPdfService.generateQuotationPdf(_quotation!);
      final filename = '${_quotation!.quotationNumber?.replaceAll('/', '-') ?? 'quotation'}.pdf';

      // Save to Documents/VyaparBook/Quotations/
      final savedPath = await QuotationPdfService.saveQuotationPdf(pdfBytes, filename);

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
    if (_quotation == null) return;

    final result = await SendToUserDialog.show(
      context,
      documentType: 'quotation',
      documentId: _quotation!.id!,
      documentData: _quotation!.toMap(),
      documentNumber: _quotation!.quotationNumber,
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quotation sent successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _deleteQuotation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Quotation'),
        content: Text('Are you sure you want to delete "${_quotation?.quotationNumber}"?'),
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
      final success = await _quotationService.deleteQuotation(_quotation!.id!);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Quotation deleted successfully'), backgroundColor: AppColors.success),
          );
          context.go('/dashboard/quotations');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete quotation'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  Future<void> _convertToInvoice() async {
    if (_quotation == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Convert to Invoice'),
        content: Text('Convert quotation "${_quotation?.quotationNumber}" to an invoice?\n\nThe quotation number will be saved as reference in the invoice.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Convert'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isConverting = true);

    try {
      // Create invoice from quotation data
      final invoice = Invoice(
        referenceNumber: _quotation!.quotationNumber,
        customerId: _quotation!.customerId,
        customerName: _quotation!.customerName,
        placeOfSupply: _quotation!.placeOfSupply,
        invoiceDate: DateTime.now(),
        dueDate: DateTime.now().add(const Duration(days: 30)),
        invoiceType: _quotation!.quotationType,
        lineItems: _quotation!.lineItems,
        subtotal: _quotation!.subtotal,
        hasDiscount: _quotation!.hasDiscount,
        discountType: _quotation!.discountType,
        discountValue: _quotation!.discountValue,
        discountAmount: _quotation!.discountAmount,
        grandTotal: _quotation!.grandTotal,
        cgstTotal: _quotation!.cgstTotal,
        sgstTotal: _quotation!.sgstTotal,
        igstTotal: _quotation!.igstTotal,
        taxTotal: _quotation!.taxTotal,
        notes: _quotation!.notes,
        termsAndConditions: _quotation!.termsAndConditions,
        companyDetails: _quotation!.companyDetails,
        bankDetails: _quotation!.bankDetails,
        userDetails: _quotation!.userDetails,
        customerDetails: _quotation!.customerDetails,
      );

      final invoiceId = await _invoiceService.addInvoice(invoice);

      if (invoiceId != null) {
        // Mark quotation as converted
        await _quotationService.markAsConvertedToInvoice(_quotation!.id!, invoiceId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invoice created successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
          context.go('/dashboard/invoices/view/$invoiceId');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to create invoice'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConverting = false);
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

    if (_quotation == null) {
      return Container(
        color: AppColors.background,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              const Text('Quotation not found', style: TextStyle(fontSize: 18, color: AppColors.textPrimary)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/dashboard/quotations'),
                child: const Text('Back to Quotations'),
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
                  onPressed: () => context.go('/dashboard/quotations'),
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
                        _quotation!.quotationNumber ?? 'Quotation',
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
                              color: _quotation!.quotationType == 'GST'
                                  ? AppColors.primary.withOpacity(0.1)
                                  : AppColors.warning.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _quotation!.quotationType ?? '-',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _quotation!.quotationType == 'GST'
                                    ? AppColors.primary
                                    : AppColors.warning,
                              ),
                            ),
                          ),
                          if (_quotation!.convertedToInvoice) ...[
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
                                    'Converted to Invoice',
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
                ElevatedButton.icon(
                  onPressed: _quotation!.convertedToInvoice || _isConverting ? null : _convertToInvoice,
                  icon: _isConverting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(_quotation!.convertedToInvoice ? Icons.check_circle : Icons.receipt),
                  label: Text(_isConverting
                      ? 'Converting...'
                      : _quotation!.convertedToInvoice
                          ? 'Already Converted'
                          : 'Convert to Invoice'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _quotation!.convertedToInvoice ? Colors.grey : AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
                if (_quotation!.convertedToInvoice && _quotation!.convertedInvoiceId != null) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/dashboard/invoices/view/${_quotation!.convertedInvoiceId}'),
                    icon: const Icon(Icons.visibility, color: AppColors.primary),
                    label: const Text('View Invoice', style: TextStyle(color: AppColors.primary)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ],
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _deleteQuotation,
                  icon: const Icon(Icons.delete, color: AppColors.error),
                  label: const Text('Delete', style: TextStyle(color: AppColors.error)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => context.go('/dashboard/quotations/edit/${_quotation!.id}'),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Quotation Details Section
            _buildSection(
              title: 'Quotation Details',
              icon: Icons.description,
              child: _buildQuotationDetailsSection(),
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
            if ((_quotation!.notes?.isNotEmpty ?? false) || (_quotation!.termsAndConditions?.isNotEmpty ?? false))
              _buildSection(
                title: 'Additional Details',
                icon: Icons.note_add,
                child: _buildAdditionalDetailsSection(),
              ),
            const SizedBox(height: 24),
          ],
        ),
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

  Widget _buildQuotationDetailsSection() {
    return Wrap(
      spacing: 32,
      runSpacing: 16,
      children: [
        _buildInfoItem('Customer', _quotation!.customerName),
        _buildInfoItem('Place of Supply', _quotation!.placeOfSupply),
        _buildInfoItem('Quotation Date', _quotation!.quotationDate != null ? _dateFormat.format(_quotation!.quotationDate!) : null),
        _buildInfoItem('Valid Until', _quotation!.validUntilDate != null ? _dateFormat.format(_quotation!.validUntilDate!) : null),
        _buildInfoItem('Quotation Type', _quotation!.quotationType),
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
        ...List.generate(_quotation!.lineItems.length, (index) {
          final item = _quotation!.lineItems[index];
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
        _buildTotalRow('Subtotal', _currencyFormat.format(_quotation!.subtotal)),
        if (_quotation!.hasDiscount) ...[
          const Divider(),
          _buildTotalRow(
            'Discount ${_quotation!.discountType == 'percentage' ? '(${_quotation!.discountValue}%)' : ''}',
            '- ${_currencyFormat.format(_quotation!.discountAmount)}',
            isDiscount: true,
          ),
        ],
        const Divider(),
        _buildTotalRow('Grand Total', _currencyFormat.format(_quotation!.grandTotal), isGrandTotal: true),
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
        if (_quotation!.notes?.isNotEmpty ?? false) ...[
          const Text('Notes', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(_quotation!.notes!, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
        ],
        if (_quotation!.termsAndConditions?.isNotEmpty ?? false) ...[
          const Text('Terms and Conditions', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(_quotation!.termsAndConditions!, style: const TextStyle(color: AppColors.textSecondary)),
        ],
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
