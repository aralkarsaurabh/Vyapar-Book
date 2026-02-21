import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../models/debit_note.dart';

class DebitNotePdfService {
  // API URL - Same as other PDF services
  static const String _apiBaseUrl =
      'https://us-central1-ibase-29eaf.cloudfunctions.net';

  /// Generate PDF by calling the backend API
  static Future<Uint8List> generateDebitNotePdf(DebitNote debitNote) async {
    try {
      // Prepare the data to send to API
      final requestData = _prepareRequestData(debitNote);

      // Call the API
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/generateDebitNotePdf'),
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
      debugPrint('Error calling Debit Note PDF API: $e');
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

  /// Prepare debit note data for API request
  static Map<String, dynamic> _prepareRequestData(DebitNote debitNote) {
    return {
      // Basic debit note info
      'id': debitNote.id,
      'debitNoteNumber': debitNote.debitNoteNumber,
      'debitNoteDate': debitNote.debitNoteDate?.toIso8601String(),
      'placeOfSupply': debitNote.placeOfSupply,

      // Reference bill
      'againstBillId': debitNote.againstBillId,
      'againstBillNumber': debitNote.againstBillNumber,

      // Reason
      'reason': debitNote.reason,
      'reasonNotes': debitNote.reasonNotes,

      // Vendor info
      'vendorId': debitNote.vendorId,
      'vendorName': debitNote.vendorName,
      'vendorVyaparId': debitNote.vendorVyaparId,
      'vendorDetails': _sanitizeForJson(debitNote.vendorDetails),

      // Company info
      'companyDetails': _sanitizeForJson(debitNote.companyDetails),
      'bankDetails': _sanitizeForJson(debitNote.bankDetails),
      'userDetails': _sanitizeForJson(debitNote.userDetails),

      // Line items
      'lineItems': debitNote.lineItems
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
      'subtotal': debitNote.subtotal,
      'cgstTotal': debitNote.cgstTotal,
      'sgstTotal': debitNote.sgstTotal,
      'igstTotal': debitNote.igstTotal,
      'taxTotal': debitNote.taxTotal,
      'grandTotal': debitNote.grandTotal,

      // Additional
      'notes': debitNote.notes,
    };
  }

  /// Get the VyaparBook DebitNotes directory path
  static Future<Directory> _getDebitNotesDirectory() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final debitNotesDir = Directory(
        '${documentsDir.path}${Platform.pathSeparator}VyaparBook${Platform.pathSeparator}DebitNotes');

    if (!await debitNotesDir.exists()) {
      await debitNotesDir.create(recursive: true);
    }

    return debitNotesDir;
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

  /// Save PDF to VyaparBook/DebitNotes folder and return the file path
  static Future<String> saveDebitNotePdf(
      Uint8List pdfBytes, String filename) async {
    final directory = await _getDebitNotesDirectory();
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
      // Save to VyaparBook/DebitNotes folder
      final savedPath = await saveDebitNotePdf(pdfBytes, filename);
      debugPrint('Debit Note PDF saved to: $savedPath');

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
      debugPrint('Error saving Debit Note PDF: $e');
      return null;
    }
  }
}
