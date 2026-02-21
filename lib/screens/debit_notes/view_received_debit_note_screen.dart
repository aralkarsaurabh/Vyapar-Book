import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/themes.dart';
import '../../services/shared_document_service.dart';
import '../../models/debit_note.dart';

class ViewReceivedDebitNoteScreen extends StatefulWidget {
  final String sharedDocumentId;

  const ViewReceivedDebitNoteScreen({super.key, required this.sharedDocumentId});

  @override
  State<ViewReceivedDebitNoteScreen> createState() => _ViewReceivedDebitNoteScreenState();
}

class _ViewReceivedDebitNoteScreenState extends State<ViewReceivedDebitNoteScreen> {
  final _sharedDocumentService = SharedDocumentService();
  bool _isLoading = true;
  SharedDocument? _sharedDocument;
  DebitNote? _debitNote;

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

      // Reconstruct debit note from snapshot
      final debitNote = DebitNote.fromMap(sharedDoc.documentSnapshot, sharedDoc.documentId);

      setState(() {
        _sharedDocument = sharedDoc;
        _debitNote = debitNote;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
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

    if (_sharedDocument == null || _debitNote == null) {
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
                onPressed: () => context.go('/dashboard/debit-notes'),
                child: const Text('Back to Debit Notes'),
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
                  onPressed: () => context.go('/dashboard/debit-notes'),
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
                        _debitNote!.debitNoteNumber ?? 'Debit Note',
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
                              color: AppColors.warning.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.move_to_inbox, size: 14, color: AppColors.warning),
                                const SizedBox(width: 4),
                                Text(
                                  'Received',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.warning,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_debitNote!.reason != null) ...[
                            const SizedBox(width: 8),
                            _buildReasonBadge(_debitNote!.reason!),
                          ],
                        ],
                      ),
                    ],
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

            // Info Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.warning, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Debit Note Received',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_sharedDocument!.senderCompanyName} is requesting credit of ${_currencyFormat.format(_debitNote!.grandTotal)} for the items listed below. Consider issuing a credit note in response.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Debit Note Details
            _buildSection(
              title: 'Debit Note Details',
              icon: Icons.receipt,
              child: _buildDebitNoteDetailsSection(),
            ),
            const SizedBox(height: 24),

            // Line Items
            _buildSection(
              title: 'Line Items',
              icon: Icons.list_alt,
              child: _buildLineItemsSection(),
            ),
            const SizedBox(height: 24),

            // Totals
            _buildSection(
              title: 'Totals',
              icon: Icons.calculate,
              child: _buildTotalsSection(),
            ),

            if (_debitNote!.notes?.isNotEmpty == true) ...[
              const SizedBox(height: 24),
              _buildSection(
                title: 'Notes',
                icon: Icons.notes,
                child: Text(
                  _debitNote!.notes!,
                  style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                ),
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

  Widget _buildReasonBadge(String reason) {
    Color bgColor;
    Color textColor;

    switch (reason) {
      case DebitNoteReason.goodsDamaged:
        bgColor = AppColors.error.withOpacity(0.1);
        textColor = AppColors.error;
        break;
      case DebitNoteReason.shortReceipt:
        bgColor = AppColors.warning.withOpacity(0.1);
        textColor = AppColors.warning;
        break;
      case DebitNoteReason.qualityIssue:
        bgColor = AppColors.info.withOpacity(0.1);
        textColor = AppColors.info;
        break;
      default:
        bgColor = AppColors.textSecondary.withOpacity(0.1);
        textColor = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        reason,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
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

  Widget _buildDebitNoteDetailsSection() {
    return Column(
      children: [
        _buildDetailRow('Against Invoice', _debitNote!.againstBillNumber ?? '-'),
        _buildDetailRow('Debit Note Date', _debitNote!.debitNoteDate != null
            ? _dateFormat.format(_debitNote!.debitNoteDate!)
            : '-'),
        _buildDetailRow('Reason', _debitNote!.reason ?? '-'),
        if (_debitNote!.reasonNotes?.isNotEmpty == true)
          _buildDetailRow('Reason Details', _debitNote!.reasonNotes!),
      ],
    );
  }

  Widget _buildLineItemsSection() {
    if (_debitNote!.lineItems.isEmpty) {
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
        ...List.generate(_debitNote!.lineItems.length, (index) {
          final item = _debitNote!.lineItems[index];
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
        _buildTotalRow('Subtotal', _currencyFormat.format(_debitNote!.subtotal)),
        if (_debitNote!.cgstTotal > 0) _buildTotalRow('CGST', _currencyFormat.format(_debitNote!.cgstTotal)),
        if (_debitNote!.sgstTotal > 0) _buildTotalRow('SGST', _currencyFormat.format(_debitNote!.sgstTotal)),
        if (_debitNote!.igstTotal > 0) _buildTotalRow('IGST', _currencyFormat.format(_debitNote!.igstTotal)),
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
              Text(_currencyFormat.format(_debitNote!.grandTotal), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.warning)),
            ],
          ),
        ),
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

  Widget _buildTotalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
