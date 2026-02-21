import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/quotation_service.dart' show LineItem;

// Re-export LineItem for convenience
export '../services/quotation_service.dart' show LineItem;

/// Debit Note status constants
class DebitNoteStatus {
  static const String draft = 'draft';
  static const String issued = 'issued';
  static const String sent = 'sent'; // Sent to vendor via Vyapar ID
}

/// Debit Note reason options
class DebitNoteReason {
  static const String goodsDamaged = 'Goods Damaged';
  static const String shortReceipt = 'Short Receipt';
  static const String qualityIssue = 'Quality Issue';
  static const String other = 'Other';

  static const List<String> options = [
    goodsDamaged,
    shortReceipt,
    qualityIssue,
    other,
  ];
}

/// Debit Note model - represents a debit note issued to a vendor
/// for purchase returns or adjustments
class DebitNote {
  String? id;
  String? userId;
  String? debitNoteNumber; // TPL/DN/2025-26/001

  // Reference to original bill (received invoice)
  String? againstBillId; // SharedDocument ID
  String? againstBillNumber; // Original invoice number

  // Vendor info (from received invoice)
  String? vendorId;
  String? vendorName;
  String? vendorVyaparId;
  String? placeOfSupply;

  // Debit Note Details
  DateTime? debitNoteDate;
  String? reason; // From DebitNoteReason options
  String? reasonNotes; // Additional notes for "Other" reason

  // Line Items (subset of bill line items)
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

  // Company Details (saved at creation time)
  Map<String, dynamic>? companyDetails;
  Map<String, dynamic>? bankDetails;
  Map<String, dynamic>? userDetails;
  Map<String, dynamic>? vendorDetails;

  DateTime? createdAt;
  DateTime? updatedAt;

  DebitNote({
    this.id,
    this.userId,
    this.debitNoteNumber,
    this.againstBillId,
    this.againstBillNumber,
    this.vendorId,
    this.vendorName,
    this.vendorVyaparId,
    this.placeOfSupply,
    this.debitNoteDate,
    this.reason,
    this.reasonNotes,
    List<LineItem>? lineItems,
    this.subtotal = 0,
    this.cgstTotal = 0,
    this.sgstTotal = 0,
    this.igstTotal = 0,
    this.taxTotal = 0,
    this.grandTotal = 0,
    this.status = DebitNoteStatus.draft,
    this.notes,
    this.companyDetails,
    this.bankDetails,
    this.userDetails,
    this.vendorDetails,
    this.createdAt,
    this.updatedAt,
  }) : lineItems = lineItems ?? [];

  factory DebitNote.fromMap(Map<String, dynamic> map, String docId) {
    return DebitNote(
      id: docId,
      userId: map['userId'],
      debitNoteNumber: map['debitNoteNumber'],
      againstBillId: map['againstBillId'],
      againstBillNumber: map['againstBillNumber'],
      vendorId: map['vendorId'],
      vendorName: map['vendorName'],
      vendorVyaparId: map['vendorVyaparId'],
      placeOfSupply: map['placeOfSupply'],
      debitNoteDate: map['debitNoteDate']?.toDate(),
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
      status: map['status'] ?? DebitNoteStatus.draft,
      notes: map['notes'],
      companyDetails: map['companyDetails'] as Map<String, dynamic>?,
      bankDetails: map['bankDetails'] as Map<String, dynamic>?,
      userDetails: map['userDetails'] as Map<String, dynamic>?,
      vendorDetails: map['vendorDetails'] as Map<String, dynamic>?,
      createdAt: map['createdAt']?.toDate(),
      updatedAt: map['updatedAt']?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'debitNoteNumber': debitNoteNumber,
      'againstBillId': againstBillId,
      'againstBillNumber': againstBillNumber,
      'vendorId': vendorId,
      'vendorName': vendorName,
      'vendorVyaparId': vendorVyaparId,
      'placeOfSupply': placeOfSupply,
      'debitNoteDate':
          debitNoteDate != null ? Timestamp.fromDate(debitNoteDate!) : null,
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
      'vendorDetails': vendorDetails,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Check if transaction is intra-state (same state = CGST+SGST) or inter-state (IGST)
  bool get isIntraState {
    final companyState = companyDetails?['state'] as String?;
    final vendorState = vendorDetails?['state'] as String?;
    return companyState != null &&
        vendorState != null &&
        companyState == vendorState;
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

  /// Create a copy of selected line items from a bill
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
