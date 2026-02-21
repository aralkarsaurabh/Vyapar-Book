import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

class ReportPdfService {
  static const String _apiBaseUrl =
      'https://us-central1-ibase-29eaf.cloudfunctions.net';

  /// Generate report PDF by calling the backend API
  ///
  /// [reportType] - one of: sales_register, purchase_register,
  ///   outstanding_receivables, outstanding_payables,
  ///   customer_wise_sales, vendor_wise_purchases
  /// [items] - list of maps with report data
  /// [dateRange] - optional start/end date for date-ranged reports
  static Future<Uint8List> generateReportPdf({
    required String reportType,
    required List<Map<String, dynamic>> items,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final companyDetails = await _getCompanyDetails();

      final requestData = {
        'reportType': reportType,
        'companyDetails': companyDetails,
        'items': items,
        if (startDate != null && endDate != null)
          'dateRange': {
            'startDate': startDate.toIso8601String(),
            'endDate': endDate.toIso8601String(),
          },
      };

      final response = await http.post(
        Uri.parse('$_apiBaseUrl/generateReportPdf'),
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
            'Failed to generate Report PDF: ${response.statusCode} - $errorBody');
      }
    } catch (e) {
      debugPrint('Error calling Report PDF API: $e');
      rethrow;
    }
  }

  /// Fetch company details from Firestore
  static Future<Map<String, dynamic>> _getCompanyDetails() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return {};

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists) {
        return _sanitizeForJson(doc.data()!) as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      debugPrint('Error fetching company details for report: $e');
      return {};
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
      return value
          .map((k, v) => MapEntry(k.toString(), _sanitizeForJson(v)));
    }
    if (value is List) {
      return value.map((v) => _sanitizeForJson(v)).toList();
    }
    return value;
  }

  /// Get the VyaparBook Reports directory path
  static Future<Directory> _getReportsDirectory() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final reportsDir = Directory(
        '${documentsDir.path}${Platform.pathSeparator}VyaparBook${Platform.pathSeparator}Reports');

    if (!await reportsDir.exists()) {
      await reportsDir.create(recursive: true);
    }

    return reportsDir;
  }

  /// Get unique filename - adds (N) suffix if file exists
  static Future<String> _getUniqueFilePath(
      Directory directory, String baseFilename) async {
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

    int counter = 1;
    while (await file.exists()) {
      filePath =
          '${directory.path}${Platform.pathSeparator}$nameWithoutExt ($counter).pdf';
      file = File(filePath);
      counter++;
    }

    return filePath;
  }

  /// Save PDF to VyaparBook/Reports folder and return the file path
  static Future<String> saveReportPdf(
      Uint8List pdfBytes, String filename) async {
    final directory = await _getReportsDirectory();
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
      final savedPath = await saveReportPdf(pdfBytes, filename);
      debugPrint('Report PDF saved to: $savedPath');

      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        await Printing.layoutPdf(
          onLayout: (_) => pdfBytes,
          name: filename,
        );
      } else {
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
}
