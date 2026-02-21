import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/themes.dart';
import '../../services/credit_note_service.dart';
import '../../services/credit_note_pdf_service.dart';
import '../../widgets/send_to_user_dialog.dart';

class ViewCreditNoteScreen extends StatefulWidget {
  final String creditNoteId;

  const ViewCreditNoteScreen({super.key, required this.creditNoteId});

  @override
  State<ViewCreditNoteScreen> createState() => _ViewCreditNoteScreenState();
}

class _ViewCreditNoteScreenState extends State<ViewCreditNoteScreen> {
  final _creditNoteService = CreditNoteService();
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  final _dateFormat = DateFormat('dd MMM yyyy');

  CreditNote? _creditNote;
  bool _isLoading = true;
  bool _isGeneratingPdf = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadCreditNote();
  }

  Future<void> _loadCreditNote() async {
    setState(() => _isLoading = true);

    try {
      final creditNote = await _creditNoteService.getCreditNoteById(widget.creditNoteId);
      if (mounted) {
        setState(() {
          _creditNote = creditNote;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading credit note: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _downloadPdf() async {
    if (_creditNote == null) return;

    setState(() => _isGeneratingPdf = true);

    try {
      final pdfBytes = await CreditNotePdfService.generateCreditNotePdf(_creditNote!);
      final filename = 'CreditNote_${_creditNote!.creditNoteNumber?.replaceAll('/', '_') ?? 'CN'}.pdf';
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

  Future<void> _sendToCustomer() async {
    if (_creditNote == null) return;

    setState(() => _isSending = true);

    try {
      // Prepare credit note data for sharing
      final documentData = _creditNote!.toMap();
      documentData['creditNoteNumber'] = _creditNote!.creditNoteNumber;
      documentData['creditNoteDate'] = _creditNote!.creditNoteDate;
      documentData['grandTotal'] = _creditNote!.grandTotal;

      final success = await SendToUserDialog.show(
        context,
        documentType: 'creditNote',
        documentId: _creditNote!.id!,
        documentData: documentData,
        documentNumber: _creditNote!.creditNoteNumber,
      );

      if (success == true) {
        // Mark as sent
        await _creditNoteService.markAsSent(_creditNote!.id!);
        await _loadCreditNote();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Credit note sent successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error sending credit note: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isSending = false);
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
                  child: Text(
                    _creditNote?.creditNoteNumber ?? 'Credit Note',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (_creditNote != null) ...[
                  _buildStatusBadge(_creditNote!.status),
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
                  const SizedBox(width: 8),
                  if (_creditNote!.status != CreditNoteStatus.sent)
                    ElevatedButton.icon(
                      onPressed: _isSending ? null : _sendToCustomer,
                      icon: _isSending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send),
                      label: const Text('Send to Customer'),
                    ),
                ],
              ],
            ),
            const SizedBox(height: 24),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _creditNote == null
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

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String label;
    IconData icon;

    switch (status) {
      case CreditNoteStatus.sent:
        bgColor = AppColors.success.withOpacity(0.1);
        textColor = AppColors.success;
        label = 'SENT';
        icon = Icons.send;
        break;
      case CreditNoteStatus.issued:
        bgColor = AppColors.primary.withOpacity(0.1);
        textColor = AppColors.primary;
        label = 'ISSUED';
        icon = Icons.check_circle;
        break;
      case CreditNoteStatus.draft:
      default:
        bgColor = AppColors.warning.withOpacity(0.1);
        textColor = AppColors.warning;
        label = 'DRAFT';
        icon = Icons.edit_note;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 6),
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

  Widget _buildContent() {
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
                  // Credit Note Info
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildInfoSection(
                          'Credit Note Details',
                          [
                            _buildInfoRow('Credit Note No.', _creditNote!.creditNoteNumber ?? '-'),
                            _buildInfoRow('Date', _creditNote!.creditNoteDate != null
                                ? _dateFormat.format(_creditNote!.creditNoteDate!)
                                : '-'),
                            _buildInfoRow('Against Invoice', _creditNote!.againstInvoiceNumber ?? '-'),
                            _buildInfoRow('Reason', _creditNote!.reason ?? '-'),
                            if (_creditNote!.reasonNotes != null)
                              _buildInfoRow('Notes', _creditNote!.reasonNotes!),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        child: _buildInfoSection(
                          'Customer Details',
                          [
                            _buildInfoRow('Name', _creditNote!.customerName ?? '-'),
                            if (_creditNote!.customerDetails != null) ...[
                              _buildInfoRow('GST', _creditNote!.customerDetails!['gstNumber'] ?? '-'),
                              _buildInfoRow('Address', _creditNote!.customerDetails!['address'] ?? '-'),
                              _buildInfoRow('City', _creditNote!.customerDetails!['city'] ?? '-'),
                              _buildInfoRow('State', _creditNote!.customerDetails!['state'] ?? '-'),
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
                  _buildLineItemsTable(),
                  const SizedBox(height: 24),

                  // Notes
                  if (_creditNote!.notes != null && _creditNote!.notes!.isNotEmpty) ...[
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
                        _creditNote!.notes!,
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
                  _buildSectionTitle('Amount Summary'),
                  const SizedBox(height: 16),
                  _buildSummaryRow('Subtotal', _currencyFormat.format(_creditNote!.subtotal)),
                  const SizedBox(height: 8),
                  if (_creditNote!.cgstTotal > 0)
                    _buildSummaryRow('CGST', _currencyFormat.format(_creditNote!.cgstTotal)),
                  if (_creditNote!.sgstTotal > 0)
                    _buildSummaryRow('SGST', _currencyFormat.format(_creditNote!.sgstTotal)),
                  if (_creditNote!.igstTotal > 0)
                    _buildSummaryRow('IGST', _currencyFormat.format(_creditNote!.igstTotal)),
                  const Divider(height: 32),
                  _buildSummaryRow(
                    'Total Credit',
                    _currencyFormat.format(_creditNote!.grandTotal),
                    isTotal: true,
                  ),
                ],
              ),
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

  Widget _buildLineItemsTable() {
    if (_creditNote!.lineItems.isEmpty) {
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
          ..._creditNote!.lineItems.map((item) {
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
                          item.title ?? 'Item',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        if (item.description != null && item.description!.isNotEmpty)
                          Text(
                            item.description!,
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
                      item.hsnSacCode ?? '-',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      '${item.quantity} ${item.unitOfMeasure ?? ''}',
                      style: const TextStyle(fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      _currencyFormat.format(item.rate),
                      style: const TextStyle(fontSize: 13),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      '${item.gstPercentage.toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      _currencyFormat.format(item.total),
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
