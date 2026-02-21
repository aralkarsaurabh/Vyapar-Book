import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/quotation_service.dart' show LineItem;

// Re-export LineItem for convenience
export '../services/quotation_service.dart' show LineItem;

/// Credit Note status constants
class CreditNoteStatus {
  static const String draft = 'draft';
  static const String issued = 'issued';
  static const String sent = 'sent'; // Sent to customer via Vyapar ID
}

/// Credit Note reason options
class CreditNoteReason {
  static const String goodsReturned = 'Goods Returned';
  static const String discountGiven = 'Discount Given';
  static const String overchargeCorrection = 'Overcharge Correction';
  static const String other = 'Other';

  static const List<String> options = [
    goodsReturned,
    discountGiven,
    overchargeCorrection,
    other,
  ];
}

/// Credit Note model - represents a credit note issued to a customer
class CreditNote {
  String? id;
  String? userId;
  String? creditNoteNumber; // TPL/CN/2025-26/001

  // Reference to original invoice
  String? againstInvoiceId;
  String? againstInvoiceNumber;

  // Customer info (from invoice)
  String? customerId;
  String? customerName;
  String? placeOfSupply;

  // Credit Note Details
  DateTime? creditNoteDate;
  String? reason; // From CreditNoteReason options
  String? reasonNotes; // Additional notes for "Other" reason

  // Line Items (subset of invoice line items)
  List<LineItem> lineItems;

  // Totals
  double subtotal; // Taxable amount
  double cgstTotal;
  double sgstTotal;
  double igstTotal;
  double taxTotal;
  double grandTotal;

  // Status
  String status; // draft, issued, sent

  // Additional Details
  String? notes;

  // Company Details (saved at creation time from invoice)
  Map<String, dynamic>? companyDetails;
  Map<String, dynamic>? bankDetails;
  Map<String, dynamic>? userDetails;
  Map<String, dynamic>? customerDetails;

  DateTime? createdAt;
  DateTime? updatedAt;

  CreditNote({
    this.id,
    this.userId,
    this.creditNoteNumber,
    this.againstInvoiceId,
    this.againstInvoiceNumber,
    this.customerId,
    this.customerName,
    this.placeOfSupply,
    this.creditNoteDate,
    this.reason,
    this.reasonNotes,
    List<LineItem>? lineItems,
    this.subtotal = 0,
    this.cgstTotal = 0,
    this.sgstTotal = 0,
    this.igstTotal = 0,
    this.taxTotal = 0,
    this.grandTotal = 0,
    this.status = CreditNoteStatus.draft,
    this.notes,
    this.companyDetails,
    this.bankDetails,
    this.userDetails,
    this.customerDetails,
    this.createdAt,
    this.updatedAt,
  }) : lineItems = lineItems ?? [];

  factory CreditNote.fromMap(Map<String, dynamic> map, String docId) {
    return CreditNote(
      id: docId,
      userId: map['userId'],
      creditNoteNumber: map['creditNoteNumber'],
      againstInvoiceId: map['againstInvoiceId'],
      againstInvoiceNumber: map['againstInvoiceNumber'],
      customerId: map['customerId'],
      customerName: map['customerName'],
      placeOfSupply: map['placeOfSupply'],
      creditNoteDate: map['creditNoteDate']?.toDate(),
      reason: map['reason'],
      reasonNotes: map['reasonNotes'],
      lineItems: (map['lineItems'] as List<dynamic>?)
              ?.map((item) => LineItem.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      subtotal: (map['subtotal'] ?? 0).toDouble(),
      cgstTotal: (map['cgstTotal'] ?? 0).toDouble(),
      sgstTotal: (map['sgstTotal'] ?? 0).toDouble(),
      igstTotal: (map['igstTotal'] ?? 0).toDouble(),
      taxTotal: (map['taxTotal'] ?? 0).toDouble(),
      grandTotal: (map['grandTotal'] ?? 0).toDouble(),
      status: map['status'] ?? CreditNoteStatus.draft,
      notes: map['notes'],
      companyDetails: map['companyDetails'] as Map<String, dynamic>?,
      bankDetails: map['bankDetails'] as Map<String, dynamic>?,
      userDetails: map['userDetails'] as Map<String, dynamic>?,
      customerDetails: map['customerDetails'] as Map<String, dynamic>?,
      createdAt: map['createdAt']?.toDate(),
      updatedAt: map['updatedAt']?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'creditNoteNumber': creditNoteNumber,
      'againstInvoiceId': againstInvoiceId,
      'againstInvoiceNumber': againstInvoiceNumber,
      'customerId': customerId,
      'customerName': customerName,
      'placeOfSupply': placeOfSupply,
      'creditNoteDate':
          creditNoteDate != null ? Timestamp.fromDate(creditNoteDate!) : null,
      'reason': reason,
      'reasonNotes': reasonNotes,
      'lineItems': lineItems.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'cgstTotal': cgstTotal,
      'sgstTotal': sgstTotal,
      'igstTotal': igstTotal,
      'taxTotal': taxTotal,
      'grandTotal': grandTotal,
      'status': status,
      'notes': notes,
      'companyDetails': companyDetails,
      'bankDetails': bankDetails,
      'userDetails': userDetails,
      'customerDetails': customerDetails,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Check if transaction is intra-state (same state = CGST+SGST) or inter-state (IGST)
  bool get isIntraState {
    final companyState = companyDetails?['state'] as String?;
    final customerState = customerDetails?['state'] as String?;
    return companyState != null &&
        customerState != null &&
        companyState == customerState;
  }

  /// Calculate totals from line items
  void calculateTotals() {
    final intraState = isIntraState;

    // Calculate line item taxes
    for (final item in lineItems) {
      item.calculateTotal(isIntraState: intraState);
    }

    // Calculate subtotal (taxable amount before GST)
    subtotal = lineItems.fold(0, (sum, item) => sum + item.taxableAmount);

    // Calculate tax totals
    cgstTotal = lineItems.fold(0, (sum, item) => sum + item.cgstAmount);
    sgstTotal = lineItems.fold(0, (sum, item) => sum + item.sgstAmount);
    igstTotal = lineItems.fold(0, (sum, item) => sum + item.igstAmount);
    taxTotal = cgstTotal + sgstTotal + igstTotal;

    // Calculate grand total
    grandTotal = subtotal + taxTotal;
    if (grandTotal < 0) grandTotal = 0;
  }

  /// Create a copy of selected line items from an invoice
  static List<LineItem> copyLineItems(
      List<LineItem> sourceItems, List<int> selectedIndices) {
    final result = <LineItem>[];
    for (final index in selectedIndices) {
      if (index >= 0 && index < sourceItems.length) {
        final source = sourceItems[index];
        result.add(LineItem(
          title: source.title,
          description: source.description,
          hsnSacCode: source.hsnSacCode,
          quantity: source.quantity,
          rate: source.rate,
          unitOfMeasure: source.unitOfMeasure,
          gstPercentage: source.gstPercentage,
        ));
      }
    }
    return result;
  }
}
