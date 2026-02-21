import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../models/credit_note.dart';

class CreditNotePdfService {
  // API URL - Same as invoice PDF service
  static const String _apiBaseUrl =
      'https://us-central1-ibase-29eaf.cloudfunctions.net';

  /// Generate PDF by calling the backend API
  static Future<Uint8List> generateCreditNotePdf(CreditNote creditNote) async {
    try {
      // Prepare the data to send to API
      final requestData = _prepareRequestData(creditNote);

      // Call the API
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/generateCreditNotePdf'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        final errorBody = response.body;
        throw Exception(
            'Failed to generate PDF: ${response.statusCode} - $errorBody');
      }
    } catch (e) {
      debugPrint('Error calling Credit Note PDF API: $e');
      rethrow;
    }
  }

  /// Convert Firestore Timestamp objects to ISO strings recursively
  static dynamic _sanitizeForJson(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _sanitizeForJson(v)));
    }
    if (value is List) {
      return value.map((v) => _sanitizeForJson(v)).toList();
    }
    return value;
  }

  /// Prepare credit note data for API request
  static Map<String, dynamic> _prepareRequestData(CreditNote creditNote) {
    return {
      // Basic credit note info
      'id': creditNote.id,
      'creditNoteNumber': creditNote.creditNoteNumber,
      'creditNoteDate': creditNote.creditNoteDate?.toIso8601String(),
      'placeOfSupply': creditNote.placeOfSupply,

      // Reference invoice
      'againstInvoiceId': creditNote.againstInvoiceId,
      'againstInvoiceNumber': creditNote.againstInvoiceNumber,

      // Reason
      'reason': creditNote.reason,
      'reasonNotes': creditNote.reasonNotes,

      // Customer info
      'customerId': creditNote.customerId,
      'customerName': creditNote.customerName,
      'customerDetails': _sanitizeForJson(creditNote.customerDetails),

      // Company info
      'companyDetails': _sanitizeForJson(creditNote.companyDetails),
      'bankDetails': _sanitizeForJson(creditNote.bankDetails),
      'userDetails': _sanitizeForJson(creditNote.userDetails),

      // Line items
      'lineItems': creditNote.lineItems
          .map((item) => {
                'title': item.title,
                'description': item.description,
                'hsnSacCode': item.hsnSacCode,
                'quantity': item.quantity,
                'rate': item.rate,
                'unitOfMeasure': item.unitOfMeasure,
                'gstPercentage': item.gstPercentage,
                'taxableAmount': item.taxableAmount,
                'cgstRate': item.cgstRate,
                'cgstAmount': item.cgstAmount,
                'sgstRate': item.sgstRate,
                'sgstAmount': item.sgstAmount,
                'igstRate': item.igstRate,
                'igstAmount': item.igstAmount,
                'total': item.total,
              })
          .toList(),

      // Totals
      'subtotal': creditNote.subtotal,
      'cgstTotal': creditNote.cgstTotal,
      'sgstTotal': creditNote.sgstTotal,
      'igstTotal': creditNote.igstTotal,
      'taxTotal': creditNote.taxTotal,
      'grandTotal': creditNote.grandTotal,

      // Additional
      'notes': creditNote.notes,
    };
  }

  /// Get the VyaparBook CreditNotes directory path
  static Future<Directory> _getCreditNotesDirectory() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final creditNotesDir = Directory(
        '${documentsDir.path}${Platform.pathSeparator}VyaparBook${Platform.pathSeparator}CreditNotes');

    if (!await creditNotesDir.exists()) {
      await creditNotesDir.create(recursive: true);
    }

    return creditNotesDir;
  }

  /// Get unique filename - adds (N) suffix if file exists
  static Future<String> _getUniqueFilePath(
      Directory directory, String baseFilename) async {
    // Remove .pdf extension if present
    String nameWithoutExt = baseFilename;
    if (nameWithoutExt.toLowerCase().endsWith('.pdf')) {
      nameWithoutExt = nameWithoutExt.substring(0, nameWithoutExt.length - 4);
    }

    // Replace invalid characters for Windows
    nameWithoutExt = nameWithoutExt.replaceAll(RegExp(r'[<>:"/\\|?*]'), '-');

    String filePath =
        '${directory.path}${Platform.pathSeparator}$nameWithoutExt.pdf';
    File file = File(filePath);

    if (!await file.exists()) {
      return filePath;
    }

    // File exists, find next available number
    int counter = 1;
    while (await file.exists()) {
      filePath =
          '${directory.path}${Platform.pathSeparator}$nameWithoutExt ($counter).pdf';
      file = File(filePath);
      counter++;
    }

    return filePath;
  }

  /// Save PDF to VyaparBook/CreditNotes folder and return the file path
  static Future<String> saveCreditNotePdf(
      Uint8List pdfBytes, String filename) async {
    final directory = await _getCreditNotesDirectory();
    final filePath = await _getUniqueFilePath(directory, filename);
    final file = File(filePath);
    await file.writeAsBytes(pdfBytes);
    return filePath;
  }

  /// Share/Print PDF
  static Future<void> sharePdf(Uint8List pdfBytes, String filename) async {
    if (kIsWeb) {
      await Printing.layoutPdf(onLayout: (_) => pdfBytes);
      return;
    }

    try {
      // Save to VyaparBook/CreditNotes folder
      final savedPath = await saveCreditNotePdf(pdfBytes, filename);
      debugPrint('Credit Note PDF saved to: $savedPath');

      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // For desktop, open print dialog
        await Printing.layoutPdf(
          onLayout: (_) => pdfBytes,
          name: filename,
        );
      } else {
        // For mobile, use share
        await Printing.sharePdf(bytes: pdfBytes, filename: filename);
      }
    } catch (e) {
      debugPrint('Error in sharePdf: $e');
      await Printing.layoutPdf(onLayout: (_) => pdfBytes);
    }
  }

  /// Print PDF directly
  static Future<void> printPdf(Uint8List pdfBytes) async {
    await Printing.layoutPdf(onLayout: (_) => pdfBytes);
  }

  /// Save PDF to file and return path
  static Future<String?> savePdfToFile(
      Uint8List pdfBytes, String filename) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(pdfBytes);
      return file.path;
    } catch (e) {
      debugPrint('Error saving Credit Note PDF: $e');
      return null;
    }
  }
}
