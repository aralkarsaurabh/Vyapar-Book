import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/themes.dart';
import '../../services/vendor_service.dart';

class AddVendorScreen extends StatefulWidget {
  const AddVendorScreen({super.key});

  @override
  State<AddVendorScreen> createState() => _AddVendorScreenState();
}

class _AddVendorScreenState extends State<AddVendorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vendorService = VendorService();
  bool _isSaving = false;

  // Mode: manual or vyapar
  bool _isVyaparMode = false;
  bool _isSearching = false;
  Map<String, dynamic>? _foundUser;
  String? _searchError;
  final _vyaparIdController = TextEditingController();

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
  void dispose() {
    _vyaparIdController.dispose();
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

  Future<void> _searchVyaparId() async {
    final vyaparId = _vyaparIdController.text.trim();
    if (vyaparId.isEmpty) {
      setState(() => _searchError = 'Please enter a Vyapar ID');
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
      _foundUser = null;
    });

    final result = await _vendorService.searchUserByVyaparId(vyaparId);

    setState(() => _isSearching = false);

    if (result == null) {
      setState(() => _searchError = 'No user found with this Vyapar ID');
      return;
    }

    if (result.containsKey('error')) {
      setState(() => _searchError = result['message']);
      return;
    }

    // Check if already exists
    final exists = await _vendorService.vendorExistsWithVyaparId(vyaparId);
    if (exists) {
      setState(() => _searchError = 'This vendor is already in your list');
      return;
    }

    setState(() => _foundUser = result);
  }

  Future<void> _addFromVyaparId() async {
    if (_foundUser == null) return;

    setState(() => _isSaving = true);

    final vendorId = await _vendorService.addVendorFromVyaparId(_foundUser!);

    setState(() => _isSaving = false);

    if (mounted) {
      if (vendorId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vendor added successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/dashboard/vendors');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add vendor'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _saveVendor() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final vendor = Vendor(
      vendorName: _vendorNameController.text.trim(),
      vendorType: _vendorType,
      contactPersonName: _contactPersonNameController.text.trim(),
      gstNumber: _gstNumberController.text.trim().toUpperCase(),
      panNumber: _panNumberController.text.trim().toUpperCase(),
      email: _emailController.text.trim(),
      phoneNumber: _phoneNumberController.text.trim(),
      addressLine1: _addressLine1Controller.text.trim(),
      addressLine2: _addressLine2Controller.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      pinCode: _pinCodeController.text.trim(),
      country: _countryController.text.trim(),
      gstRegistrationStatus: _gstRegistrationStatus,
      placeOfSupplyState: _placeOfSupplyStateController.text.trim(),
      legalNameAsPerGst: _legalNameAsPerGstController.text.trim(),
      traderName: _traderNameController.text.trim(),
      vendorCategory: _vendorCategoryController.text.trim(),
      defaultPaymentTerms: _defaultPaymentTermsController.text.trim(),
    );

    final vendorId = await _vendorService.addVendor(vendor);

    setState(() => _isSaving = false);

    if (mounted) {
      if (vendorId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vendor added successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/dashboard/vendors');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add vendor'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Vendor',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Add a new vendor to your list',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Mode Toggle
            _buildModeToggle(),
            const SizedBox(height: 24),

            if (_isVyaparMode) ...[
              // Vyapar ID Search
              _buildVyaparIdSearch(),
            ] else ...[
              // Manual Entry Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
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
                        label: Text(_isSaving ? 'Saving...' : 'Save Vendor'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How would you like to add a vendor?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildModeOption(
                  title: 'Enter Manually',
                  subtitle: 'Fill in vendor details yourself',
                  icon: Icons.edit_note,
                  isSelected: !_isVyaparMode,
                  onTap: () => setState(() {
                    _isVyaparMode = false;
                    _foundUser = null;
                    _searchError = null;
                  }),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildModeOption(
                  title: 'Search by Vyapar ID',
                  subtitle: 'Import from VyaparBook user',
                  icon: Icons.search,
                  isSelected: _isVyaparMode,
                  onTap: () => setState(() {
                    _isVyaparMode = true;
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVyaparIdSearch() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.search, color: AppColors.info, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Search by Vyapar ID',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _vyaparIdController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Vyapar ID',
                    hintText: 'e.g., ABC1234',
                    prefixIcon: const Icon(Icons.tag),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onSubmitted: (_) => _searchVyaparId(),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _isSearching ? null : _searchVyaparId,
                icon: _isSearching
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.search),
                label: Text(_isSearching ? 'Searching...' : 'Search'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                ),
              ),
            ],
          ),
          if (_searchError != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _searchError!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_foundUser != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: AppColors.success),
                      const SizedBox(width: 8),
                      const Text(
                        'User Found on VyaparBook',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildFoundUserDetail('Company', _foundUser!['companyName']),
                  _buildFoundUserDetail('Contact Person', _foundUser!['contactName']),
                  _buildFoundUserDetail('Vyapar ID', _foundUser!['vyaparId']),
                  _buildFoundUserDetail('Email', _foundUser!['email']),
                  if (_foundUser!['gstNumber'] != null)
                    _buildFoundUserDetail('GST Number', _foundUser!['gstNumber']),
                  if (_foundUser!['city'] != null || _foundUser!['state'] != null)
                    _buildFoundUserDetail(
                      'Location',
                      [_foundUser!['city'], _foundUser!['state']]
                          .where((e) => e != null)
                          .join(', '),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _addFromVyaparId,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.add),
                      label: Text(_isSaving ? 'Adding...' : 'Add as Vendor'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFoundUserDetail(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
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
                fontSize: 13,
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
