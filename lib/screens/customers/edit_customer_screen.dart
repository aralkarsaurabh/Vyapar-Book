import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/themes.dart';
import '../../services/customer_service.dart';

class EditCustomerScreen extends StatefulWidget {
  final String customerId;

  const EditCustomerScreen({super.key, required this.customerId});

  @override
  State<EditCustomerScreen> createState() => _EditCustomerScreenState();
}

class _EditCustomerScreenState extends State<EditCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerService = CustomerService();
  bool _isLoading = true;
  bool _isSaving = false;
  Customer? _customer;

  // Basic Information Controllers
  final _customerNameController = TextEditingController();
  final _contactPersonNameController = TextEditingController();
  final _gstNumberController = TextEditingController();
  final _panNumberController = TextEditingController();
  String? _customerType;

  // Contact Information Controllers
  final _emailController = TextEditingController();
  final _phoneNumberController = TextEditingController();

  // Address Controllers
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pinCodeController = TextEditingController();
  final _countryController = TextEditingController();

  // Business Details Controllers
  final _placeOfSupplyStateController = TextEditingController();
  final _legalNameAsPerGstController = TextEditingController();
  final _traderNameController = TextEditingController();
  final _customerCategoryController = TextEditingController();
  final _defaultPaymentTermsController = TextEditingController();
  String? _gstRegistrationStatus;

  final List<String> _customerTypes = ['Individual', 'Business'];
  final List<String> _gstRegistrationStatuses = [
    'Registered',
    'Unregistered',
    'Composition Scheme',
    'Exempt',
  ];

  @override
  void initState() {
    super.initState();
    _loadCustomer();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _contactPersonNameController.dispose();
    _gstNumberController.dispose();
    _panNumberController.dispose();
    _emailController.dispose();
    _phoneNumberController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pinCodeController.dispose();
    _countryController.dispose();
    _placeOfSupplyStateController.dispose();
    _legalNameAsPerGstController.dispose();
    _traderNameController.dispose();
    _customerCategoryController.dispose();
    _defaultPaymentTermsController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomer() async {
    setState(() => _isLoading = true);

    final customer = await _customerService.getCustomerById(widget.customerId);

    if (customer != null) {
      setState(() {
        _customer = customer;
        _customerNameController.text = customer.customerName ?? '';
        _customerType = customer.customerType;
        _contactPersonNameController.text = customer.contactPersonName ?? '';
        _gstNumberController.text = customer.gstNumber ?? '';
        _panNumberController.text = customer.panNumber ?? '';
        _emailController.text = customer.email ?? '';
        _phoneNumberController.text = customer.phoneNumber ?? '';
        _addressLine1Controller.text = customer.addressLine1 ?? '';
        _addressLine2Controller.text = customer.addressLine2 ?? '';
        _cityController.text = customer.city ?? '';
        _stateController.text = customer.state ?? '';
        _pinCodeController.text = customer.pinCode ?? '';
        _countryController.text = customer.country ?? '';
        _gstRegistrationStatus = customer.gstRegistrationStatus;
        _placeOfSupplyStateController.text = customer.placeOfSupplyState ?? '';
        _legalNameAsPerGstController.text = customer.legalNameAsPerGst ?? '';
        _traderNameController.text = customer.traderName ?? '';
        _customerCategoryController.text = customer.customerCategory ?? '';
        _defaultPaymentTermsController.text = customer.defaultPaymentTerms ?? '';
      });
    }

    setState(() => _isLoading = false);
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;
    if (_customer == null) return;

    setState(() => _isSaving = true);

    _customer!.customerName = _customerNameController.text.trim();
    _customer!.customerType = _customerType;
    _customer!.contactPersonName = _contactPersonNameController.text.trim();
    _customer!.gstNumber = _gstNumberController.text.trim().toUpperCase();
    _customer!.panNumber = _panNumberController.text.trim().toUpperCase();
    _customer!.email = _emailController.text.trim();
    _customer!.phoneNumber = _phoneNumberController.text.trim();
    _customer!.addressLine1 = _addressLine1Controller.text.trim();
    _customer!.addressLine2 = _addressLine2Controller.text.trim();
    _customer!.city = _cityController.text.trim();
    _customer!.state = _stateController.text.trim();
    _customer!.pinCode = _pinCodeController.text.trim();
    _customer!.country = _countryController.text.trim();
    _customer!.gstRegistrationStatus = _gstRegistrationStatus;
    _customer!.placeOfSupplyState = _placeOfSupplyStateController.text.trim();
    _customer!.legalNameAsPerGst = _legalNameAsPerGstController.text.trim();
    _customer!.traderName = _traderNameController.text.trim();
    _customer!.customerCategory = _customerCategoryController.text.trim();
    _customer!.defaultPaymentTerms = _defaultPaymentTermsController.text.trim();

    final success = await _customerService.updateCustomer(_customer!);

    setState(() => _isSaving = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Customer updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/dashboard/customers');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update customer'),
            backgroundColor: AppColors.error,
          ),
        );
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
        child: Form(
          key: _formKey,
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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Customer',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Update customer details',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveCustomer,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isSaving ? 'Saving...' : 'Update Customer'),
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
              const SizedBox(height: 32),

              // Save button at bottom
              Center(
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveCustomer,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Saving...' : 'Update Customer'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
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
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildTextField(
          controller: _customerNameController,
          label: 'Customer Name',
          hint: 'Enter customer name',
          isRequired: true,
        ),
        _buildDropdown(
          label: 'Customer Type',
          value: _customerType,
          items: _customerTypes,
          onChanged: (value) => setState(() => _customerType = value),
          isRequired: true,
        ),
        _buildTextField(
          controller: _contactPersonNameController,
          label: 'Contact Person Name',
          hint: 'Enter contact person name',
        ),
        _buildTextField(
          controller: _gstNumberController,
          label: 'GST Number',
          hint: 'Enter GST number',
          textCapitalization: TextCapitalization.characters,
        ),
        _buildTextField(
          controller: _panNumberController,
          label: 'PAN Number',
          hint: 'Enter PAN number',
          textCapitalization: TextCapitalization.characters,
        ),
      ],
    );
  }

  Widget _buildContactInfoSection() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildTextField(
          controller: _emailController,
          label: 'Email',
          hint: 'Enter email address',
          keyboardType: TextInputType.emailAddress,
        ),
        _buildTextField(
          controller: _phoneNumberController,
          label: 'Phone Number',
          hint: 'Enter phone number',
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }

  Widget _buildAddressSection() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildTextField(
          controller: _addressLine1Controller,
          label: 'Address Line 1',
          hint: 'Enter address line 1',
          isFullWidth: true,
        ),
        _buildTextField(
          controller: _addressLine2Controller,
          label: 'Address Line 2',
          hint: 'Enter address line 2',
          isFullWidth: true,
        ),
        _buildTextField(
          controller: _cityController,
          label: 'City',
          hint: 'Enter city',
        ),
        _buildTextField(
          controller: _stateController,
          label: 'State',
          hint: 'Enter state',
        ),
        _buildTextField(
          controller: _pinCodeController,
          label: 'Pin Code',
          hint: 'Enter pin code',
          keyboardType: TextInputType.number,
        ),
        _buildTextField(
          controller: _countryController,
          label: 'Country',
          hint: 'Enter country',
        ),
      ],
    );
  }

  Widget _buildBusinessDetailsSection() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildDropdown(
          label: 'GST Registration Status',
          value: _gstRegistrationStatus,
          items: _gstRegistrationStatuses,
          onChanged: (value) => setState(() => _gstRegistrationStatus = value),
        ),
        _buildTextField(
          controller: _placeOfSupplyStateController,
          label: 'Place of Supply State',
          hint: 'Enter place of supply state',
        ),
        _buildTextField(
          controller: _legalNameAsPerGstController,
          label: 'Legal Name as per GST',
          hint: 'Enter legal name as per GST',
        ),
        _buildTextField(
          controller: _traderNameController,
          label: 'Trader Name',
          hint: 'Enter trader name',
        ),
        _buildTextField(
          controller: _customerCategoryController,
          label: 'Customer Category',
          hint: 'Enter customer category',
        ),
        _buildTextField(
          controller: _defaultPaymentTermsController,
          label: 'Default Payment Terms',
          hint: 'e.g., Net 30, Net 60',
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool isRequired = false,
    bool isFullWidth = false,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return SizedBox(
      width: isFullWidth ? double.infinity : 280,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        decoration: InputDecoration(
          labelText: isRequired ? '$label *' : label,
          hintText: hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        validator: isRequired
            ? (value) {
                if (value == null || value.isEmpty) {
                  return 'This field is required';
                }
                return null;
              }
            : null,
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool isRequired = false,
  }) {
    return SizedBox(
      width: 280,
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: isRequired ? '$label *' : label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        items: items.map((item) {
          return DropdownMenuItem(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: onChanged,
        validator: isRequired
            ? (value) {
                if (value == null || value.isEmpty) {
                  return 'This field is required';
                }
                return null;
              }
            : null,
      ),
    );
  }
}
