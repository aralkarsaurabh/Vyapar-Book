import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/themes.dart';
import '../../services/purchase_order_service.dart';
import '../../services/quotation_service.dart';
import '../../services/vendor_service.dart';
import '../../services/profile_service.dart';
import '../../services/auth_service.dart';

class EditPurchaseOrderScreen extends StatefulWidget {
  final String poId;

  const EditPurchaseOrderScreen({super.key, required this.poId});

  @override
  State<EditPurchaseOrderScreen> createState() =>
      _EditPurchaseOrderScreenState();
}

class _EditPurchaseOrderScreenState extends State<EditPurchaseOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _poService = PurchaseOrderService();
  final _vendorService = VendorService();
  final _profileService = ProfileService();
  final _authService = AuthService();

  bool _isLoading = true;
  bool _isSaving = false;
  PurchaseOrder? _po;

  List<Vendor> _vendors = [];
  Vendor? _selectedVendor;

  String? _placeOfSupply;
  DateTime _poDate = DateTime.now();
  DateTime _expectedDeliveryDate = DateTime.now().add(const Duration(days: 15));
  String _poType = 'GST';

  List<LineItem> _lineItems = [LineItem()];

  bool _hasDiscount = false;
  String _discountType = 'percentage';
  final _discountValueController = TextEditingController(text: '0');

  final _notesController = TextEditingController();
  final _termsController = TextEditingController();
  final _deliveryAddressController = TextEditingController();

  CompanyProfile? _companyProfile;
  Map<String, String?>? _userInfo;

  final _currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _discountValueController.dispose();
    _notesController.dispose();
    _termsController.dispose();
    _deliveryAddressController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Load PO
    _po = await _poService.getPurchaseOrderById(widget.poId);

    if (_po == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Load vendors
    final vendorsStream = _vendorService.getVendors();
    final vendors = await vendorsStream.first;

    // Load company profile
    _companyProfile = await _profileService.getCompanyProfile();
    _userInfo = await _authService.getCurrentUserInfo();

    // Populate form fields
    _vendors = vendors;
    _selectedVendor =
        vendors.where((v) => v.id == _po!.vendorId).firstOrNull;
    _placeOfSupply = _po!.placeOfSupply;
    _poDate = _po!.poDate ?? DateTime.now();
    _expectedDeliveryDate =
        _po!.expectedDeliveryDate ?? DateTime.now().add(const Duration(days: 15));
    _poType = _po!.poType ?? 'GST';
    _lineItems = _po!.lineItems.isNotEmpty ? _po!.lineItems : [LineItem()];
    _hasDiscount = _po!.hasDiscount;
    _discountType = _po!.discountType ?? 'percentage';
    _discountValueController.text = _po!.discountValue.toString();
    _notesController.text = _po!.notes ?? '';
    _termsController.text = _po!.termsAndConditions ?? '';
    _deliveryAddressController.text = _po!.deliveryAddress ?? '';

    setState(() => _isLoading = false);
  }

  void _addLineItem() {
    setState(() {
      _lineItems.add(LineItem());
    });
  }

  void _removeLineItem(int index) {
    if (_lineItems.length > 1) {
      setState(() {
        _lineItems.removeAt(index);
        _calculateTotals();
      });
    }
  }

  bool get _isIntraState {
    final companyState = _companyProfile?.state;
    final vendorState = _selectedVendor?.state;
    return companyState != null &&
        vendorState != null &&
        companyState == vendorState;
  }

  void _calculateTotals() {
    setState(() {
      final intraState = _isIntraState;
      for (var item in _lineItems) {
        item.calculateTotal(isIntraState: intraState);
      }
    });
  }

  double get _subtotal {
    return _lineItems.fold(0, (sum, item) => sum + item.taxableAmount);
  }

  double get _cgstTotal {
    return _lineItems.fold(0, (sum, item) => sum + item.cgstAmount);
  }

  double get _sgstTotal {
    return _lineItems.fold(0, (sum, item) => sum + item.sgstAmount);
  }

  double get _igstTotal {
    return _lineItems.fold(0, (sum, item) => sum + item.igstAmount);
  }

  double get _taxTotal {
    return _cgstTotal + _sgstTotal + _igstTotal;
  }

  double get _discountAmount {
    if (!_hasDiscount) return 0;
    final discountValue = double.tryParse(_discountValueController.text) ?? 0;
    if (_discountType == 'percentage') {
      return _subtotal * (discountValue / 100);
    }
    return discountValue;
  }

  double get _grandTotal {
    final total = _subtotal + _taxTotal - _discountAmount;
    return total < 0 ? 0 : total;
  }

  Future<void> _selectDate(BuildContext context, bool isPODate) async {
    final initialDate = isPODate ? _poDate : _expectedDeliveryDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isPODate) {
          _poDate = picked;
        } else {
          _expectedDeliveryDate = picked;
        }
      });
    }
  }

  Future<void> _savePurchaseOrder() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedVendor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a vendor'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_placeOfSupply == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select place of supply'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    _calculateTotals();

    _po!.vendorId = _selectedVendor!.id;
    _po!.vendorName = _selectedVendor!.vendorName;
    _po!.vendorGst = _selectedVendor!.gstNumber;
    _po!.placeOfSupply = _placeOfSupply;
    _po!.poDate = _poDate;
    _po!.expectedDeliveryDate = _expectedDeliveryDate;
    _po!.poType = _poType;
    _po!.lineItems = _lineItems;
    _po!.subtotal = _subtotal;
    _po!.hasDiscount = _hasDiscount;
    _po!.discountType = _discountType;
    _po!.discountValue = double.tryParse(_discountValueController.text) ?? 0;
    _po!.discountAmount = _discountAmount;
    _po!.grandTotal = _grandTotal;
    _po!.cgstTotal = _cgstTotal;
    _po!.sgstTotal = _sgstTotal;
    _po!.igstTotal = _igstTotal;
    _po!.taxTotal = _taxTotal;
    _po!.notes = _notesController.text.trim();
    _po!.termsAndConditions = _termsController.text.trim();
    _po!.deliveryAddress = _deliveryAddressController.text.trim();
    _po!.companyDetails = _companyProfile?.toMap();
    _po!.vendorDetails = {
      'vendorName': _selectedVendor!.vendorName,
      'vendorType': _selectedVendor!.vendorType,
      'contactPersonName': _selectedVendor!.contactPersonName,
      'gstNumber': _selectedVendor!.gstNumber,
      'panNumber': _selectedVendor!.panNumber,
      'email': _selectedVendor!.email,
      'phoneNumber': _selectedVendor!.phoneNumber,
      'addressLine1': _selectedVendor!.addressLine1,
      'addressLine2': _selectedVendor!.addressLine2,
      'city': _selectedVendor!.city,
      'state': _selectedVendor!.state,
      'pinCode': _selectedVendor!.pinCode,
      'country': _selectedVendor!.country,
      'linkedVyaparId': _selectedVendor!.linkedVyaparId,
      'linkedUserId': _selectedVendor!.linkedUserId,
    };

    final success = await _poService.updatePurchaseOrder(_po!);

    setState(() => _isSaving = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase Order updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/dashboard/purchase-orders/view/${_po!.id}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update purchase order'),
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

    if (_po!.status != POStatus.draft) {
      return Container(
        color: AppColors.background,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 64, color: AppColors.warning),
              const SizedBox(height: 16),
              const Text(
                'This purchase order cannot be edited',
                style: TextStyle(fontSize: 18, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Status: ${_po!.statusDisplay}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () =>
                    context.go('/dashboard/purchase-orders/view/${_po!.id}'),
                child: const Text('View Purchase Order'),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: AppColors.background,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildVendorSection(),
              const SizedBox(height: 24),
              _buildPODetailsSection(),
              const SizedBox(height: 24),
              _buildLineItemsSection(),
              const SizedBox(height: 24),
              _buildTotalsSection(),
              const SizedBox(height: 24),
              _buildAdditionalDetailsSection(),
              const SizedBox(height: 32),
              _buildActionButtons(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: () =>
              context.go('/dashboard/purchase-orders/view/${_po!.id}'),
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit ${_po!.poNumber ?? 'Purchase Order'}',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Draft',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.warning,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVendorSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.store, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Vendor Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<Vendor>(
            value: _selectedVendor,
            decoration: const InputDecoration(
              labelText: 'Select Vendor *',
              border: OutlineInputBorder(),
            ),
            items: _vendors.map((vendor) {
              return DropdownMenuItem(
                value: vendor,
                child: Text(vendor.vendorName ?? 'Unknown'),
              );
            }).toList(),
            onChanged: (vendor) {
              setState(() {
                _selectedVendor = vendor;
                _placeOfSupply = vendor?.state;
                _calculateTotals();
              });
            },
            validator: (value) =>
                value == null ? 'Please select a vendor' : null,
          ),
          if (_selectedVendor != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(
                      'Contact', _selectedVendor!.contactPersonName ?? '-'),
                  _buildInfoRow('GST', _selectedVendor!.gstNumber ?? '-'),
                  _buildInfoRow(
                    'Address',
                    '${_selectedVendor!.addressLine1 ?? ''}, ${_selectedVendor!.city ?? ''}, ${_selectedVendor!.state ?? ''}',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
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
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPODetailsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.description, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'PO Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _placeOfSupply,
                  decoration: const InputDecoration(
                    labelText: 'Place of Supply *',
                    border: OutlineInputBorder(),
                  ),
                  items: QuotationService.indianStates.map((state) {
                    return DropdownMenuItem(value: state, child: Text(state));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _placeOfSupply = value;
                      _calculateTotals();
                    });
                  },
                  validator: (value) =>
                      value == null ? 'Please select place of supply' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _poType,
                  decoration: const InputDecoration(
                    labelText: 'PO Type *',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'GST', child: Text('GST')),
                    DropdownMenuItem(value: 'Non-GST', child: Text('Non-GST')),
                  ],
                  onChanged: (value) {
                    setState(() => _poType = value!);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(context, true),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'PO Date *',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(_dateFormat.format(_poDate)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(context, false),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Expected Delivery Date *',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(_dateFormat.format(_expectedDeliveryDate)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLineItemsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.list, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Line Items',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _addLineItem,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Item'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._lineItems.asMap().entries.map((entry) {
            return _buildLineItemCard(entry.key, entry.value);
          }),
        ],
      ),
    );
  }

  Widget _buildLineItemCard(int index, LineItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Item ${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (_lineItems.length > 1)
                IconButton(
                  onPressed: () => _removeLineItem(index),
                  icon: const Icon(Icons.delete, color: AppColors.error),
                  iconSize: 20,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  initialValue: item.title,
                  decoration: const InputDecoration(
                    labelText: 'Item Name *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) => item.title = value,
                  validator: (value) =>
                      value?.isEmpty == true ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: TextFormField(
                  initialValue: item.hsnSacCode,
                  decoration: const InputDecoration(
                    labelText: 'HSN/SAC',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) => item.hsnSacCode = value,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: item.description,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            maxLines: 2,
            onChanged: (value) => item.description = value,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: item.quantity.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Qty *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  onChanged: (value) {
                    item.quantity = double.tryParse(value) ?? 0;
                    _calculateTotals();
                  },
                  validator: (value) =>
                      (double.tryParse(value ?? '') ?? 0) <= 0
                          ? 'Invalid'
                          : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: item.unitOfMeasure ?? 'Nos',
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Nos', child: Text('Nos')),
                    DropdownMenuItem(value: 'Kg', child: Text('Kg')),
                    DropdownMenuItem(value: 'Ltr', child: Text('Ltr')),
                    DropdownMenuItem(value: 'Mtr', child: Text('Mtr')),
                    DropdownMenuItem(value: 'Box', child: Text('Box')),
                    DropdownMenuItem(value: 'Pcs', child: Text('Pcs')),
                    DropdownMenuItem(value: 'Set', child: Text('Set')),
                  ],
                  onChanged: (value) => item.unitOfMeasure = value,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: item.rate.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Rate *',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixText: '₹ ',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  onChanged: (value) {
                    item.rate = double.tryParse(value) ?? 0;
                    _calculateTotals();
                  },
                  validator: (value) =>
                      (double.tryParse(value ?? '') ?? 0) <= 0
                          ? 'Invalid'
                          : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<double>(
                  value: item.gstPercentage,
                  decoration: const InputDecoration(
                    labelText: 'GST %',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: QuotationService.gstPercentages.map((rate) {
                    return DropdownMenuItem(
                      value: rate,
                      child: Text('${rate.toInt()}%'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    item.gstPercentage = value ?? 0;
                    _calculateTotals();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Total: ${_currencyFormat.format(item.total)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calculate, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Totals',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: _hasDiscount,
                onChanged: (value) {
                  setState(() => _hasDiscount = value ?? false);
                },
              ),
              const Text('Apply Discount'),
            ],
          ),
          if (_hasDiscount) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _discountType,
                    decoration: const InputDecoration(
                      labelText: 'Discount Type',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'percentage', child: Text('Percentage')),
                      DropdownMenuItem(value: 'amount', child: Text('Amount')),
                    ],
                    onChanged: (value) {
                      setState(() => _discountType = value!);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _discountValueController,
                    decoration: InputDecoration(
                      labelText: _discountType == 'percentage'
                          ? 'Discount %'
                          : 'Discount Amount',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      prefixText: _discountType == 'amount' ? '₹ ' : null,
                      suffixText: _discountType == 'percentage' ? '%' : null,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          _buildTotalRow('Subtotal', _subtotal),
          if (_isIntraState) ...[
            _buildTotalRow('CGST', _cgstTotal),
            _buildTotalRow('SGST', _sgstTotal),
          ] else
            _buildTotalRow('IGST', _igstTotal),
          if (_hasDiscount && _discountAmount > 0)
            _buildTotalRow('Discount', -_discountAmount, isNegative: true),
          const Divider(),
          _buildTotalRow('Grand Total', _grandTotal, isGrand: true),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount,
      {bool isGrand = false, bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isGrand ? 16 : 14,
              fontWeight: isGrand ? FontWeight.bold : FontWeight.w500,
              color: isNegative ? AppColors.success : AppColors.textPrimary,
            ),
          ),
          Text(
            _currencyFormat.format(amount.abs()),
            style: TextStyle(
              fontSize: isGrand ? 18 : 14,
              fontWeight: isGrand ? FontWeight.bold : FontWeight.w500,
              color: isNegative ? AppColors.success : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalDetailsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.notes, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Additional Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _deliveryAddressController,
            decoration: const InputDecoration(
              labelText: 'Delivery Address',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notes',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _termsController,
            decoration: const InputDecoration(
              labelText: 'Terms & Conditions',
              border: OutlineInputBorder(),
            ),
            maxLines: 5,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: _isSaving
              ? null
              : () => context.go('/dashboard/purchase-orders/view/${_po!.id}'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: _isSaving ? null : _savePurchaseOrder,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Update Purchase Order'),
        ),
      ],
    );
  }
}
