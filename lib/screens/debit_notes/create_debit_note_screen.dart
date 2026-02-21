import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/themes.dart';
import '../../services/debit_note_service.dart';
import '../../services/invoice_service.dart';
import '../../services/shared_document_service.dart';
import '../../services/profile_service.dart';
import '../../services/vendor_service.dart';

class CreateDebitNoteScreen extends StatefulWidget {
  final String? billId; // Pre-selected bill (optional)

  const CreateDebitNoteScreen({super.key, this.billId});

  @override
  State<CreateDebitNoteScreen> createState() => _CreateDebitNoteScreenState();
}

class _CreateDebitNoteScreenState extends State<CreateDebitNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _debitNoteService = DebitNoteService();
  final _profileService = ProfileService();
  final _vendorService = VendorService();
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  final _dateFormat = DateFormat('dd MMM yyyy');

  bool _isLoading = true;
  bool _isSaving = false;
  List<SharedDocument> _bills = [];
  SharedDocument? _selectedBill;
  Invoice? _reconstructedInvoice;
  Vendor? _vendor;
  DateTime _debitNoteDate = DateTime.now();
  String _selectedReason = DebitNoteReason.goodsDamaged;
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
    _dateController = TextEditingController(text: _dateFormat.format(_debitNoteDate));
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

      // Load recorded bills available for debit note
      final bills = await _debitNoteService.getRecordedBillsForDebitNote();
      _bills = bills;

      // If bill ID is provided, pre-select it
      if (widget.billId != null) {
        _selectedBill = bills.firstWhere(
          (b) => b.id == widget.billId,
          orElse: () => bills.first,
        );
        if (_selectedBill != null) {
          await _onBillSelected(_selectedBill!);
        }
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onBillSelected(SharedDocument bill) async {
    setState(() => _isLoading = true);

    try {
      // Reconstruct invoice from snapshot
      final invoice = Invoice.fromMap(bill.documentSnapshot, bill.documentId);
      _reconstructedInvoice = invoice;

      // Try to find vendor by sender's Vyapar ID
      final vendors = await _vendorService.getVendorsOnce();
      _vendor = vendors.firstWhere(
        (v) => v.linkedVyaparId == bill.senderVyaparId,
        orElse: () => Vendor(
          vendorName: bill.senderCompanyName,
          linkedVyaparId: bill.senderVyaparId,
        ),
      );

      // Create selectable line items
      _selectableItems = invoice.lineItems.map((item) {
        return _SelectableLineItem(
          original: item,
          selected: false,
          quantity: item.quantity,
          maxQuantity: item.quantity,
        );
      }).toList();

      _selectedBill = bill;
      _calculateTotals();
    } catch (e) {
      debugPrint('Error selecting bill: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _calculateTotals() {
    // Use vendor's state from the bill for GST calculation
    final vendorState = _reconstructedInvoice?.companyDetails?['state'] ??
                       _selectedBill?.documentSnapshot['companyDetails']?['state'];
    final companyState = _companyDetails?['state'];
    final isIntraState = companyState != null &&
                        vendorState != null &&
                        companyState == vendorState;

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
      initialDate: _debitNoteDate,
      firstDate: _selectedBill?.documentDate ?? DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _debitNoteDate = picked;
        _dateController.text = _dateFormat.format(picked);
      });
    }
  }

  Future<void> _saveDebitNote() async {
    if (_selectedBill == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a bill'),
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
      final vendorState = _reconstructedInvoice?.companyDetails?['state'] ??
                         _selectedBill?.documentSnapshot['companyDetails']?['state'];
      final companyState = _companyDetails?['state'];
      final isIntraState = companyState != null &&
                          vendorState != null &&
                          companyState == vendorState;

      // Create line items for debit note
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

      // Get vendor details
      final vendorDetails = _reconstructedInvoice?.companyDetails ?? {
        'companyName': _selectedBill!.senderCompanyName,
        'state': vendorState,
      };

      final debitNote = DebitNote(
        againstBillId: _selectedBill!.id,
        againstBillNumber: _reconstructedInvoice?.invoiceNumber ?? _selectedBill!.documentNumber,
        vendorId: _vendor?.id,
        vendorName: _selectedBill!.senderCompanyName ?? _vendor?.vendorName,
        vendorVyaparId: _selectedBill!.senderVyaparId,
        placeOfSupply: _reconstructedInvoice?.placeOfSupply,
        debitNoteDate: _debitNoteDate,
        reason: _selectedReason,
        reasonNotes: _selectedReason == DebitNoteReason.other ? _reasonNotesController.text : null,
        lineItems: lineItems,
        subtotal: _subtotal,
        cgstTotal: _cgstTotal,
        sgstTotal: _sgstTotal,
        igstTotal: _igstTotal,
        taxTotal: _cgstTotal + _sgstTotal + _igstTotal,
        grandTotal: _grandTotal,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        companyDetails: _companyDetails,
        vendorDetails: vendorDetails,
        bankDetails: _reconstructedInvoice?.bankDetails,
        userDetails: _reconstructedInvoice?.userDetails,
      );

      final debitNoteId = await _debitNoteService.addDebitNote(debitNote);

      if (mounted) {
        if (debitNoteId != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Debit note created successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          context.go('/dashboard/debit-notes/view/$debitNoteId');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to create debit note'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error creating debit note: $e');
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
                  onPressed: () => context.go('/dashboard/debit-notes'),
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back to Debit Notes',
                ),
                const SizedBox(width: 8),
                const Text(
                  'Create Debit Note',
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
                  : _bills.isEmpty
                      ? _buildNoBillsMessage()
                      : _buildForm(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoBillsMessage() {
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
            'No recorded bills available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Record a received invoice as a bill first to issue a debit note',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.go('/dashboard/invoices'),
            icon: const Icon(Icons.receipt),
            label: const Text('Go to Invoices'),
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
                    // Bill Selection
                    _buildSectionTitle('Select Bill (Received Invoice)'),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<SharedDocument>(
                      value: _selectedBill,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Bill',
                        hintText: 'Select a recorded bill',
                      ),
                      items: _bills.map((bill) {
                        return DropdownMenuItem(
                          value: bill,
                          child: Text(
                            '${bill.documentNumber ?? '-'} - ${bill.senderCompanyName ?? 'Unknown'} (${_currencyFormat.format(bill.grandTotal)})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (bill) {
                        if (bill != null) {
                          _onBillSelected(bill);
                        }
                      },
                      validator: (value) {
                        if (value == null) return 'Please select a bill';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Debit Note Details
                    _buildSectionTitle('Debit Note Details'),
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
                                  labelText: 'Debit Note Date',
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
                            items: DebitNoteReason.options.map((reason) {
                              return DropdownMenuItem(
                                value: reason,
                                child: Text(reason),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedReason = value ?? DebitNoteReason.goodsDamaged);
                            },
                          ),
                        ),
                      ],
                    ),
                    if (_selectedReason == DebitNoteReason.other) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _reasonNotesController,
                        decoration: const InputDecoration(
                          labelText: 'Reason Details',
                          hintText: 'Specify the reason for debit note',
                        ),
                        maxLines: 2,
                        validator: (value) {
                          if (_selectedReason == DebitNoteReason.other && (value == null || value.isEmpty)) {
                            return 'Please specify the reason';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Line Items
                    if (_selectedBill != null) ...[
                      _buildSectionTitle('Select Items to Debit'),
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
                        onPressed: _isSaving ? null : _saveDebitNote,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Create Debit Note'),
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
                  _buildSectionTitle('Debit Note Summary'),
                  const SizedBox(height: 16),

                  if (_selectedBill != null) ...[
                    _buildSummaryRow('Original Bill', _reconstructedInvoice?.invoiceNumber ?? _selectedBill!.documentNumber ?? '-'),
                    const SizedBox(height: 8),
                    _buildSummaryRow('Vendor', _selectedBill!.senderCompanyName ?? '-'),
                    const SizedBox(height: 8),
                    _buildSummaryRow('Bill Amount', _currencyFormat.format(_selectedBill!.grandTotal)),
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
                    'Debit Amount',
                    _currencyFormat.format(_grandTotal),
                    isTotal: true,
                  ),

                  if (_selectedBill != null && _grandTotal > 0) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This will reduce your payable to ${_selectedBill!.senderCompanyName} by ${_currencyFormat.format(_grandTotal)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.warning,
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
            color: isTotal ? AppColors.warning : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildLineItemsTable() {
    if (_selectableItems.isEmpty) {
      return const Text('No items in selected bill');
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
                Expanded(flex: 1, child: Text('Debit Qty', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13), textAlign: TextAlign.center)),
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
