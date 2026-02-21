import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/themes.dart';
import '../../services/quotation_service.dart';
import '../../services/customer_service.dart';

class EditQuotationScreen extends StatefulWidget {
  final String quotationId;

  const EditQuotationScreen({super.key, required this.quotationId});

  @override
  State<EditQuotationScreen> createState() => _EditQuotationScreenState();
}

class _EditQuotationScreenState extends State<EditQuotationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quotationService = QuotationService();
  final _customerService = CustomerService();

  bool _isLoading = true;
  bool _isSaving = false;
  Quotation? _quotation;

  // Customer list
  List<Customer> _customers = [];
  Customer? _selectedCustomer;

  // Quotation Details
  String? _placeOfSupply;
  DateTime _quotationDate = DateTime.now();
  DateTime _validUntilDate = DateTime.now().add(const Duration(days: 30));
  String _quotationType = 'GST';

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
    final customers = await customersStream.first;

    // Load quotation
    final quotation = await _quotationService.getQuotationById(widget.quotationId);

    if (quotation != null) {
      setState(() {
        _quotation = quotation;
        _customers = customers;
        _selectedCustomer = customers.firstWhere(
          (c) => c.id == quotation.customerId,
          orElse: () => customers.isNotEmpty ? customers.first : Customer(),
        );
        _placeOfSupply = quotation.placeOfSupply;
        _quotationDate = quotation.quotationDate ?? DateTime.now();
        _validUntilDate = quotation.validUntilDate ?? DateTime.now().add(const Duration(days: 30));
        _quotationType = quotation.quotationType ?? 'GST';
        _lineItems = quotation.lineItems.isNotEmpty ? quotation.lineItems : [LineItem()];
        _hasDiscount = quotation.hasDiscount;
        _discountType = quotation.discountType ?? 'percentage';
        _discountValueController.text = quotation.discountValue.toString();
        _notesController.text = quotation.notes ?? '';
        _termsController.text = quotation.termsAndConditions ?? '';
        _previousTermsLength = _termsController.text.length;
      });
    }

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
    final companyState = _quotation?.companyDetails?['state'] as String?;
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

  Future<void> _selectDate(BuildContext context, bool isQuotationDate) async {
    final initialDate = isQuotationDate ? _quotationDate : _validUntilDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isQuotationDate) {
          _quotationDate = picked;
        } else {
          _validUntilDate = picked;
        }
      });
    }
  }

  Future<void> _saveQuotation() async {
    if (!_formKey.currentState!.validate()) return;
    if (_quotation == null) return;

    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a customer'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    _calculateTotals();

    _quotation!.customerId = _selectedCustomer!.id;
    _quotation!.customerName = _selectedCustomer!.customerName;
    _quotation!.placeOfSupply = _placeOfSupply;
    _quotation!.quotationDate = _quotationDate;
    _quotation!.validUntilDate = _validUntilDate;
    _quotation!.quotationType = _quotationType;
    _quotation!.lineItems = _lineItems;
    _quotation!.subtotal = _subtotal;
    _quotation!.hasDiscount = _hasDiscount;
    _quotation!.discountType = _discountType;
    _quotation!.discountValue = double.tryParse(_discountValueController.text) ?? 0;
    _quotation!.discountAmount = _discountAmount;
    _quotation!.grandTotal = _grandTotal;
    _quotation!.cgstTotal = _cgstTotal;
    _quotation!.sgstTotal = _sgstTotal;
    _quotation!.igstTotal = _igstTotal;
    _quotation!.taxTotal = _taxTotal;
    _quotation!.notes = _notesController.text.trim();
    _quotation!.termsAndConditions = _termsController.text.trim();
    _quotation!.customerDetails = {
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
    };

    final success = await _quotationService.updateQuotation(_quotation!);

    setState(() => _isSaving = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quotation updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/dashboard/quotations');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update quotation'),
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

    if (_quotation == null) {
      return Container(
        color: AppColors.background,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              const Text(
                'Quotation not found',
                style: TextStyle(fontSize: 18, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/dashboard/quotations'),
                child: const Text('Back to Quotations'),
              ),
            ],
          ),
        ),
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
                'Please add a customer first',
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
                onPressed: () => context.go('/dashboard/quotations'),
                child: const Text('Back to Quotations'),
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
                    onPressed: () => context.go('/dashboard/quotations'),
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
                          'Edit Quotation',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _quotation!.quotationNumber ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveQuotation,
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
                    label: Text(_isSaving ? 'Saving...' : 'Update Quotation'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Quotation Details Section
              _buildSection(
                title: 'Quotation Details',
                icon: Icons.description,
                child: _buildQuotationDetailsSection(),
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
                  onPressed: _isSaving ? null : _saveQuotation,
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
                  label: Text(_isSaving ? 'Saving...' : 'Update Quotation'),
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

  Widget _buildQuotationDetailsSection() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        SizedBox(
          width: 280,
          child: DropdownButtonFormField<Customer>(
            value: _selectedCustomer,
            decoration: InputDecoration(
              labelText: 'Customer *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: _customers.map((customer) {
              return DropdownMenuItem(value: customer, child: Text(customer.customerName ?? '-'));
            }).toList(),
            onChanged: (value) => setState(() => _selectedCustomer = value),
          ),
        ),
        SizedBox(
          width: 280,
          child: DropdownButtonFormField<String>(
            value: _placeOfSupply,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Place of Supply *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: QuotationService.indianStates.map((state) {
              return DropdownMenuItem(value: state, child: Text(state, overflow: TextOverflow.ellipsis));
            }).toList(),
            onChanged: (value) => setState(() => _placeOfSupply = value),
          ),
        ),
        SizedBox(
          width: 280,
          child: TextFormField(
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Quotation Date *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              suffixIcon: const Icon(Icons.calendar_today),
            ),
            controller: TextEditingController(text: _dateFormat.format(_quotationDate)),
            onTap: () => _selectDate(context, true),
          ),
        ),
        SizedBox(
          width: 280,
          child: TextFormField(
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Valid Until *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              suffixIcon: const Icon(Icons.calendar_today),
            ),
            controller: TextEditingController(text: _dateFormat.format(_validUntilDate)),
            onTap: () => _selectDate(context, false),
          ),
        ),
        SizedBox(
          width: 280,
          child: DropdownButtonFormField<String>(
            value: _quotationType,
            decoration: InputDecoration(
              labelText: 'Quotation Type *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: const [
              DropdownMenuItem(value: 'GST', child: Text('GST Quotation')),
              DropdownMenuItem(value: 'Non-GST', child: Text('Non-GST Quotation')),
            ],
            onChanged: (value) => setState(() => _quotationType = value ?? 'GST'),
          ),
        ),
      ],
    );
  }

  Widget _buildLineItemsSection() {
    return Column(
      children: [
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
        ...List.generate(_lineItems.length, (index) => _buildLineItemRow(index)),
        const SizedBox(height: 16),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 40, child: Padding(padding: const EdgeInsets.only(top: 12), child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.w500)))),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                TextFormField(
                  initialValue: item.title,
                  decoration: const InputDecoration(labelText: 'Title', isDense: true, border: OutlineInputBorder()),
                  onChanged: (value) => item.title = value,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: item.description,
                  decoration: const InputDecoration(labelText: 'Description', isDense: true, border: OutlineInputBorder()),
                  maxLines: 2,
                  onChanged: (value) => item.description = value,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: TextFormField(
              initialValue: item.hsnSacCode,
              decoration: const InputDecoration(labelText: 'HSN/SAC', isDense: true, border: OutlineInputBorder()),
              onChanged: (value) => item.hsnSacCode = value,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: TextFormField(
              initialValue: item.quantity.toString(),
              decoration: const InputDecoration(labelText: 'Qty', isDense: true, border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              onChanged: (value) {
                item.quantity = double.tryParse(value) ?? 0;
                _calculateTotals();
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: TextFormField(
              initialValue: item.rate.toString(),
              decoration: const InputDecoration(labelText: 'Rate', isDense: true, border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              onChanged: (value) {
                item.rate = double.tryParse(value) ?? 0;
                _calculateTotals();
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: DropdownButtonFormField<double>(
              value: item.gstPercentage,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'GST', isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
              items: QuotationService.gstPercentages.map((gst) => DropdownMenuItem(value: gst, child: Text('${gst.toInt()}%'))).toList(),
              onChanged: _quotationType == 'Non-GST' ? null : (value) {
                item.gstPercentage = value ?? 0;
                _calculateTotals();
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_currencyFormat.format(item.total), style: const TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right),
            ),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              onPressed: _lineItems.length > 1 ? () => _removeLineItem(index) : null,
              icon: Icon(Icons.delete_outline, color: _lineItems.length > 1 ? AppColors.error : AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsSection() {
    return Column(
      children: [
        _buildTotalRow('Subtotal', _currencyFormat.format(_subtotal)),
        const Divider(),
        Row(
          children: [
            Checkbox(value: _hasDiscount, onChanged: (value) => setState(() => _hasDiscount = value ?? false)),
            const Text('Apply Discount'),
          ],
        ),
        if (_hasDiscount) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<String>(
                  value: _discountType,
                  decoration: const InputDecoration(labelText: 'Discount Type', isDense: true, border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'percentage', child: Text('Percentage')),
                    DropdownMenuItem(value: 'amount', child: Text('Amount')),
                  ],
                  onChanged: (value) => setState(() => _discountType = value ?? 'percentage'),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 150,
                child: TextFormField(
                  controller: _discountValueController,
                  decoration: InputDecoration(labelText: _discountType == 'percentage' ? 'Discount %' : 'Discount Amount', isDense: true, border: const OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                  onChanged: (value) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTotalRow('Discount ${_discountType == 'percentage' ? '(${_discountValueController.text}%)' : ''}', '- ${_currencyFormat.format(_discountAmount)}', isDiscount: true),
          const Divider(),
        ],
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
          Text(label, style: TextStyle(fontSize: isGrandTotal ? 18 : 14, fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.w500, color: isDiscount ? AppColors.error : AppColors.textPrimary)),
          Text(value, style: TextStyle(fontSize: isGrandTotal ? 18 : 14, fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.w500, color: isDiscount ? AppColors.error : AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildAdditionalDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _notesController,
          decoration: InputDecoration(labelText: 'Notes', hintText: 'Add any additional notes...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        const Text('Terms and Conditions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        const Text('Press Enter to add a new numbered item', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _termsController,
          focusNode: _termsFocusNode,
          decoration: InputDecoration(
            hintText: 'Click here to start adding terms...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
