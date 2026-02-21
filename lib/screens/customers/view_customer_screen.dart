import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/themes.dart';
import '../../services/customer_service.dart';

class ViewCustomerScreen extends StatefulWidget {
  final String customerId;

  const ViewCustomerScreen({super.key, required this.customerId});

  @override
  State<ViewCustomerScreen> createState() => _ViewCustomerScreenState();
}

class _ViewCustomerScreenState extends State<ViewCustomerScreen> {
  final _customerService = CustomerService();
  bool _isLoading = true;
  Customer? _customer;

  @override
  void initState() {
    super.initState();
    _loadCustomer();
  }

  Future<void> _loadCustomer() async {
    setState(() => _isLoading = true);
    final customer = await _customerService.getCustomerById(widget.customerId);
    setState(() {
      _customer = customer;
      _isLoading = false;
    });
  }

  Future<void> _deleteCustomer() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text('Are you sure you want to delete "${_customer?.customerName}"?'),
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
      final success = await _customerService.deleteCustomer(_customer!.id!);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Customer deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          context.go('/dashboard/customers');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete customer'),
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

    if (_customer == null) {
      return Container(
        color: AppColors.background,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              const Text(
                'Customer not found',
                style: TextStyle(fontSize: 18, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/dashboard/customers'),
                child: const Text('Back to Customers'),
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
                  onPressed: () => context.go('/dashboard/customers'),
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
                        _customer!.customerName ?? 'Customer',
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
                              color: _customer!.customerType == 'Business'
                                  ? AppColors.primary.withOpacity(0.1)
                                  : AppColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _customer!.customerType ?? '-',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _customer!.customerType == 'Business'
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
                OutlinedButton.icon(
                  onPressed: () => context.go('/dashboard/reports/customer-ledger?customerId=${_customer!.id}'),
                  icon: const Icon(Icons.menu_book, color: AppColors.primary),
                  label: const Text('View Ledger', style: TextStyle(color: AppColors.primary)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _deleteCustomer,
                  icon: const Icon(Icons.delete, color: AppColors.error),
                  label: const Text('Delete', style: TextStyle(color: AppColors.error)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => context.go('/dashboard/customers/edit/${_customer!.id}'),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Basic Information Section
            _buildSection(
              title: 'Basic Information',
              icon: Icons.person,
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
        _buildInfoItem('Customer Name', _customer!.customerName),
        _buildInfoItem('Customer Type', _customer!.customerType),
        _buildInfoItem('Contact Person', _customer!.contactPersonName),
        _buildInfoItem('GST Number', _customer!.gstNumber),
        _buildInfoItem('PAN Number', _customer!.panNumber),
      ],
    );
  }

  Widget _buildContactInfoSection() {
    return Wrap(
      spacing: 32,
      runSpacing: 16,
      children: [
        _buildInfoItem('Email', _customer!.email),
        _buildInfoItem('Phone Number', _customer!.phoneNumber),
      ],
    );
  }

  Widget _buildAddressSection() {
    final address = [
      _customer!.addressLine1,
      _customer!.addressLine2,
      _customer!.city,
      _customer!.state,
      _customer!.pinCode,
      _customer!.country,
    ].where((e) => e != null && e.isNotEmpty).join(', ');

    return Wrap(
      spacing: 32,
      runSpacing: 16,
      children: [
        _buildInfoItem('Address Line 1', _customer!.addressLine1),
        _buildInfoItem('Address Line 2', _customer!.addressLine2),
        _buildInfoItem('City', _customer!.city),
        _buildInfoItem('State', _customer!.state),
        _buildInfoItem('Pin Code', _customer!.pinCode),
        _buildInfoItem('Country', _customer!.country),
      ],
    );
  }

  Widget _buildBusinessDetailsSection() {
    return Wrap(
      spacing: 32,
      runSpacing: 16,
      children: [
        _buildInfoItem('GST Registration Status', _customer!.gstRegistrationStatus),
        _buildInfoItem('Place of Supply State', _customer!.placeOfSupplyState),
        _buildInfoItem('Legal Name as per GST', _customer!.legalNameAsPerGst),
        _buildInfoItem('Trader Name', _customer!.traderName),
        _buildInfoItem('Customer Category', _customer!.customerCategory),
        _buildInfoItem('Default Payment Terms', _customer!.defaultPaymentTerms),
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
