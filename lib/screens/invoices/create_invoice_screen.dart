import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/themes.dart';
import '../../services/invoice_service.dart';
import '../../services/customer_service.dart';
import '../../services/profile_service.dart';
import '../../services/auth_service.dart';

class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceService = InvoiceService();
  final _customerService = CustomerService();
  final _profileService = ProfileService();
  final _authService = AuthService();

  bool _isLoading = true;
  bool _isSaving = false;

  // Customer list
  List<Customer> _customers = [];
  Customer? _selectedCustomer;

  // Invoice Details
  String? _placeOfSupply;
  DateTime _invoiceDate = DateTime.now();
  int _creditPeriodDays = 30;
  String _invoiceType = 'GST';

  // Calculate due date from invoice date and credit period
  DateTime get _dueDate => _invoiceDate.add(Duration(days: _creditPeriodDays));

  // Line Items
  List<LineItem> _lineItems = [LineItem()];

  // Discount
  bool _hasDiscount = false;
  String _discountType = 'percentage';
  final _discountValueController = TextEditingController(text: '0');

  // Additional Details
  final _notesController = TextEditingController();
  final _termsController = TextEditingController();
  final _termsFocusNode = FocusNode();
  int _previousTermsLength = 0;

  // Company and user details
  CompanyProfile? _companyProfile;
  Map<String, String?>? _userInfo;

  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _termsFocusNode.addListener(_onTermsFocusChange);
    _loadData();
  }

  void _onTermsFocusChange() {
    if (_termsFocusNode.hasFocus && _termsController.text.isEmpty) {
      _termsController.text = '1. ';
      _termsController.selection = TextSelection.collapsed(offset: _termsController.text.length);
    }
  }

  @override
  void dispose() {
    _termsFocusNode.removeListener(_onTermsFocusChange);
    _termsFocusNode.dispose();
    _discountValueController.dispose();
    _notesController.dispose();
    _termsController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Load customers
    final customersStream = _customerService.getCustomers();
    customersStream.first.then((customers) {
      setState(() {
        _customers = customers;
      });
    });

    // Load company profile
    _companyProfile = await _profileService.getCompanyProfile();
    _userInfo = await _authService.getCurrentUserInfo();

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

  // Check if transaction is intra-state (same state = CGST+SGST) or inter-state (IGST)
  bool get _isIntraState {
    final companyState = _companyProfile?.state;
    final customerState = _selectedCustomer?.state;
    return companyState != null && customerState != null && companyState == customerState;
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

  Future<void> _selectInvoiceDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _invoiceDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _invoiceDate = picked;
      });
    }
  }

  Future<void> _saveInvoice() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a customer'),
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

    // Calculate all totals
    _calculateTotals();

    final invoice = Invoice(
      customerId: _selectedCustomer!.id,
      customerName: _selectedCustomer!.customerName,
      placeOfSupply: _placeOfSupply,
      invoiceDate: _invoiceDate,
      creditPeriodDays: _creditPeriodDays,
      invoiceType: _invoiceType,
      lineItems: _lineItems,
      subtotal: _subtotal,
      hasDiscount: _hasDiscount,
      discountType: _discountType,
      discountValue: double.tryParse(_discountValueController.text) ?? 0,
      discountAmount: _discountAmount,
      grandTotal: _grandTotal,
      cgstTotal: _cgstTotal,
      sgstTotal: _sgstTotal,
      igstTotal: _igstTotal,
      taxTotal: _taxTotal,
      notes: _notesController.text.trim(),
      termsAndConditions: _termsController.text.trim(),
      companyDetails: _companyProfile?.toMap(),
      bankDetails: {
        'bankAccountHolderName': _companyProfile?.bankAccountHolderName,
        'bankName': _companyProfile?.bankName,
        'accountNumber': _companyProfile?.accountNumber,
        'ifscCode': _companyProfile?.ifscCode,
        'branchName': _companyProfile?.branchName,
        'accountType': _companyProfile?.accountType,
      },
      userDetails: {
        'name': _userInfo?['name'],
        'email': _userInfo?['email'],
        'phone': _userInfo?['phone'],
        'companyName': _companyProfile?.companyLegalName,
        'address': '${_companyProfile?.addressLine1 ?? ''}, ${_companyProfile?.addressLine2 ?? ''}, ${_companyProfile?.city ?? ''}, ${_companyProfile?.state ?? ''} - ${_companyProfile?.pinCode ?? ''}',
      },
      customerDetails: {
        'customerName': _selectedCustomer!.customerName,
        'customerType': _selectedCustomer!.customerType,
        'contactPersonName': _selectedCustomer!.contactPersonName,
        'gstNumber': _selectedCustomer!.gstNumber,
        'panNumber': _selectedCustomer!.panNumber,
        'email': _selectedCustomer!.email,
        'phoneNumber': _selectedCustomer!.phoneNumber,
        'addressLine1': _selectedCustomer!.addressLine1,
        'addressLine2': _selectedCustomer!.addressLine2,
        'city': _selectedCustomer!.city,
        'state': _selectedCustomer!.state,
        'pinCode': _selectedCustomer!.pinCode,
        'country': _selectedCustomer!.country,
      },
    );

    final invoiceId = await _invoiceService.addInvoice(invoice);

    setState(() => _isSaving = false);

    if (mounted) {
      if (invoiceId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice created successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/dashboard/invoices');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create invoice'),
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

    // Show message if no customers exist
    if (_customers.isEmpty) {
      return Container(
        color: AppColors.background,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 64,
                color: AppColors.textSecondary.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Customers Found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please add a customer first before creating an invoice',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.go('/dashboard/customers/add'),
                icon: const Icon(Icons.add),
                label: const Text('Add Customer'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/dashboard/invoices'),
                child: const Text('Back to Invoices'),
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
                    onPressed: () => context.go('/dashboard/invoices'),
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
                          'Create Invoice',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Create a new invoice for your customer',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveInvoice,
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
                    label: Text(_isSaving ? 'Saving...' : 'Save Invoice'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Invoice Details Section
              _buildSection(
                title: 'Invoice Details',
                icon: Icons.receipt,
                child: _buildInvoiceDetailsSection(),
              ),
              const SizedBox(height: 24),

              // Line Items Section
              _buildSection(
                title: 'Line Items',
                icon: Icons.list_alt,
                child: _buildLineItemsSection(),
              ),
              const SizedBox(height: 24),

              // Totals Section
              _buildSection(
                title: 'Totals',
                icon: Icons.calculate,
                child: _buildTotalsSection(),
              ),
              const SizedBox(height: 24),

              // Additional Details Section
              _buildSection(
                title: 'Additional Details',
                icon: Icons.note_add,
                child: _buildAdditionalDetailsSection(),
              ),
              const SizedBox(height: 32),

              // Save button at bottom
              Center(
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveInvoice,
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
                  label: Text(_isSaving ? 'Saving...' : 'Save Invoice'),
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

  Widget _buildInvoiceDetailsSection() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        // Customer Dropdown
        SizedBox(
          width: 280,
          child: DropdownButtonFormField<Customer>(
            value: _selectedCustomer,
            decoration: InputDecoration(
              labelText: 'Customer *',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            items: _customers.map((customer) {
              return DropdownMenuItem(
                value: customer,
                child: Text(customer.customerName ?? '-'),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedCustomer = value),
            validator: (value) => value == null ? 'Please select a customer' : null,
          ),
        ),

        // Place of Supply
        SizedBox(
          width: 280,
          child: DropdownButtonFormField<String>(
            value: _placeOfSupply,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Place of Supply *',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            items: InvoiceService.indianStates.map((state) {
              return DropdownMenuItem(
                value: state,
                child: Text(state, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (value) => setState(() => _placeOfSupply = value),
            validator: (value) => value == null ? 'Please select place of supply' : null,
          ),
        ),

        // Invoice Date
        SizedBox(
          width: 280,
          child: TextFormField(
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Invoice Date *',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              suffixIcon: const Icon(Icons.calendar_today),
            ),
            controller: TextEditingController(text: _dateFormat.format(_invoiceDate)),
            onTap: () => _selectInvoiceDate(context),
          ),
        ),

        // Credit Period
        SizedBox(
          width: 280,
          child: DropdownButtonFormField<int>(
            value: _creditPeriodDays,
            decoration: InputDecoration(
              labelText: 'Credit Period *',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              helperText: 'Due: ${_dateFormat.format(_dueDate)}',
            ),
            items: CreditPeriod.options.map((days) {
              return DropdownMenuItem(
                value: days,
                child: Text(CreditPeriod.getLabel(days)),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _creditPeriodDays = value ?? 30);
            },
          ),
        ),

        // Invoice Type
        SizedBox(
          width: 280,
          child: DropdownButtonFormField<String>(
            value: _invoiceType,
            decoration: InputDecoration(
              labelText: 'Invoice Type *',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'GST', child: Text('GST Invoice')),
              DropdownMenuItem(value: 'Non-GST', child: Text('Non-GST Invoice')),
            ],
            onChanged: (value) => setState(() => _invoiceType = value ?? 'GST'),
          ),
        ),
      ],
    );
  }

  Widget _buildLineItemsSection() {
    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              SizedBox(width: 40, child: Text('#', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
              Expanded(flex: 3, child: Text('Title / Description', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
              SizedBox(width: 100, child: Text('HSN/SAC', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
              SizedBox(width: 70, child: Text('Qty', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.center)),
              SizedBox(width: 100, child: Text('Rate', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.right)),
              SizedBox(width: 90, child: Text('GST %', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.center)),
              SizedBox(width: 120, child: Text('Total', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.right)),
              SizedBox(width: 40),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Line Items
        ...List.generate(_lineItems.length, (index) => _buildLineItemRow(index)),

        const SizedBox(height: 16),

        // Add Line Item Button
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addLineItem,
            icon: const Icon(Icons.add),
            label: const Text('Add Line Item'),
          ),
        ),
      ],
    );
  }

  Widget _buildLineItemRow(int index) {
    final item = _lineItems[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Serial Number
              SizedBox(
                width: 40,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ),

              // Title and Description
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    TextFormField(
                      initialValue: item.title,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => item.title = value,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: item.description,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      onChanged: (value) => item.description = value,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // HSN/SAC
              SizedBox(
                width: 100,
                child: TextFormField(
                  initialValue: item.hsnSacCode,
                  decoration: const InputDecoration(
                    labelText: 'HSN/SAC',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => item.hsnSacCode = value,
                ),
              ),
              const SizedBox(width: 8),

              // Quantity
              SizedBox(
                width: 70,
                child: TextFormField(
                  initialValue: item.quantity.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Qty',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                  onChanged: (value) {
                    item.quantity = double.tryParse(value) ?? 0;
                    _calculateTotals();
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Rate
              SizedBox(
                width: 100,
                child: TextFormField(
                  initialValue: item.rate.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Rate',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                  onChanged: (value) {
                    item.rate = double.tryParse(value) ?? 0;
                    _calculateTotals();
                  },
                ),
              ),
              const SizedBox(width: 8),

              // GST %
              SizedBox(
                width: 90,
                child: DropdownButtonFormField<double>(
                  value: item.gstPercentage,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'GST',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  items: InvoiceService.gstPercentages.map((gst) {
                    return DropdownMenuItem(
                      value: gst,
                      child: Text('${gst.toInt()}%'),
                    );
                  }).toList(),
                  onChanged: _invoiceType == 'Non-GST'
                      ? null
                      : (value) {
                          item.gstPercentage = value ?? 0;
                          _calculateTotals();
                        },
                ),
              ),
              const SizedBox(width: 8),

              // Total
              SizedBox(
                width: 120,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _currencyFormat.format(item.total),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.right,
                  ),
                ),
              ),

              // Delete Button
              SizedBox(
                width: 40,
                child: IconButton(
                  onPressed: _lineItems.length > 1 ? () => _removeLineItem(index) : null,
                  icon: Icon(
                    Icons.delete_outline,
                    color: _lineItems.length > 1 ? AppColors.error : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsSection() {
    return Column(
      children: [
        // Subtotal
        _buildTotalRow('Subtotal', _currencyFormat.format(_subtotal)),
        const Divider(),

        // Discount Toggle
        Row(
          children: [
            Checkbox(
              value: _hasDiscount,
              onChanged: (value) => setState(() => _hasDiscount = value ?? false),
            ),
            const Text('Apply Discount'),
          ],
        ),

        // Discount Options
        if (_hasDiscount) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              // Discount Type
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<String>(
                  value: _discountType,
                  decoration: const InputDecoration(
                    labelText: 'Discount Type',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'percentage', child: Text('Percentage')),
                    DropdownMenuItem(value: 'amount', child: Text('Amount')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _discountType = value ?? 'percentage';
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),

              // Discount Value
              SizedBox(
                width: 150,
                child: TextFormField(
                  controller: _discountValueController,
                  decoration: InputDecoration(
                    labelText: _discountType == 'percentage' ? 'Discount %' : 'Discount Amount',
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                  onChanged: (value) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTotalRow(
            'Discount ${_discountType == 'percentage' ? '(${_discountValueController.text}%)' : ''}',
            '- ${_currencyFormat.format(_discountAmount)}',
            isDiscount: true,
          ),
          const Divider(),
        ],

        // Grand Total
        _buildTotalRow('Grand Total', _currencyFormat.format(_grandTotal), isGrandTotal: true),
      ],
    );
  }

  Widget _buildTotalRow(String label, String value, {bool isGrandTotal = false, bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isGrandTotal ? 18 : 14,
              fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.w500,
              color: isDiscount ? AppColors.error : AppColors.textPrimary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isGrandTotal ? 18 : 14,
              fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.w500,
              color: isDiscount ? AppColors.error : AppColors.textPrimary,
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
        // Notes
        TextFormField(
          controller: _notesController,
          decoration: InputDecoration(
            labelText: 'Notes',
            hintText: 'Add any additional notes...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),

        // Terms and Conditions
        const Text(
          'Terms and Conditions',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Press Enter to add a new numbered item',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _termsController,
          focusNode: _termsFocusNode,
          decoration: InputDecoration(
            hintText: 'Click here to start adding terms...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          maxLines: 6,
          onChanged: (value) {
            // Only auto-number when Enter is pressed (text length increased and ends with newline)
            final isTextAdded = value.length > _previousTermsLength;
            _previousTermsLength = value.length;

            if (isTextAdded && value.endsWith('\n')) {
              // Find the highest number used so far
              final lines = value.split('\n');
              int maxNumber = 0;
              final numberRegex = RegExp(r'^(\d+)\.');
              for (final line in lines) {
                final match = numberRegex.firstMatch(line.trim());
                if (match != null) {
                  final num = int.tryParse(match.group(1)!) ?? 0;
                  if (num > maxNumber) maxNumber = num;
                }
              }
              // Add next number
              final nextNumber = maxNumber + 1;
              final newText = '$value$nextNumber. ';
              _previousTermsLength = newText.length;
              _termsController.value = TextEditingValue(
                text: newText,
                selection: TextSelection.collapsed(offset: newText.length),
              );
            }
          },
        ),
      ],
    );
  }
}
