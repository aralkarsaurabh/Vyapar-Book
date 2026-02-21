import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/themes.dart';
import '../../services/purchase_order_service.dart';
import '../../services/purchase_order_pdf_service.dart';
import '../../services/quotation_service.dart';

class ViewReceivedPurchaseOrderScreen extends StatefulWidget {
  final String sharedDocumentId;

  const ViewReceivedPurchaseOrderScreen(
      {super.key, required this.sharedDocumentId});

  @override
  State<ViewReceivedPurchaseOrderScreen> createState() =>
      _ViewReceivedPurchaseOrderScreenState();
}

class _ViewReceivedPurchaseOrderScreenState
    extends State<ViewReceivedPurchaseOrderScreen> {
  final _poService = PurchaseOrderService();
  final _currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final _dateFormat = DateFormat('dd MMM yyyy');

  bool _isLoading = true;
  bool _isGeneratingPdf = false;
  Map<String, dynamic>? _sharedDoc;
  Map<String, dynamic>? _poSnapshot;

  @override
  void initState() {
    super.initState();
    _loadPO();
  }

  Future<void> _loadPO() async {
    setState(() => _isLoading = true);
    final doc = await _poService.getReceivedPOById(widget.sharedDocumentId);
    setState(() {
      _sharedDoc = doc;
      _poSnapshot = doc?['documentSnapshot'] as Map<String, dynamic>?;
      _isLoading = false;
    });
  }

  Future<void> _downloadPdf() async {
    if (_poSnapshot == null) return;

    setState(() => _isGeneratingPdf = true);

    try {
      // Reconstruct PurchaseOrder from snapshot
      final po = PurchaseOrder.fromMap(_poSnapshot!, _sharedDoc!['documentId'] ?? '');

      final pdfBytes = await PurchaseOrderPdfService.generatePurchaseOrderPdf(po);
      final filename = '${po.poNumber?.replaceAll('/', '-') ?? 'purchase-order'}.pdf';

      final savedPath = await PurchaseOrderPdfService.savePurchaseOrderPdf(pdfBytes, filename);

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
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: AppColors.error,
          ),
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

    if (_sharedDoc == null || _poSnapshot == null) {
      return Container(
        color: AppColors.background,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              const Text(
                'Purchase order not found',
                style: TextStyle(fontSize: 18, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/dashboard/purchase-orders'),
                child: const Text('Back to Purchase Orders'),
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
            _buildHeader(),
            const SizedBox(height: 24),
            _buildSenderInfo(),
            const SizedBox(height: 24),
            _buildPODetails(),
            const SizedBox(height: 24),
            _buildLineItems(),
            const SizedBox(height: 24),
            _buildTotals(),
            if (_poSnapshot!['deliveryAddress']?.isNotEmpty == true ||
                _poSnapshot!['notes']?.isNotEmpty == true ||
                _poSnapshot!['termsAndConditions']?.isNotEmpty == true) ...[
              const SizedBox(height: 24),
              _buildAdditionalDetails(),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final poNumber = _sharedDoc!['documentNumber'] ?? 'Purchase Order';
    final sharedAt = _sharedDoc!['sharedAt'] != null
        ? (_sharedDoc!['sharedAt'] as Timestamp).toDate()
        : null;

    return Row(
      children: [
        IconButton(
          onPressed: () => context.go('/dashboard/purchase-orders'),
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
              Row(
                children: [
                  Text(
                    poNumber,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.move_to_inbox,
                            size: 14, color: AppColors.info),
                        const SizedBox(width: 4),
                        Text(
                          'Received',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.info,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (sharedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Received on ${_dateFormat.format(sharedAt)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: _isGeneratingPdf ? null : _downloadPdf,
          icon: _isGeneratingPdf
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.picture_as_pdf),
          label: Text(_isGeneratingPdf ? 'Generating...' : 'Download PDF'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildSenderInfo() {
    final senderCompanyName = _sharedDoc!['senderCompanyName'] ?? 'Unknown';
    final senderVyaparId = _sharedDoc!['senderVyaparId'] ?? '';
    final buyerDetails =
        _poSnapshot!['userDetails'] as Map<String, dynamic>? ?? {};

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.info.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Text(
                    senderCompanyName.isNotEmpty
                        ? senderCompanyName[0].toUpperCase()
                        : 'U',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.info,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Purchase Order From',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.info.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified,
                                  size: 12, color: AppColors.info),
                              const SizedBox(width: 4),
                              Text(
                                senderVyaparId,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.info,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      senderCompanyName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Wrap(
            spacing: 32,
            runSpacing: 12,
            children: [
              _buildInfoItem(
                  'Contact', buyerDetails['name']?.toString() ?? '-'),
              _buildInfoItem(
                  'Email', buyerDetails['email']?.toString() ?? '-'),
              _buildInfoItem(
                  'Address', buyerDetails['address']?.toString() ?? '-'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPODetails() {
    final poDate = _poSnapshot!['poDate'] != null
        ? (_poSnapshot!['poDate'] as Timestamp).toDate()
        : null;
    final expectedDeliveryDate = _poSnapshot!['expectedDeliveryDate'] != null
        ? (_poSnapshot!['expectedDeliveryDate'] as Timestamp).toDate()
        : null;

    return _buildSection(
      title: 'PO Details',
      icon: Icons.description,
      child: Wrap(
        spacing: 32,
        runSpacing: 16,
        children: [
          _buildInfoItem(
              'PO Number', _poSnapshot!['poNumber']?.toString() ?? '-'),
          _buildInfoItem('PO Type', _poSnapshot!['poType']?.toString() ?? '-'),
          _buildInfoItem(
              'PO Date', poDate != null ? _dateFormat.format(poDate) : '-'),
          _buildInfoItem(
              'Expected Delivery',
              expectedDeliveryDate != null
                  ? _dateFormat.format(expectedDeliveryDate)
                  : '-'),
          _buildInfoItem(
              'Place of Supply', _poSnapshot!['placeOfSupply']?.toString() ?? '-'),
        ],
      ),
    );
  }

  Widget _buildLineItems() {
    final lineItems = _poSnapshot!['lineItems'] as List<dynamic>? ?? [];

    return _buildSection(
      title: 'Line Items',
      icon: Icons.list,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: const Row(
              children: [
                Expanded(
                    flex: 3,
                    child: Text('Item',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary))),
                Expanded(
                    flex: 1,
                    child: Text('HSN',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary))),
                Expanded(
                    flex: 1,
                    child: Text('Qty',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary))),
                Expanded(
                    flex: 1,
                    child: Text('Rate',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary))),
                Expanded(
                    flex: 1,
                    child: Text('GST',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary))),
                Expanded(
                    flex: 1,
                    child: Text('Total',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary))),
              ],
            ),
          ),
          // Items
          ...lineItems.map((item) {
            final itemMap = item as Map<String, dynamic>;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                    bottom:
                        BorderSide(color: AppColors.border.withOpacity(0.5))),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          itemMap['title']?.toString() ?? '-',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (itemMap['description']?.toString().isNotEmpty ==
                            true)
                          Text(
                            itemMap['description'].toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      itemMap['hsnSacCode']?.toString() ?? '-',
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      '${itemMap['quantity'] ?? 0} ${itemMap['unitOfMeasure'] ?? ''}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      _currencyFormat.format(itemMap['rate'] ?? 0),
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      '${(itemMap['gstPercentage'] ?? 0).toInt()}%',
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      _currencyFormat.format(itemMap['total'] ?? 0),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
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

  Widget _buildTotals() {
    final subtotal = (_poSnapshot!['subtotal'] ?? 0).toDouble();
    final cgstTotal = (_poSnapshot!['cgstTotal'] ?? 0).toDouble();
    final sgstTotal = (_poSnapshot!['sgstTotal'] ?? 0).toDouble();
    final igstTotal = (_poSnapshot!['igstTotal'] ?? 0).toDouble();
    final hasDiscount = _poSnapshot!['hasDiscount'] ?? false;
    final discountAmount = (_poSnapshot!['discountAmount'] ?? 0).toDouble();
    final grandTotal = (_poSnapshot!['grandTotal'] ?? 0).toDouble();

    final hasIGST = igstTotal > 0;

    return _buildSection(
      title: 'Totals',
      icon: Icons.calculate,
      child: Column(
        children: [
          _buildTotalRow('Subtotal', subtotal),
          if (!hasIGST) ...[
            _buildTotalRow('CGST', cgstTotal),
            _buildTotalRow('SGST', sgstTotal),
          ] else
            _buildTotalRow('IGST', igstTotal),
          if (hasDiscount && discountAmount > 0)
            _buildTotalRow('Discount', -discountAmount, isNegative: true),
          const Divider(height: 24),
          _buildTotalRow('Grand Total', grandTotal, isGrand: true),
        ],
      ),
    );
  }

  Widget _buildAdditionalDetails() {
    return _buildSection(
      title: 'Additional Details',
      icon: Icons.notes,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_poSnapshot!['deliveryAddress']?.toString().isNotEmpty ==
              true) ...[
            const Text(
              'Delivery Address',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _poSnapshot!['deliveryAddress'].toString(),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_poSnapshot!['notes']?.toString().isNotEmpty == true) ...[
            const Text(
              'Notes',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _poSnapshot!['notes'].toString(),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_poSnapshot!['termsAndConditions']?.toString().isNotEmpty ==
              true) ...[
            const Text(
              'Terms & Conditions',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _poSnapshot!['termsAndConditions'].toString(),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ],
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

  Widget _buildInfoItem(String label, String value) {
    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isNotEmpty ? value : '-',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount,
      {bool isGrand = false, bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isGrand ? 18 : 14,
              fontWeight: isGrand ? FontWeight.bold : FontWeight.w500,
              color: isNegative ? AppColors.success : AppColors.textPrimary,
            ),
          ),
          Text(
            _currencyFormat.format(amount.abs()),
            style: TextStyle(
              fontSize: isGrand ? 20 : 14,
              fontWeight: isGrand ? FontWeight.bold : FontWeight.w500,
              color: isNegative ? AppColors.success : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
