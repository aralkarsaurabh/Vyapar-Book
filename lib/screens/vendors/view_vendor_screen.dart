import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/themes.dart';
import '../../services/vendor_service.dart';

class ViewVendorScreen extends StatefulWidget {
  final String vendorId;

  const ViewVendorScreen({super.key, required this.vendorId});

  @override
  State<ViewVendorScreen> createState() => _ViewVendorScreenState();
}

class _ViewVendorScreenState extends State<ViewVendorScreen> {
  final _vendorService = VendorService();
  bool _isLoading = true;
  bool _isRefreshing = false;
  Vendor? _vendor;

  @override
  void initState() {
    super.initState();
    _loadVendor();
  }

  Future<void> _loadVendor() async {
    setState(() => _isLoading = true);
    final vendor = await _vendorService.getVendorById(widget.vendorId);
    setState(() {
      _vendor = vendor;
      _isLoading = false;
    });
  }

  Future<void> _refreshFromVyaparId() async {
    if (_vendor?.linkedVyaparId == null) return;

    setState(() => _isRefreshing = true);

    final success = await _vendorService.refreshVendorFromVyaparId(widget.vendorId);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vendor data refreshed successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        await _loadVendor();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to refresh vendor data'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }

    setState(() => _isRefreshing = false);
  }

  Future<void> _deleteVendor() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vendor'),
        content: Text('Are you sure you want to delete "${_vendor?.vendorName}"?'),
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
      final success = await _vendorService.deleteVendor(_vendor!.id!);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vendor deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          context.go('/dashboard/vendors');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete vendor'),
              backgroundColor: AppColors.error,
            ),
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

    if (_vendor == null) {
      return Container(
        color: AppColors.background,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              const Text(
                'Vendor not found',
                style: TextStyle(fontSize: 18, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/dashboard/vendors'),
                child: const Text('Back to Vendors'),
              ),
            ],
          ),
        ),
      );
    }

    final isLinked = _vendor!.linkedVyaparId != null;

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
                  onPressed: () => context.go('/dashboard/vendors'),
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
                          Flexible(
                            child: Text(
                              _vendor!.vendorName ?? 'Vendor',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isLinked) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.info.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.link, size: 14, color: AppColors.info),
                                  const SizedBox(width: 4),
                                  Text(
                                    _vendor!.linkedVyaparId!,
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
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _vendor!.vendorType == 'Business'
                                  ? AppColors.primary.withOpacity(0.1)
                                  : AppColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _vendor!.vendorType ?? '-',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _vendor!.vendorType == 'Business'
                                    ? AppColors.primary
                                    : AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isLinked) ...[
                  OutlinedButton.icon(
                    onPressed: _isRefreshing ? null : _refreshFromVyaparId,
                    icon: _isRefreshing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.refresh, color: AppColors.info),
                    label: Text(
                      'Refresh',
                      style: TextStyle(color: AppColors.info),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.info),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                OutlinedButton.icon(
                  onPressed: () => context.go('/dashboard/reports/vendor-ledger?vendorId=${_vendor!.id}'),
                  icon: Icon(Icons.menu_book, color: AppColors.primary),
                  label: Text('View Ledger', style: TextStyle(color: AppColors.primary)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _deleteVendor,
                  icon: const Icon(Icons.delete, color: AppColors.error),
                  label: const Text('Delete', style: TextStyle(color: AppColors.error)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => context.go('/dashboard/vendors/edit/${_vendor!.id}'),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Vyapar Link Info (if linked)
            if (isLinked) ...[
              _buildVyaparLinkSection(),
              const SizedBox(height: 24),
            ],

            // Basic Information Section
            _buildSection(
              title: 'Basic Information',
              icon: Icons.store,
              child: _buildBasicInfoSection(),
            ),
            const SizedBox(height: 24),

            // Contact Information Section
            _buildSection(
              title: 'Contact Information',
              icon: Icons.contact_phone,
              child: _buildContactInfoSection(),
            ),
            const SizedBox(height: 24),

            // Address Section
            _buildSection(
              title: 'Address',
              icon: Icons.location_on,
              child: _buildAddressSection(),
            ),
            const SizedBox(height: 24),

            // Business Details Section
            _buildSection(
              title: 'Business Details',
              icon: Icons.business,
              child: _buildBusinessDetailsSection(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildVyaparLinkSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.2),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.verified, color: AppColors.info, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Linked to VyaparBook User',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This vendor is linked to Vyapar ID: ${_vendor!.linkedVyaparId}. '
                  'You can refresh to get the latest details from their profile.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (_vendor!.linkedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Linked on: ${_formatDate(_vendor!.linkedAt!)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.year}';
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

  Widget _buildBasicInfoSection() {
    return Wrap(
      spacing: 32,
      runSpacing: 16,
      children: [
        _buildInfoItem('Vendor Name', _vendor!.vendorName),
        _buildInfoItem('Vendor Type', _vendor!.vendorType),
        _buildInfoItem('Contact Person', _vendor!.contactPersonName),
        _buildInfoItem('GST Number', _vendor!.gstNumber),
        _buildInfoItem('PAN Number', _vendor!.panNumber),
      ],
    );
  }

  Widget _buildContactInfoSection() {
    return Wrap(
      spacing: 32,
      runSpacing: 16,
      children: [
        _buildInfoItem('Email', _vendor!.email),
        _buildInfoItem('Phone Number', _vendor!.phoneNumber),
      ],
    );
  }

  Widget _buildAddressSection() {
    return Wrap(
      spacing: 32,
      runSpacing: 16,
      children: [
        _buildInfoItem('Address Line 1', _vendor!.addressLine1),
        _buildInfoItem('Address Line 2', _vendor!.addressLine2),
        _buildInfoItem('City', _vendor!.city),
        _buildInfoItem('State', _vendor!.state),
        _buildInfoItem('Pin Code', _vendor!.pinCode),
        _buildInfoItem('Country', _vendor!.country),
      ],
    );
  }

  Widget _buildBusinessDetailsSection() {
    return Wrap(
      spacing: 32,
      runSpacing: 16,
      children: [
        _buildInfoItem('GST Registration Status', _vendor!.gstRegistrationStatus),
        _buildInfoItem('Place of Supply State', _vendor!.placeOfSupplyState),
        _buildInfoItem('Legal Name as per GST', _vendor!.legalNameAsPerGst),
        _buildInfoItem('Trader Name', _vendor!.traderName),
        _buildInfoItem('Vendor Category', _vendor!.vendorCategory),
        _buildInfoItem('Default Payment Terms', _vendor!.defaultPaymentTerms),
      ],
    );
  }

  Widget _buildInfoItem(String label, String? value) {
    return SizedBox(
      width: 250,
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
