import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/themes.dart';
import '../../services/shared_document_service.dart';
import '../../services/quotation_service.dart';
import '../../services/quotation_pdf_service.dart';
import '../../services/vendor_service.dart';

class ViewReceivedQuotationScreen extends StatefulWidget {
  final String sharedDocumentId;

  const ViewReceivedQuotationScreen({super.key, required this.sharedDocumentId});

  @override
  State<ViewReceivedQuotationScreen> createState() => _ViewReceivedQuotationScreenState();
}

class _ViewReceivedQuotationScreenState extends State<ViewReceivedQuotationScreen> {
  final _sharedDocumentService = SharedDocumentService();
  final _vendorService = VendorService();
  bool _isLoading = true;
  bool _isGeneratingPdf = false;
  bool _isAddingVendor = false;
  bool _vendorExists = false;
  SharedDocument? _sharedDocument;
  Quotation? _quotation;

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

      // Reconstruct quotation from snapshot
      final quotation = Quotation.fromMap(sharedDoc.documentSnapshot, sharedDoc.documentId);

      // Check if vendor already exists
      final vendorExists = await _vendorService.vendorExistsWithVyaparId(sharedDoc.senderVyaparId);

      setState(() {
        _sharedDocument = sharedDoc;
        _quotation = quotation;
        _vendorExists = vendorExists;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadPdf() async {
    if (_quotation == null) return;

    setState(() => _isGeneratingPdf = true);

    try {
      final pdfBytes = await QuotationPdfService.generateQuotationPdf(_quotation!);
      final filename = '${_quotation!.quotationNumber?.replaceAll('/', '-') ?? 'quotation'}.pdf';

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

  Future<void> _addAsVendor() async {
    if (_sharedDocument == null) return;

    setState(() => _isAddingVendor = true);

    try {
      // Search for the user to get full details
      final userData = await _vendorService.searchUserByVyaparId(_sharedDocument!.senderVyaparId);

      if (userData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not find user details'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      if (userData.containsKey('error')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(userData['message']),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final vendorId = await _vendorService.addVendorFromVyaparId(userData);

      if (mounted) {
        if (vendorId != null) {
          setState(() => _vendorExists = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vendor added successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vendor already exists or failed to add'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding vendor: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAddingVendor = false);
      }
    }
  }

  void _convertToPurchaseOrder() {
    if (_sharedDocument == null || _quotation == null) return;

    // Prepare quotation data to pass to create PO screen
    final quotationData = {
      'quotationId': _sharedDocument!.documentId,
      'quotationNumber': _quotation!.quotationNumber,
      'senderVyaparId': _sharedDocument!.senderVyaparId,
      'senderCompanyName': _sharedDocument!.senderCompanyName,
      'quotationType': _quotation!.quotationType,
      'lineItems': _quotation!.lineItems.map((item) => {
        'title': item.title,
        'description': item.description,
        'hsnSacCode': item.hsnSacCode,
        'quantity': item.quantity,
        'rate': item.rate,
        'unitOfMeasure': item.unitOfMeasure,
        'gstPercentage': item.gstPercentage,
      }).toList(),
      'notes': _quotation!.notes,
      'termsAndConditions': _quotation!.termsAndConditions,
    };

    context.go('/dashboard/purchase-orders/create', extra: quotationData);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: AppColors.background,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_sharedDocument == null || _quotation == null) {
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
                        ],
                      ),
                    ],
                  ),
                ),
                if (!_vendorExists) ...[
                  OutlinedButton.icon(
                    onPressed: _isAddingVendor ? null : _addAsVendor,
                    icon: _isAddingVendor
                        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.info))
                        : Icon(Icons.store_outlined, color: AppColors.info),
                    label: Text(
                      _isAddingVendor ? 'Adding...' : 'Add as Vendor',
                      style: TextStyle(color: AppColors.info),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.info),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 16, color: AppColors.success),
                        const SizedBox(width: 6),
                        Text(
                          'In Vendors',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Convert to PO button (only shown when vendor exists)
                  ElevatedButton.icon(
                    onPressed: _convertToPurchaseOrder,
                    icon: const Icon(Icons.shopping_cart),
                    label: const Text('Convert to PO'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
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

            if (_quotation!.notes?.isNotEmpty == true || _quotation!.termsAndConditions?.isNotEmpty == true) ...[
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

  Widget _buildQuotationDetailsSection() {
    return Column(
      children: [
        _buildDetailRow('Customer', _quotation!.customerName ?? '-'),
        _buildDetailRow('Place of Supply', _quotation!.placeOfSupply ?? '-'),
        _buildDetailRow('Quotation Date', _quotation!.quotationDate != null
            ? _dateFormat.format(_quotation!.quotationDate!)
            : '-'),
        _buildDetailRow('Valid Until', _quotation!.validUntilDate != null
            ? _dateFormat.format(_quotation!.validUntilDate!)
            : '-'),
        _buildDetailRow('Type', _quotation!.quotationType ?? '-'),
      ],
    );
  }

  Widget _buildLineItemsSection() {
    if (_quotation!.lineItems.isEmpty) {
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
        ...List.generate(_quotation!.lineItems.length, (index) {
          final item = _quotation!.lineItems[index];
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
        _buildTotalRow('Subtotal', _currencyFormat.format(_quotation!.subtotal)),
        if (_quotation!.hasDiscount && _quotation!.discountAmount > 0)
          _buildTotalRow(
            'Discount ${_quotation!.discountType == 'percentage' ? '(${_quotation!.discountValue}%)' : ''}',
            '-${_currencyFormat.format(_quotation!.discountAmount)}',
            isDiscount: true,
          ),
        if (_quotation!.cgstTotal > 0) _buildTotalRow('CGST', _currencyFormat.format(_quotation!.cgstTotal)),
        if (_quotation!.sgstTotal > 0) _buildTotalRow('SGST', _currencyFormat.format(_quotation!.sgstTotal)),
        if (_quotation!.igstTotal > 0) _buildTotalRow('IGST', _currencyFormat.format(_quotation!.igstTotal)),
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
              Text(_currencyFormat.format(_quotation!.grandTotal), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
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
        if (_quotation!.notes?.isNotEmpty == true) ...[
          const Text('Notes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(_quotation!.notes!, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
        ],
        if (_quotation!.termsAndConditions?.isNotEmpty == true) ...[
          const Text('Terms & Conditions', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(_quotation!.termsAndConditions!, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
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
}
