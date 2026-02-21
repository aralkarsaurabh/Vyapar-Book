import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/themes.dart';
import '../services/shared_document_service.dart';
import '../services/invoice_service.dart';
import '../services/vendor_payment_service.dart';
import '../services/vendor_service.dart';

/// Dialog to record a received invoice as a bill in the books
class RecordBillDialog extends StatefulWidget {
  final SharedDocument sharedDocument;
  final Invoice invoice;

  const RecordBillDialog({
    super.key,
    required this.sharedDocument,
    required this.invoice,
  });

  /// Show the dialog and return true if bill was recorded
  static Future<bool?> show(
      BuildContext context, SharedDocument sharedDocument, Invoice invoice) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => RecordBillDialog(
        sharedDocument: sharedDocument,
        invoice: invoice,
      ),
    );
  }

  @override
  State<RecordBillDialog> createState() => _RecordBillDialogState();
}

class _RecordBillDialogState extends State<RecordBillDialog> {
  final _vendorPaymentService = VendorPaymentService();
  final _vendorService = VendorService();
  final _currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final _dateFormat = DateFormat('dd MMM yyyy');

  bool _isLoading = false;
  bool _isSaving = false;
  String? _vendorId;
  bool _vendorExists = false;

  @override
  void initState() {
    super.initState();
    _checkVendor();
  }

  Future<void> _checkVendor() async {
    setState(() => _isLoading = true);

    // Check if we already have this vendor by Vyapar ID
    if (widget.sharedDocument.senderVyaparId.isNotEmpty) {
      final exists = await _vendorService
          .vendorExistsWithVyaparId(widget.sharedDocument.senderVyaparId);

      if (exists) {
        // Get the vendor ID for updating outstanding balance
        final vendors = await _vendorService.getVendors().first;
        final vendor = vendors.firstWhere(
          (v) =>
              v.linkedVyaparId?.toUpperCase() ==
              widget.sharedDocument.senderVyaparId.toUpperCase(),
          orElse: () => Vendor(),
        );
        _vendorId = vendor.id;
        _vendorExists = true;
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _recordBill() async {
    setState(() => _isSaving = true);

    try {
      final success = await _vendorPaymentService.recordBill(
        sharedDocumentId: widget.sharedDocument.id!,
        billNumber: widget.invoice.invoiceNumber ?? '',
        vendorName:
            widget.sharedDocument.senderCompanyName ?? 'Unknown Vendor',
        billDate: widget.invoice.invoiceDate ?? DateTime.now(),
        subtotal: widget.invoice.subtotal,
        grandTotal: widget.invoice.grandTotal,
        cgstAmount: widget.invoice.cgstTotal,
        sgstAmount: widget.invoice.sgstTotal,
        igstAmount: widget.invoice.igstTotal,
        vendorId: _vendorId,
      );

      if (success && mounted) {
        Navigator.of(context).pop(true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to record bill'),
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
        width: 480,
        constraints: const BoxConstraints(maxHeight: 600),
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
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:
                        const Icon(Icons.receipt_long, color: AppColors.info, size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Record Bill',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Add this invoice to your books',
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
                          // Vendor Info
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              children: [
                                _buildInfoRow('Vendor',
                                    widget.sharedDocument.senderCompanyName ?? 'Unknown'),
                                const SizedBox(height: 8),
                                _buildInfoRow('Vyapar ID',
                                    widget.sharedDocument.senderVyaparId),
                                if (!_vendorExists) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.info_outline,
                                            size: 16, color: AppColors.warning),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'This vendor is not in your vendors list. Add them to track payables.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.warning,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Bill Info
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              children: [
                                _buildInfoRow('Bill Number',
                                    widget.invoice.invoiceNumber ?? '-'),
                                const SizedBox(height: 8),
                                _buildInfoRow(
                                    'Bill Date',
                                    widget.invoice.invoiceDate != null
                                        ? _dateFormat
                                            .format(widget.invoice.invoiceDate!)
                                        : '-'),
                                const Divider(height: 24),
                                _buildInfoRow('Subtotal',
                                    _currencyFormat.format(widget.invoice.subtotal)),
                                if (widget.invoice.cgstTotal > 0) ...[
                                  const SizedBox(height: 8),
                                  _buildInfoRow('CGST',
                                      _currencyFormat.format(widget.invoice.cgstTotal)),
                                ],
                                if (widget.invoice.sgstTotal > 0) ...[
                                  const SizedBox(height: 8),
                                  _buildInfoRow('SGST',
                                      _currencyFormat.format(widget.invoice.sgstTotal)),
                                ],
                                if (widget.invoice.igstTotal > 0) ...[
                                  const SizedBox(height: 8),
                                  _buildInfoRow('IGST',
                                      _currencyFormat.format(widget.invoice.igstTotal)),
                                ],
                                const SizedBox(height: 8),
                                _buildInfoRow(
                                  'Total Amount',
                                  _currencyFormat.format(widget.invoice.grandTotal),
                                  valueStyle: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // What this will do
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.success.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.check_circle,
                                        size: 18, color: AppColors.success),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'This will:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildBulletPoint(
                                    'Add ${_currencyFormat.format(widget.invoice.grandTotal)} to your payables'),
                                _buildBulletPoint(
                                    'Record ${_currencyFormat.format(widget.invoice.subtotal)} as purchase expense'),
                                if (widget.invoice.cgstTotal > 0 ||
                                    widget.invoice.sgstTotal > 0 ||
                                    widget.invoice.igstTotal > 0)
                                  _buildBulletPoint(
                                      'Claim ${_currencyFormat.format(widget.invoice.cgstTotal + widget.invoice.sgstTotal + widget.invoice.igstTotal)} GST input credit'),
                              ],
                            ),
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
                    onPressed:
                        _isSaving ? null : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _recordBill,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check),
                    label: Text(_isSaving ? 'Recording...' : 'Record Bill'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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
          style: valueStyle ??
              const TextStyle(
                  fontWeight: FontWeight.w500, color: AppColors.textPrimary),
        ),
      ],
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6, right: 8),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
