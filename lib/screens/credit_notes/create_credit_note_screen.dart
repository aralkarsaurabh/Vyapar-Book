import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/themes.dart';
import '../../services/credit_note_service.dart';
import '../../services/invoice_service.dart';
import '../../services/profile_service.dart';

class CreateCreditNoteScreen extends StatefulWidget {
  final String? invoiceId; // Pre-selected invoice (optional)

  const CreateCreditNoteScreen({super.key, this.invoiceId});

  @override
  State<CreateCreditNoteScreen> createState() => _CreateCreditNoteScreenState();
}

class _CreateCreditNoteScreenState extends State<CreateCreditNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _creditNoteService = CreditNoteService();
  final _profileService = ProfileService();
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  final _dateFormat = DateFormat('dd MMM yyyy');

  bool _isLoading = true;
  bool _isSaving = false;
  List<Invoice> _invoices = [];
  Invoice? _selectedInvoice;
  DateTime _creditNoteDate = DateTime.now();
  String _selectedReason = CreditNoteReason.goodsReturned;
  final _reasonNotesController = TextEditingController();
  final _notesController = TextEditingController();
  late final TextEditingController _dateController;

  // Line items with selection and quantity adjustment
  List<_SelectableLineItem> _selectableItems = [];

  // Calculated totals
  double _subtotal = 0;
  double _cgstTotal = 0;
  double _sgstTotal = 0;
  double _igstTotal = 0;
  double _grandTotal = 0;

  // Company details for GST calculation
  Map<String, dynamic>? _companyDetails;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(text: _dateFormat.format(_creditNoteDate));
    _loadData();
  }

  @override
  void dispose() {
    _reasonNotesController.dispose();
    _notesController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load company profile
      final profile = await _profileService.getCompanyProfile();
      if (profile != null) {
        _companyDetails = {
          'companyName': profile.companyLegalName,
          'companyLegalName': profile.companyLegalName,
          'gstNumber': profile.gstin,
          'address': profile.addressLine1,
          'city': profile.city,
          'state': profile.state,
          'pincode': profile.pinCode,
        };
      }

      // Load invoices available for credit note
      final invoices = await _creditNoteService.getInvoicesForCreditNote();
      _invoices = invoices;

      // If invoice ID is provided, pre-select it
      if (widget.invoiceId != null) {
        _selectedInvoice = invoices.firstWhere(
          (i) => i.id == widget.invoiceId,
          orElse: () => invoices.first,
        );
        if (_selectedInvoice != null) {
          await _onInvoiceSelected(_selectedInvoice!);
        }
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onInvoiceSelected(Invoice invoice) async {
    setState(() => _isLoading = true);

    try {
      // Create selectable line items
      _selectableItems = invoice.lineItems.map((item) {
        return _SelectableLineItem(
          original: item,
          selected: false,
          quantity: item.quantity,
          maxQuantity: item.quantity,
        );
      }).toList();

      _selectedInvoice = invoice;
      _calculateTotals();
    } catch (e) {
      debugPrint('Error selecting invoice: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _calculateTotals() {
    final isIntraState = _companyDetails?['state'] != null &&
        _selectedInvoice != null &&
        _companyDetails!['state'] == (_selectedInvoice!.customerDetails?['state'] ?? _selectedInvoice!.placeOfSupply);

    double subtotal = 0;
    double cgst = 0;
    double sgst = 0;
    double igst = 0;

    for (final item in _selectableItems) {
      if (item.selected && item.quantity > 0) {
        final taxableAmount = item.quantity * item.original.rate;
        subtotal += taxableAmount;

        final gstAmount = taxableAmount * (item.original.gstPercentage / 100);
        if (isIntraState) {
          cgst += gstAmount / 2;
          sgst += gstAmount / 2;
        } else {
          igst += gstAmount;
        }
      }
    }

    setState(() {
      _subtotal = subtotal;
      _cgstTotal = cgst;
      _sgstTotal = sgst;
      _igstTotal = igst;
      _grandTotal = subtotal + cgst + sgst + igst;
    });
  }

  void _toggleItemSelection(int index, bool? value) {
    setState(() {
      _selectableItems[index].selected = value ?? false;
      _calculateTotals();
    });
  }

  void _updateItemQuantity(int index, double quantity) {
    setState(() {
      _selectableItems[index].quantity = quantity;
      _calculateTotals();
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _creditNoteDate,
      firstDate: _selectedInvoice?.invoiceDate ?? DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _creditNoteDate = picked;
        _dateController.text = _dateFormat.format(picked);
      });
    }
  }

  Future<void> _saveCreditNote() async {
    if (_selectedInvoice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an invoice'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final selectedItems = _selectableItems.where((item) => item.selected && item.quantity > 0).toList();
    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one item'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final isIntraState = _companyDetails?['state'] != null &&
          _companyDetails!['state'] == (_selectedInvoice!.customerDetails?['state'] ?? _selectedInvoice!.placeOfSupply);

      // Create line items for credit note
      final lineItems = selectedItems.map((item) {
        final li = LineItem(
          title: item.original.title,
          description: item.original.description,
          hsnSacCode: item.original.hsnSacCode,
          quantity: item.quantity,
          rate: item.original.rate,
          unitOfMeasure: item.original.unitOfMeasure,
          gstPercentage: item.original.gstPercentage,
        );
        li.calculateTotal(isIntraState: isIntraState);
        return li;
      }).toList();

      final creditNote = CreditNote(
        againstInvoiceId: _selectedInvoice!.id,
        againstInvoiceNumber: _selectedInvoice!.invoiceNumber,
        customerId: _selectedInvoice!.customerId,
        customerName: _selectedInvoice!.customerName,
        placeOfSupply: _selectedInvoice!.placeOfSupply,
        creditNoteDate: _creditNoteDate,
        reason: _selectedReason,
        reasonNotes: _selectedReason == CreditNoteReason.other ? _reasonNotesController.text : null,
        lineItems: lineItems,
        subtotal: _subtotal,
        cgstTotal: _cgstTotal,
        sgstTotal: _sgstTotal,
        igstTotal: _igstTotal,
        taxTotal: _cgstTotal + _sgstTotal + _igstTotal,
        grandTotal: _grandTotal,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        companyDetails: _companyDetails,
        customerDetails: _selectedInvoice!.customerDetails,
        bankDetails: _selectedInvoice!.bankDetails,
        userDetails: _selectedInvoice!.userDetails,
      );

      final creditNoteId = await _creditNoteService.addCreditNote(creditNote);

      if (mounted) {
        if (creditNoteId != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Credit note created successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          context.go('/dashboard/credit-notes/view/$creditNoteId');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to create credit note'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error creating credit note: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                IconButton(
                  onPressed: () => context.go('/dashboard/credit-notes'),
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back to Credit Notes',
                ),
                const SizedBox(width: 8),
                const Text(
                  'Create Credit Note',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _invoices.isEmpty
                      ? _buildNoInvoicesMessage()
                      : _buildForm(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoInvoicesMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No invoices available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create an invoice first to issue a credit note',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column - Form
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Invoice Selection
                    _buildSectionTitle('Select Invoice'),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Invoice>(
                      value: _selectedInvoice,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Invoice',
                        hintText: 'Select an invoice',
                      ),
                      items: _invoices.map((invoice) {
                        return DropdownMenuItem(
                          value: invoice,
                          child: Text(
                            '${invoice.invoiceNumber ?? '-'} - ${invoice.customerName ?? 'Unknown'} (${_currencyFormat.format(invoice.grandTotal)})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (invoice) {
                        if (invoice != null) {
                          _onInvoiceSelected(invoice);
                        }
                      },
                      validator: (value) {
                        if (value == null) return 'Please select an invoice';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Credit Note Details
                    _buildSectionTitle('Credit Note Details'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _selectDate,
                            child: AbsorbPointer(
                              child: TextFormField(
                                controller: _dateController,
                                decoration: const InputDecoration(
                                  labelText: 'Credit Note Date',
                                  suffixIcon: Icon(Icons.calendar_today),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedReason,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Reason',
                            ),
                            items: CreditNoteReason.options.map((reason) {
                              return DropdownMenuItem(
                                value: reason,
                                child: Text(reason),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedReason = value ?? CreditNoteReason.goodsReturned);
                            },
                          ),
                        ),
                      ],
                    ),
                    if (_selectedReason == CreditNoteReason.other) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _reasonNotesController,
                        decoration: const InputDecoration(
                          labelText: 'Reason Details',
                          hintText: 'Specify the reason for credit note',
                        ),
                        maxLines: 2,
                        validator: (value) {
                          if (_selectedReason == CreditNoteReason.other && (value == null || value.isEmpty)) {
                            return 'Please specify the reason';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Line Items
                    if (_selectedInvoice != null) ...[
                      _buildSectionTitle('Select Items to Credit'),
                      const SizedBox(height: 12),
                      _buildLineItemsTable(),
                      const SizedBox(height: 24),
                    ],

                    // Notes
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (Optional)',
                        hintText: 'Any additional notes',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveCreditNote,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Create Credit Note'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 24),

          // Right column - Summary
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Credit Note Summary'),
                  const SizedBox(height: 16),

                  if (_selectedInvoice != null) ...[
                    _buildSummaryRow('Original Invoice', _selectedInvoice!.invoiceNumber ?? '-'),
                    const SizedBox(height: 8),
                    _buildSummaryRow('Customer', _selectedInvoice!.customerName ?? '-'),
                    const SizedBox(height: 8),
                    _buildSummaryRow('Invoice Amount', _currencyFormat.format(_selectedInvoice!.grandTotal)),
                    const Divider(height: 32),
                  ],

                  _buildSummaryRow('Subtotal', _currencyFormat.format(_subtotal)),
                  const SizedBox(height: 8),
                  if (_cgstTotal > 0)
                    _buildSummaryRow('CGST', _currencyFormat.format(_cgstTotal)),
                  if (_sgstTotal > 0)
                    _buildSummaryRow('SGST', _currencyFormat.format(_sgstTotal)),
                  if (_igstTotal > 0)
                    _buildSummaryRow('IGST', _currencyFormat.format(_igstTotal)),
                  const Divider(height: 32),
                  _buildSummaryRow(
                    'Credit Amount',
                    _currencyFormat.format(_grandTotal),
                    isTotal: true,
                  ),

                  if (_selectedInvoice != null && _grandTotal > 0) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.info.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: AppColors.info, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This will reduce ${_selectedInvoice!.customerName}\'s outstanding by ${_currencyFormat.format(_grandTotal)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.info,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
            color: isTotal ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: isTotal ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildLineItemsTable() {
    if (_selectableItems.isEmpty) {
      return const Text('No items in selected invoice');
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: const Row(
              children: [
                SizedBox(width: 40), // Checkbox
                Expanded(flex: 3, child: Text('Item', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                Expanded(flex: 1, child: Text('Rate', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13), textAlign: TextAlign.right)),
                Expanded(flex: 1, child: Text('Max Qty', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13), textAlign: TextAlign.center)),
                Expanded(flex: 1, child: Text('Credit Qty', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13), textAlign: TextAlign.center)),
                Expanded(flex: 1, child: Text('Amount', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13), textAlign: TextAlign.right)),
              ],
            ),
          ),
          // Items
          ...List.generate(_selectableItems.length, (index) {
            final item = _selectableItems[index];
            final amount = item.selected ? item.quantity * item.original.rate : 0.0;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border.withOpacity(0.5))),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Checkbox(
                      value: item.selected,
                      onChanged: (value) => _toggleItemSelection(index, value),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.original.title ?? 'Item',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        if (item.original.description != null && item.original.description!.isNotEmpty)
                          Text(
                            item.original.description!,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      _currencyFormat.format(item.original.rate),
                      style: const TextStyle(fontSize: 13),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      '${item.maxQuantity}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: item.selected
                        ? Center(
                            child: SizedBox(
                              width: 60,
                              child: TextFormField(
                                initialValue: '${item.quantity}',
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                ),
                                onChanged: (value) {
                                  final qty = double.tryParse(value) ?? 0;
                                  final clampedQty = qty.clamp(0.0, item.maxQuantity);
                                  _updateItemQuantity(index, clampedQty);
                                },
                              ),
                            ),
                          )
                        : const Text('-', textAlign: TextAlign.center),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      item.selected ? _currencyFormat.format(amount) : '-',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: item.selected ? FontWeight.w500 : FontWeight.normal,
                        color: item.selected ? AppColors.textPrimary : AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SelectableLineItem {
  final LineItem original;
  bool selected;
  double quantity;
  final double maxQuantity;

  _SelectableLineItem({
    required this.original,
    required this.selected,
    required this.quantity,
    required this.maxQuantity,
  });
}
