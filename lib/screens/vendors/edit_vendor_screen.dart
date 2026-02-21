import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/themes.dart';
import '../../services/vendor_service.dart';

class EditVendorScreen extends StatefulWidget {
  final String vendorId;

  const EditVendorScreen({super.key, required this.vendorId});

  @override
  State<EditVendorScreen> createState() => _EditVendorScreenState();
}

class _EditVendorScreenState extends State<EditVendorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vendorService = VendorService();
  bool _isLoading = true;
  bool _isSaving = false;
  Vendor? _vendor;

  // Basic Information Controllers
  final _vendorNameController = TextEditingController();
  final _contactPersonNameController = TextEditingController();
  final _gstNumberController = TextEditingController();
  final _panNumberController = TextEditingController();
  String? _vendorType;

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
  final _vendorCategoryController = TextEditingController();
  final _defaultPaymentTermsController = TextEditingController();
  String? _gstRegistrationStatus;

  final List<String> _vendorTypes = ['Individual', 'Business'];
  final List<String> _gstRegistrationStatuses = [
    'Registered',
    'Unregistered',
    'Composition Scheme',
    'Exempt',
  ];

  @override
  void initState() {
    super.initState();
    _loadVendor();
  }

  @override
  void dispose() {
    _vendorNameController.dispose();
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
    _vendorCategoryController.dispose();
    _defaultPaymentTermsController.dispose();
    super.dispose();
  }

  Future<void> _loadVendor() async {
    setState(() => _isLoading = true);
    final vendor = await _vendorService.getVendorById(widget.vendorId);
    if (vendor != null) {
      _vendorNameController.text = vendor.vendorName ?? '';
      _contactPersonNameController.text = vendor.contactPersonName ?? '';
      _gstNumberController.text = vendor.gstNumber ?? '';
      _panNumberController.text = vendor.panNumber ?? '';
      _vendorType = vendor.vendorType;
      _emailController.text = vendor.email ?? '';
      _phoneNumberController.text = vendor.phoneNumber ?? '';
      _addressLine1Controller.text = vendor.addressLine1 ?? '';
      _addressLine2Controller.text = vendor.addressLine2 ?? '';
      _cityController.text = vendor.city ?? '';
      _stateController.text = vendor.state ?? '';
      _pinCodeController.text = vendor.pinCode ?? '';
      _countryController.text = vendor.country ?? '';
      _placeOfSupplyStateController.text = vendor.placeOfSupplyState ?? '';
      _legalNameAsPerGstController.text = vendor.legalNameAsPerGst ?? '';
      _traderNameController.text = vendor.traderName ?? '';
      _vendorCategoryController.text = vendor.vendorCategory ?? '';
      _defaultPaymentTermsController.text = vendor.defaultPaymentTerms ?? '';
      _gstRegistrationStatus = vendor.gstRegistrationStatus;
    }
    setState(() {
      _vendor = vendor;
      _isLoading = false;
    });
  }

  Future<void> _saveVendor() async {
    if (!_formKey.currentState!.validate()) return;
    if (_vendor == null) return;

    setState(() => _isSaving = true);

    _vendor!.vendorName = _vendorNameController.text.trim();
    _vendor!.vendorType = _vendorType;
    _vendor!.contactPersonName = _contactPersonNameController.text.trim();
    _vendor!.gstNumber = _gstNumberController.text.trim().toUpperCase();
    _vendor!.panNumber = _panNumberController.text.trim().toUpperCase();
    _vendor!.email = _emailController.text.trim();
    _vendor!.phoneNumber = _phoneNumberController.text.trim();
    _vendor!.addressLine1 = _addressLine1Controller.text.trim();
    _vendor!.addressLine2 = _addressLine2Controller.text.trim();
    _vendor!.city = _cityController.text.trim();
    _vendor!.state = _stateController.text.trim();
    _vendor!.pinCode = _pinCodeController.text.trim();
    _vendor!.country = _countryController.text.trim();
    _vendor!.gstRegistrationStatus = _gstRegistrationStatus;
    _vendor!.placeOfSupplyState = _placeOfSupplyStateController.text.trim();
    _vendor!.legalNameAsPerGst = _legalNameAsPerGstController.text.trim();
    _vendor!.traderName = _traderNameController.text.trim();
    _vendor!.vendorCategory = _vendorCategoryController.text.trim();
    _vendor!.defaultPaymentTerms = _defaultPaymentTermsController.text.trim();

    final success = await _vendorService.updateVendor(_vendor!);

    setState(() => _isSaving = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vendor updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/dashboard/vendors/view/${_vendor!.id}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update vendor'),
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
                    onPressed: () => context.go('/dashboard/vendors/view/${_vendor!.id}'),
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
                        const Text(
                          'Edit Vendor',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _vendor!.vendorName ?? 'Update vendor details',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveVendor,
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
                    label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Vyapar Link Info (if linked)
              if (_vendor!.linkedVyaparId != null) ...[
                _buildVyaparLinkInfo(),
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
              const SizedBox(height: 32),

              // Save button at bottom
              Center(
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveVendor,
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
                  label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
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

  Widget _buildVyaparLinkInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.info),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'This vendor is linked to Vyapar ID: ${_vendor!.linkedVyaparId}. '
              'Changes you make here will be local and won\'t affect the original user\'s profile.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.info,
              ),
            ),
          ),
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

  Widget _buildBasicInfoSection() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildTextField(
          controller: _vendorNameController,
          label: 'Vendor Name',
          hint: 'Enter vendor name',
          isRequired: true,
        ),
        _buildDropdown(
          label: 'Vendor Type',
          value: _vendorType,
          items: _vendorTypes,
          onChanged: (value) => setState(() => _vendorType = value),
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
          controller: _vendorCategoryController,
          label: 'Vendor Category',
          hint: 'Enter vendor category',
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
