import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/themes.dart';
import '../../services/shared_document_service.dart';
import '../../services/credit_note_pdf_service.dart';
import '../../models/credit_note.dart';

class ViewReceivedCreditNoteScreen extends StatefulWidget {
  final String sharedDocumentId;

  const ViewReceivedCreditNoteScreen({super.key, required this.sharedDocumentId});

  @override
  State<ViewReceivedCreditNoteScreen> createState() => _ViewReceivedCreditNoteScreenState();
}

class _ViewReceivedCreditNoteScreenState extends State<ViewReceivedCreditNoteScreen> {
  final _sharedDocumentService = SharedDocumentService();
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  final _dateFormat = DateFormat('dd MMM yyyy');

  SharedDocument? _document;
  bool _isLoading = true;
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    setState(() => _isLoading = true);

    try {
      final doc = await _sharedDocumentService.getSharedDocumentById(widget.sharedDocumentId);
      if (doc != null) {
        await _sharedDocumentService.markAsViewed(widget.sharedDocumentId);
      }
      if (mounted) {
        setState(() {
          _document = doc;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading document: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _downloadPdf() async {
    if (_document == null) return;

    setState(() => _isGeneratingPdf = true);

    try {
      // Convert shared document snapshot to CreditNote object
      final creditNote = _convertToCreditNote(_document!);
      final pdfBytes = await CreditNotePdfService.generateCreditNotePdf(creditNote);
      final filename = 'CreditNote_${_document!.documentNumber?.replaceAll('/', '_') ?? 'CN'}.pdf';
      await CreditNotePdfService.sharePdf(pdfBytes, filename);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF generated and saved'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error generating PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isGeneratingPdf = false);
    }
  }

  CreditNote _convertToCreditNote(SharedDocument doc) {
    final snapshot = doc.documentSnapshot;

    // Parse line items
    final lineItemsData = snapshot['lineItems'] as List<dynamic>? ?? [];
    final lineItems = lineItemsData.map((itemData) {
      final item = itemData as Map<String, dynamic>;
      return LineItem(
        title: item['title'] as String?,
        description: item['description'] as String?,
        hsnSacCode: item['hsnSacCode'] as String?,
        quantity: (item['quantity'] ?? 0).toInt(),
        rate: (item['rate'] ?? 0).toDouble(),
        unitOfMeasure: item['unitOfMeasure'] as String?,
        gstPercentage: (item['gstPercentage'] ?? 0).toDouble(),
      );
    }).toList();

    return CreditNote(
      id: doc.documentId,
      creditNoteNumber: doc.documentNumber,
      creditNoteDate: doc.documentDate,
      againstInvoiceId: snapshot['againstInvoiceId'] as String?,
      againstInvoiceNumber: snapshot['againstInvoiceNumber'] as String?,
      customerId: snapshot['customerId'] as String?,
      customerName: snapshot['customerName'] as String?,
      placeOfSupply: snapshot['placeOfSupply'] as String?,
      reason: snapshot['reason'] as String?,
      reasonNotes: snapshot['reasonNotes'] as String?,
      lineItems: lineItems,
      subtotal: (snapshot['subtotal'] ?? 0).toDouble(),
      cgstTotal: (snapshot['cgstTotal'] ?? 0).toDouble(),
      sgstTotal: (snapshot['sgstTotal'] ?? 0).toDouble(),
      igstTotal: (snapshot['igstTotal'] ?? 0).toDouble(),
      taxTotal: (snapshot['taxTotal'] ?? 0).toDouble(),
      grandTotal: doc.grandTotal,
      notes: snapshot['notes'] as String?,
      companyDetails: snapshot['companyDetails'] as Map<String, dynamic>?,
      customerDetails: snapshot['customerDetails'] as Map<String, dynamic>?,
      bankDetails: snapshot['bankDetails'] as Map<String, dynamic>?,
      userDetails: snapshot['userDetails'] as Map<String, dynamic>?,
    );
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
            // Header
            Row(
              children: [
                IconButton(
                  onPressed: () => context.go('/dashboard/credit-notes'),
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back to Credit Notes',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _document?.documentNumber ?? 'Credit Note',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (_document != null)
                        Text(
                          'Received from ${_document!.senderCompanyName ?? _document!.senderVyaparId}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_document != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.move_to_inbox, size: 16, color: AppColors.info),
                        SizedBox(width: 6),
                        Text(
                          'RECEIVED',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.info,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: _isGeneratingPdf ? null : _downloadPdf,
                    icon: _isGeneratingPdf
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download),
                    label: const Text('Download PDF'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _document == null
                      ? _buildNotFound()
                      : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'Credit note not found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final snapshot = _document!.documentSnapshot;

    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column - Details
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sender Info Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.info,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Center(
                            child: Text(
                              _document!.senderCompanyName?.isNotEmpty == true
                                  ? _document!.senderCompanyName![0].toUpperCase()
                                  : 'V',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Credit Note From',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                _document!.senderCompanyName ?? 'Unknown Vendor',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Vyapar ID: ${_document!.senderVyaparId}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.info,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Received',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              _document!.sharedAt != null
                                  ? _dateFormat.format(_document!.sharedAt!)
                                  : '-',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Credit Note Details
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildInfoSection(
                          'Credit Note Details',
                          [
                            _buildInfoRow('Credit Note No.', _document!.documentNumber ?? '-'),
                            _buildInfoRow('Date', _document!.documentDate != null
                                ? _dateFormat.format(_document!.documentDate!)
                                : '-'),
                            _buildInfoRow('Against Invoice', snapshot['againstInvoiceNumber'] ?? '-'),
                            _buildInfoRow('Reason', snapshot['reason'] ?? '-'),
                            if (snapshot['reasonNotes'] != null)
                              _buildInfoRow('Notes', snapshot['reasonNotes']),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        child: _buildInfoSection(
                          'Vendor Details',
                          [
                            _buildInfoRow('Company', _document!.senderCompanyName ?? '-'),
                            _buildInfoRow('Vyapar ID', _document!.senderVyaparId),
                            if (snapshot['companyDetails'] != null) ...[
                              _buildInfoRow('GST', snapshot['companyDetails']['gstNumber'] ?? '-'),
                              _buildInfoRow('Address', snapshot['companyDetails']['address'] ?? '-'),
                              _buildInfoRow('City', snapshot['companyDetails']['city'] ?? '-'),
                              _buildInfoRow('State', snapshot['companyDetails']['state'] ?? '-'),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Line Items
                  _buildSectionTitle('Line Items'),
                  const SizedBox(height: 12),
                  _buildLineItemsTable(snapshot),
                  const SizedBox(height: 24),

                  // Notes
                  if (snapshot['notes'] != null && snapshot['notes'].toString().isNotEmpty) ...[
                    _buildSectionTitle('Notes'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        snapshot['notes'],
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(width: 24),

          // Right column - Summary
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Amount Summary'),
                      const SizedBox(height: 16),
                      _buildSummaryRow('Subtotal', _currencyFormat.format((snapshot['subtotal'] ?? 0).toDouble())),
                      const SizedBox(height: 8),
                      if ((snapshot['cgstTotal'] ?? 0) > 0)
                        _buildSummaryRow('CGST', _currencyFormat.format((snapshot['cgstTotal'] ?? 0).toDouble())),
                      if ((snapshot['sgstTotal'] ?? 0) > 0)
                        _buildSummaryRow('SGST', _currencyFormat.format((snapshot['sgstTotal'] ?? 0).toDouble())),
                      if ((snapshot['igstTotal'] ?? 0) > 0)
                        _buildSummaryRow('IGST', _currencyFormat.format((snapshot['igstTotal'] ?? 0).toDouble())),
                      const Divider(height: 32),
                      _buildSummaryRow(
                        'Total Credit',
                        _currencyFormat.format(_document!.grandTotal),
                        isTotal: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.success.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.success, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This credit note reduces your payable to ${_document!.senderCompanyName} by ${_currencyFormat.format(_document!.grandTotal)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.success,
                          ),
                        ),
                      ),
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
            color: isTotal ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: isTotal ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildLineItemsTable(Map<String, dynamic> snapshot) {
    final lineItems = snapshot['lineItems'] as List<dynamic>? ?? [];

    if (lineItems.isEmpty) {
      return const Text('No line items');
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('Item', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                Expanded(flex: 1, child: Text('HSN/SAC', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                Expanded(flex: 1, child: Text('Qty', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13), textAlign: TextAlign.center)),
                Expanded(flex: 1, child: Text('Rate', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13), textAlign: TextAlign.right)),
                Expanded(flex: 1, child: Text('GST %', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13), textAlign: TextAlign.center)),
                Expanded(flex: 1, child: Text('Amount', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13), textAlign: TextAlign.right)),
              ],
            ),
          ),
          // Items
          ...lineItems.map((itemData) {
            final item = itemData as Map<String, dynamic>;
            final quantity = (item['quantity'] ?? 0).toInt();
            final rate = (item['rate'] ?? 0).toDouble();
            final total = (item['total'] ?? (quantity * rate)).toDouble();

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border.withOpacity(0.5))),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'] ?? 'Item',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        if (item['description'] != null && item['description'].toString().isNotEmpty)
                          Text(
                            item['description'],
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      item['hsnSacCode'] ?? '-',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      '$quantity ${item['unitOfMeasure'] ?? ''}',
                      style: const TextStyle(fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      _currencyFormat.format(rate),
                      style: const TextStyle(fontSize: 13),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      '${(item['gstPercentage'] ?? 0).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      _currencyFormat.format(total),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.right,
                    ),
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
