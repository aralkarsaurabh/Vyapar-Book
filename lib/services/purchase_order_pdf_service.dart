import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'purchase_order_service.dart';

class PurchaseOrderPdfService {
  // API URL - Same as other PDF services
  static const String _apiBaseUrl = 'https://us-central1-ibase-29eaf.cloudfunctions.net';

  /// Generate PDF by calling the backend API
  static Future<Uint8List> generatePurchaseOrderPdf(PurchaseOrder po) async {
    try {
      // Prepare the data to send to API
      final requestData = _prepareRequestData(po);

      // Call the API
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/generatePurchaseOrderPdf'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        final errorBody = response.body;
        throw Exception('Failed to generate PDF: ${response.statusCode} - $errorBody');
      }
    } catch (e) {
      debugPrint('Error calling PDF API: $e');
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

  /// Prepare purchase order data for API request
  static Map<String, dynamic> _prepareRequestData(PurchaseOrder po) {
    return {
      // Basic PO info
      'id': po.id,
      'poNumber': po.poNumber,
      'poDate': po.poDate?.toIso8601String(),
      'expectedDeliveryDate': po.expectedDeliveryDate?.toIso8601String(),
      'poType': po.poType,
      'placeOfSupply': po.placeOfSupply,
      'status': po.status,

      // Vendor info
      'vendorId': po.vendorId,
      'vendorName': po.vendorName,
      'vendorGst': po.vendorGst,
      'vendorDetails': _sanitizeForJson(po.vendorDetails),

      // Reference (if created from quotation)
      'againstQuotationId': po.againstQuotationId,
      'againstQuotationNumber': po.againstQuotationNumber,

      // Company info
      'companyDetails': _sanitizeForJson(po.companyDetails),
      'bankDetails': _sanitizeForJson(po.bankDetails),
      'userDetails': _sanitizeForJson(po.userDetails),

      // Line items
      'lineItems': po.lineItems.map((item) => {
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
      }).toList(),

      // Totals
      'subtotal': po.subtotal,
      'hasDiscount': po.hasDiscount,
      'discountType': po.discountType,
      'discountValue': po.discountValue,
      'discountAmount': po.discountAmount,
      'cgstTotal': po.cgstTotal,
      'sgstTotal': po.sgstTotal,
      'igstTotal': po.igstTotal,
      'taxTotal': po.taxTotal,
      'grandTotal': po.grandTotal,

      // Additional
      'notes': po.notes,
      'termsAndConditions': po.termsAndConditions,
      'deliveryAddress': po.deliveryAddress,
      'shippingMethod': po.shippingMethod,
    };
  }

  /// Get the VyaparBook PurchaseOrders directory path
  static Future<Directory> _getPurchaseOrdersDirectory() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final msmeToolDir = Directory('${documentsDir.path}${Platform.pathSeparator}VyaparBook${Platform.pathSeparator}PurchaseOrders');

    if (!await msmeToolDir.exists()) {
      await msmeToolDir.create(recursive: true);
    }

    return msmeToolDir;
  }

  /// Get unique filename - adds (N) suffix if file exists
  static Future<String> _getUniqueFilePath(Directory directory, String baseFilename) async {
    // Remove .pdf extension if present
    String nameWithoutExt = baseFilename;
    if (nameWithoutExt.toLowerCase().endsWith('.pdf')) {
      nameWithoutExt = nameWithoutExt.substring(0, nameWithoutExt.length - 4);
    }

    // Replace invalid characters for Windows
    nameWithoutExt = nameWithoutExt.replaceAll(RegExp(r'[<>:"/\\|?*]'), '-');

    String filePath = '${directory.path}${Platform.pathSeparator}$nameWithoutExt.pdf';
    File file = File(filePath);

    if (!await file.exists()) {
      return filePath;
    }

    // File exists, find next available number
    int counter = 1;
    while (await file.exists()) {
      filePath = '${directory.path}${Platform.pathSeparator}$nameWithoutExt ($counter).pdf';
      file = File(filePath);
      counter++;
    }

    return filePath;
  }

  /// Save PDF to VyaparBook/PurchaseOrders folder and return the file path
  static Future<String> savePurchaseOrderPdf(Uint8List pdfBytes, String filename) async {
    final directory = await _getPurchaseOrdersDirectory();
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
      // Save to VyaparBook/PurchaseOrders folder
      final savedPath = await savePurchaseOrderPdf(pdfBytes, filename);
      debugPrint('PDF saved to: $savedPath');

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
  static Future<String?> savePdfToFile(Uint8List pdfBytes, String filename) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(pdfBytes);
      return file.path;
    } catch (e) {
      debugPrint('Error saving PDF: $e');
      return null;
    }
  }
}
