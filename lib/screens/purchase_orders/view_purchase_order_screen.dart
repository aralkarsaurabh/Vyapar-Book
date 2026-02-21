import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/themes.dart';
import '../../services/purchase_order_service.dart';
import '../../services/purchase_order_pdf_service.dart';
import '../../services/quotation_service.dart';

class ViewPurchaseOrderScreen extends StatefulWidget {
  final String poId;

  const ViewPurchaseOrderScreen({super.key, required this.poId});

  @override
  State<ViewPurchaseOrderScreen> createState() =>
      _ViewPurchaseOrderScreenState();
}

class _ViewPurchaseOrderScreenState extends State<ViewPurchaseOrderScreen> {
  final _poService = PurchaseOrderService();
  final _currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final _dateFormat = DateFormat('dd MMM yyyy');

  bool _isLoading = true;
  bool _isSending = false;
  bool _isGeneratingPdf = false;
  PurchaseOrder? _po;

  @override
  void initState() {
    super.initState();
    _loadPO();
  }

  Future<void> _loadPO() async {
    setState(() => _isLoading = true);
    final po = await _poService.getPurchaseOrderById(widget.poId);
    setState(() {
      _po = po;
      _isLoading = false;
    });
  }

  Future<void> _sendToVendor() async {
    if (_po == null) return;

    // Check if vendor is linked via Vyapar ID
    if (_po!.vendorDetails?['linkedUserId'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Vendor is not a VyaparBook user. Cannot send electronically.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send to Vendor'),
        content: Text(
          'Send this purchase order to ${_po!.vendorName}?\n\n'
          'The vendor will receive it in their VyaparBook account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSending = true);

    final success = await _poService.sendToVendor(widget.poId);

    setState(() => _isSending = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase order sent successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadPO(); // Reload to update status
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send purchase order'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deletePO() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Purchase Order'),
        content: Text('Are you sure you want to delete "${_po!.poNumber}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _poService.deletePurchaseOrder(_po!.id!);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Purchase order deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          context.go('/dashboard/purchase-orders');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete purchase order'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _downloadPdf() async {
    if (_po == null) return;

    setState(() => _isGeneratingPdf = true);

    try {
      final pdfBytes = await PurchaseOrderPdfService.generatePurchaseOrderPdf(_po!);
      final filename = '${_po!.poNumber?.replaceAll('/', '-') ?? 'purchase-order'}.pdf';

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

  Color _getStatusColor(String status) {
    switch (status) {
      case POStatus.draft:
        return AppColors.textSecondary;
      case POStatus.sent:
        return AppColors.info;
      case POStatus.acknowledged:
        return AppColors.primary;
      case POStatus.fulfilled:
        return AppColors.success;
      case POStatus.cancelled:
        return AppColors.error;
      default:
        return AppColors.textSecondary;
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

    if (_po == null) {
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

    final statusColor = _getStatusColor(_po!.status);
    final canSend = _po!.status == POStatus.draft &&
        _po!.vendorDetails?['linkedUserId'] != null;
    final canEdit = _po!.status == POStatus.draft;
    final canDelete = _po!.status == POStatus.draft;

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
                            _po!.poNumber ?? 'Purchase Order',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _po!.statusDisplay,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Vendor: ${_po!.vendorName ?? '-'}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canSend) ...[
                  ElevatedButton.icon(
                    onPressed: _isSending ? null : _sendToVendor,
                    icon: _isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                    label: const Text('Send to Vendor'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (canDelete)
                  OutlinedButton.icon(
                    onPressed: _deletePO,
                    icon: const Icon(Icons.delete, color: AppColors.error),
                    label: const Text('Delete',
                        style: TextStyle(color: AppColors.error)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                    ),
                  ),
                if (canEdit) ...[
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () =>
                        context.go('/dashboard/purchase-orders/edit/${_po!.id}'),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                    ),
                  ),
                ],
                const SizedBox(width: 12),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // PO Details
            _buildSection(
              title: 'PO Details',
              icon: Icons.description,
              child: _buildPODetailsSection(),
            ),
            const SizedBox(height: 24),

            // Vendor Details
            _buildSection(
              title: 'Vendor Details',
              icon: Icons.store,
              child: _buildVendorDetailsSection(),
            ),
            const SizedBox(height: 24),

            // Line Items
            _buildSection(
              title: 'Line Items',
              icon: Icons.list,
              child: _buildLineItemsSection(),
            ),
            const SizedBox(height: 24),

            // Totals
            _buildSection(
              title: 'Totals',
              icon: Icons.calculate,
              child: _buildTotalsSection(),
            ),

            if (_po!.notes?.isNotEmpty == true ||
                _po!.termsAndConditions?.isNotEmpty == true ||
                _po!.deliveryAddress?.isNotEmpty == true) ...[
              const SizedBox(height: 24),
              _buildSection(
                title: 'Additional Details',
                icon: Icons.notes,
                child: _buildAdditionalDetailsSection(),
              ),
            ],

            const SizedBox(height: 32),
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

  Widget _buildPODetailsSection() {
    return Wrap(
      spacing: 32,
      runSpacing: 16,
      children: [
        _buildInfoItem('PO Number', _po!.poNumber),
        _buildInfoItem('PO Type', _po!.poType),
        _buildInfoItem('PO Date',
            _po!.poDate != null ? _dateFormat.format(_po!.poDate!) : null),
        _buildInfoItem(
            'Expected Delivery',
            _po!.expectedDeliveryDate != null
                ? _dateFormat.format(_po!.expectedDeliveryDate!)
                : null),
        _buildInfoItem('Place of Supply', _po!.placeOfSupply),
        if (_po!.againstQuotationNumber != null)
          _buildInfoItem('Against Quotation', _po!.againstQuotationNumber),
        if (_po!.sentToVendor && _po!.sentAt != null)
          _buildInfoItem('Sent At', _dateFormat.format(_po!.sentAt!)),
      ],
    );
  }

  Widget _buildVendorDetailsSection() {
    final vendorDetails = _po!.vendorDetails;
    final isLinked = vendorDetails?['linkedVyaparId'] != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isLinked)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, size: 16, color: AppColors.info),
                const SizedBox(width: 6),
                Text(
                  'VyaparBook User: ${vendorDetails?['linkedVyaparId']}',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.info,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        Wrap(
          spacing: 32,
          runSpacing: 16,
          children: [
            _buildInfoItem('Vendor Name', vendorDetails?['vendorName']),
            _buildInfoItem('Contact Person', vendorDetails?['contactPersonName']),
            _buildInfoItem('GST Number', vendorDetails?['gstNumber']),
            _buildInfoItem('Email', vendorDetails?['email']),
            _buildInfoItem('Phone', vendorDetails?['phoneNumber']),
            _buildInfoItem(
              'Address',
              '${vendorDetails?['addressLine1'] ?? ''}, ${vendorDetails?['city'] ?? ''}, ${vendorDetails?['state'] ?? ''} - ${vendorDetails?['pinCode'] ?? ''}',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLineItemsSection() {
    return Column(
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
        ..._po!.lineItems.map((item) => _buildLineItemRow(item)),
      ],
    );
  }

  Widget _buildLineItemRow(LineItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border:
            Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5))),
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
                  item.title ?? '-',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (item.description?.isNotEmpty == true)
                  Text(
                    item.description!,
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
              item.hsnSacCode ?? '-',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${item.quantity} ${item.unitOfMeasure ?? ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              _currencyFormat.format(item.rate),
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${item.gstPercentage.toInt()}%',
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              _currencyFormat.format(item.total),
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
  }

  Widget _buildTotalsSection() {
    final isIntraState = _po!.isIntraState;

    return Column(
      children: [
        _buildTotalRow('Subtotal', _po!.subtotal),
        if (isIntraState) ...[
          _buildTotalRow('CGST', _po!.cgstTotal),
          _buildTotalRow('SGST', _po!.sgstTotal),
        ] else
          _buildTotalRow('IGST', _po!.igstTotal),
        if (_po!.hasDiscount && _po!.discountAmount > 0)
          _buildTotalRow('Discount', -_po!.discountAmount, isNegative: true),
        const Divider(height: 24),
        _buildTotalRow('Grand Total', _po!.grandTotal, isGrand: true),
      ],
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

  Widget _buildAdditionalDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_po!.deliveryAddress?.isNotEmpty == true) ...[
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
            _po!.deliveryAddress!,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_po!.notes?.isNotEmpty == true) ...[
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
            _po!.notes!,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_po!.termsAndConditions?.isNotEmpty == true) ...[
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
            _po!.termsAndConditions!,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
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
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value?.isNotEmpty == true ? value! : '-',
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
}
