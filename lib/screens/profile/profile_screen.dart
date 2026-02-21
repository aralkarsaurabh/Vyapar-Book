import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../config/themes.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _profileService = ProfileService();
  final _authService = AuthService();

  bool _isLoading = true;
  bool _isSaving = false;

  // Vyapar User ID
  String? _msmeId;

  // Logo
  String? _logoBase64;
  Uint8List? _logoBytes;

  // Legal Entity Controllers
  final _companyLegalNameController = TextEditingController();
  final _traderNameController = TextEditingController();
  final _cinController = TextEditingController();
  final _panController = TextEditingController();
  String? _constitutionType;

  // GST and Tax Controllers
  final _gstinController = TextEditingController();
  final _gstRegistrationDateController = TextEditingController();
  final _gstStateCodeController = TextEditingController();
  final _defaultGstRateController = TextEditingController();
  String? _gstRegistrationStatus;
  String? _reverseChargeApplicable;

  // Address Controllers
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _stateController = TextEditingController();
  final _pinCodeController = TextEditingController();
  final _countryController = TextEditingController();

  // Contact Controllers
  final _authorizedContactNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _alternatePhoneNumberController = TextEditingController();
  final _emailAddressController = TextEditingController();
  final _alternateEmailAddressController = TextEditingController();
  final _websiteController = TextEditingController();

  // Banking Controllers
  final _bankAccountHolderNameController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ifscCodeController = TextEditingController();
  final _branchNameController = TextEditingController();
  String? _accountType;

  final List<String> _constitutionTypes = [
    'Proprietorship',
    'Partnership',
    'LLP',
    'Private Limited',
    'Public Limited',
    'One Person Company',
    'HUF',
    'Trust',
    'Society',
    'Other',
  ];

  final List<String> _gstRegistrationStatuses = [
    'Registered',
    'Unregistered',
    'Composition Scheme',
    'Exempt',
  ];

  final List<String> _accountTypes = [
    'Current',
    'Savings',
    'Overdraft',
    'Cash Credit',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _companyLegalNameController.dispose();
    _traderNameController.dispose();
    _cinController.dispose();
    _panController.dispose();
    _gstinController.dispose();
    _gstRegistrationDateController.dispose();
    _gstStateCodeController.dispose();
    _defaultGstRateController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _stateController.dispose();
    _pinCodeController.dispose();
    _countryController.dispose();
    _authorizedContactNameController.dispose();
    _phoneNumberController.dispose();
    _alternatePhoneNumberController.dispose();
    _emailAddressController.dispose();
    _alternateEmailAddressController.dispose();
    _websiteController.dispose();
    _bankAccountHolderNameController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _ifscCodeController.dispose();
    _branchNameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    // Get user data from auth (registration data)
    final userData = await _authService.getCurrentUserInfo();
    final profile = await _profileService.getCompanyProfile();

    setState(() {
      // Load Vyapar ID
      _msmeId = userData['msmeId'];

      if (profile != null) {
        _logoBase64 = profile.logoBase64;
        if (_logoBase64 != null && _logoBase64!.isNotEmpty) {
          _logoBytes = _profileService.base64ToImage(_logoBase64);
        }

        _companyLegalNameController.text = profile.companyLegalName ?? '';
        _traderNameController.text = profile.traderName ?? '';
        _constitutionType = profile.constitutionType;
        _cinController.text = profile.cin ?? '';
        _panController.text = profile.pan ?? '';

        _gstRegistrationStatus = profile.gstRegistrationStatus;
        _gstinController.text = profile.gstin ?? '';
        _gstRegistrationDateController.text = profile.gstRegistrationDate ?? '';
        _gstStateCodeController.text = profile.gstStateCode ?? '';
        _defaultGstRateController.text = profile.defaultGstRate ?? '';
        _reverseChargeApplicable = profile.reverseChargeApplicable;

        _addressLine1Controller.text = profile.addressLine1 ?? '';
        _addressLine2Controller.text = profile.addressLine2 ?? '';
        _cityController.text = profile.city ?? '';
        _districtController.text = profile.district ?? '';
        _stateController.text = profile.state ?? '';
        _pinCodeController.text = profile.pinCode ?? '';
        _countryController.text = profile.country ?? '';

        // Prefill contact details from profile or user registration data
        _authorizedContactNameController.text = profile.authorizedContactName ?? userData['name'] ?? '';
        _phoneNumberController.text = profile.phoneNumber ?? userData['phone'] ?? '';
        _alternatePhoneNumberController.text = profile.alternatePhoneNumber ?? '';
        _emailAddressController.text = profile.emailAddress ?? userData['email'] ?? '';
        _alternateEmailAddressController.text = profile.alternateEmailAddress ?? '';
        _websiteController.text = profile.website ?? '';

        _bankAccountHolderNameController.text = profile.bankAccountHolderName ?? '';
        _bankNameController.text = profile.bankName ?? '';
        _accountNumberController.text = profile.accountNumber ?? '';
        _ifscCodeController.text = profile.ifscCode ?? '';
        _branchNameController.text = profile.branchName ?? '';
        _accountType = profile.accountType;
      } else {
        // No profile exists yet, prefill from user registration data
        _authorizedContactNameController.text = userData['name'] ?? '';
        _phoneNumberController.text = userData['phone'] ?? '';
        _emailAddressController.text = userData['email'] ?? '';
      }
    });

    setState(() => _isLoading = false);
  }

  Future<void> _pickLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        setState(() {
          _logoBytes = bytes;
          _logoBase64 = base64Encode(bytes);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final profile = CompanyProfile(
      logoBase64: _logoBase64,
      companyLegalName: _companyLegalNameController.text.trim(),
      traderName: _traderNameController.text.trim(),
      constitutionType: _constitutionType,
      cin: _cinController.text.trim(),
      pan: _panController.text.trim().toUpperCase(),
      gstRegistrationStatus: _gstRegistrationStatus,
      gstin: _gstinController.text.trim().toUpperCase(),
      gstRegistrationDate: _gstRegistrationDateController.text.trim(),
      gstStateCode: _gstStateCodeController.text.trim(),
      defaultGstRate: _defaultGstRateController.text.trim(),
      reverseChargeApplicable: _reverseChargeApplicable,
      addressLine1: _addressLine1Controller.text.trim(),
      addressLine2: _addressLine2Controller.text.trim(),
      city: _cityController.text.trim(),
      district: _districtController.text.trim(),
      state: _stateController.text.trim(),
      pinCode: _pinCodeController.text.trim(),
      country: _countryController.text.trim(),
      authorizedContactName: _authorizedContactNameController.text.trim(),
      phoneNumber: _phoneNumberController.text.trim(),
      alternatePhoneNumber: _alternatePhoneNumberController.text.trim(),
      emailAddress: _emailAddressController.text.trim(),
      alternateEmailAddress: _alternateEmailAddressController.text.trim(),
      website: _websiteController.text.trim(),
      bankAccountHolderName: _bankAccountHolderNameController.text.trim(),
      bankName: _bankNameController.text.trim(),
      accountNumber: _accountNumberController.text.trim(),
      ifscCode: _ifscCodeController.text.trim().toUpperCase(),
      branchName: _branchNameController.text.trim(),
      accountType: _accountType,
    );

    final success = await _profileService.saveCompanyProfile(profile);

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Profile saved successfully!' : 'Failed to save profile'),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Page header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Company Profile',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Manage your company information',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveProfile,
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
                          label: Text(_isSaving ? 'Saving...' : 'Save Profile'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Vyapar ID Card
                    if (_msmeId != null && _msmeId!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primary.withOpacity(0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.badge,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Your Vyapar ID',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _msmeId!,
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Verified',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Company Logo Section
                    _buildSection(
                      title: 'Company Logo',
                      icon: Icons.image,
                      child: _buildLogoSection(),
                    ),
                    const SizedBox(height: 24),

                    // Legal Entity Section
                    _buildSection(
                      title: 'Legal Entity Details',
                      icon: Icons.business,
                      child: _buildLegalEntitySection(),
                    ),
                    const SizedBox(height: 24),

                    // GST and Tax Section
                    _buildSection(
                      title: 'GST and Tax Identity',
                      icon: Icons.receipt_long,
                      child: _buildGstTaxSection(),
                    ),
                    const SizedBox(height: 24),

                    // Address Section
                    _buildSection(
                      title: 'Registered Address',
                      icon: Icons.location_on,
                      child: _buildAddressSection(),
                    ),
                    const SizedBox(height: 24),

                    // Contact Section
                    _buildSection(
                      title: 'Contact Details',
                      icon: Icons.contact_phone,
                      child: _buildContactSection(),
                    ),
                    const SizedBox(height: 24),

                    // Banking Section
                    _buildSection(
                      title: 'Banking Details',
                      icon: Icons.account_balance,
                      child: _buildBankingSection(),
                    ),
                    const SizedBox(height: 32),

                    // Save button at bottom
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveProfile,
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
                        label: Text(_isSaving ? 'Saving...' : 'Save Profile'),
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

  Widget _buildLogoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: _logoBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.memory(
                        _logoBytes!,
                        fit: BoxFit.contain,
                      ),
                    )
                  : const Icon(
                      Icons.business,
                      size: 48,
                      color: AppColors.textSecondary,
                    ),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickLogo,
                  icon: const Icon(Icons.upload),
                  label: const Text('Upload Logo'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Recommended: 200x200 pixels\nFormats: PNG, JPG, JPEG',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLegalEntitySection() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildTextField(
          controller: _companyLegalNameController,
          label: 'Company Legal Name',
          hint: 'Enter company legal name',
          isRequired: true,
        ),
        _buildTextField(
          controller: _traderNameController,
          label: 'Trader Name (if different)',
          hint: 'Enter trader name',
        ),
        _buildDropdown(
          label: 'Constitution Type',
          value: _constitutionType,
          items: _constitutionTypes,
          onChanged: (value) => setState(() => _constitutionType = value),
        ),
        _buildTextField(
          controller: _cinController,
          label: 'CIN',
          hint: 'Enter CIN number',
        ),
        _buildTextField(
          controller: _panController,
          label: 'PAN Number',
          hint: 'Enter PAN number',
          textCapitalization: TextCapitalization.characters,
        ),
      ],
    );
  }

  Widget _buildGstTaxSection() {
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
          controller: _gstinController,
          label: 'GSTIN Number',
          hint: 'Enter GSTIN',
          textCapitalization: TextCapitalization.characters,
        ),
        _buildTextField(
          controller: _gstRegistrationDateController,
          label: 'GST Registration Date',
          hint: 'DD/MM/YYYY',
        ),
        _buildTextField(
          controller: _gstStateCodeController,
          label: 'GST State Code',
          hint: 'Enter state code',
        ),
        _buildTextField(
          controller: _defaultGstRateController,
          label: 'Default GST Rate (%)',
          hint: 'Enter default rate',
          keyboardType: TextInputType.number,
        ),
        _buildDropdown(
          label: 'Reverse Charge Applicable',
          value: _reverseChargeApplicable,
          items: const ['Yes', 'No'],
          onChanged: (value) => setState(() => _reverseChargeApplicable = value),
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
          controller: _districtController,
          label: 'District',
          hint: 'Enter district',
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

  Widget _buildContactSection() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildTextField(
          controller: _authorizedContactNameController,
          label: 'Authorized Contact Name',
          hint: 'Enter contact name',
        ),
        _buildTextField(
          controller: _phoneNumberController,
          label: 'Phone Number',
          hint: 'Enter phone number',
          keyboardType: TextInputType.phone,
        ),
        _buildTextField(
          controller: _alternatePhoneNumberController,
          label: 'Alternate Phone Number',
          hint: 'Enter alternate phone',
          keyboardType: TextInputType.phone,
        ),
        _buildTextField(
          controller: _emailAddressController,
          label: 'Email Address',
          hint: 'Enter email address',
          keyboardType: TextInputType.emailAddress,
        ),
        _buildTextField(
          controller: _alternateEmailAddressController,
          label: 'Alternate Email Address',
          hint: 'Enter alternate email',
          keyboardType: TextInputType.emailAddress,
        ),
        _buildTextField(
          controller: _websiteController,
          label: 'Website',
          hint: 'Enter website URL',
          keyboardType: TextInputType.url,
        ),
      ],
    );
  }

  Widget _buildBankingSection() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildTextField(
          controller: _bankAccountHolderNameController,
          label: 'Account Holder Name',
          hint: 'Enter account holder name',
        ),
        _buildTextField(
          controller: _bankNameController,
          label: 'Bank Name',
          hint: 'Enter bank name',
        ),
        _buildTextField(
          controller: _accountNumberController,
          label: 'Account Number',
          hint: 'Enter account number',
          keyboardType: TextInputType.number,
        ),
        _buildTextField(
          controller: _ifscCodeController,
          label: 'IFSC Code',
          hint: 'Enter IFSC code',
          textCapitalization: TextCapitalization.characters,
        ),
        _buildTextField(
          controller: _branchNameController,
          label: 'Branch Name',
          hint: 'Enter branch name',
        ),
        _buildDropdown(
          label: 'Account Type',
          value: _accountType,
          items: _accountTypes,
          onChanged: (value) => setState(() => _accountType = value),
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
  }) {
    return SizedBox(
      width: 280,
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
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
      ),
    );
  }
}
