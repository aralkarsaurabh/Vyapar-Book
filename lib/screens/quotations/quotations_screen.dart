import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/themes.dart';
import '../../services/quotation_service.dart';
import '../../services/shared_document_service.dart';

enum ViewMode { created, received }

class QuotationsScreen extends StatefulWidget {
  const QuotationsScreen({super.key});

  @override
  State<QuotationsScreen> createState() => _QuotationsScreenState();
}

class _QuotationsScreenState extends State<QuotationsScreen> {
  final _quotationService = QuotationService();
  final _sharedDocumentService = SharedDocumentService();
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  final _dateFormat = DateFormat('dd MMM yyyy');
  int _currentPage = 0;
  final int _itemsPerPage = 10;
  ViewMode _viewMode = ViewMode.created;

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() => _currentPage--);
    }
  }

  void _nextPage(int totalPages) {
    if (_currentPage < totalPages - 1) {
      setState(() => _currentPage++);
    }
  }

  void _switchViewMode(ViewMode mode) {
    if (_viewMode != mode) {
      setState(() {
        _viewMode = mode;
        _currentPage = 0; // Reset pagination when switching modes
      });
    }
  }

  Future<void> _deleteQuotation(Quotation quotation) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Quotation'),
        content: Text('Are you sure you want to delete "${quotation.quotationNumber}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _quotationService.deleteQuotation(quotation.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Quotation deleted successfully' : 'Failed to delete quotation'),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );
      }
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quotations',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _viewMode == ViewMode.created
                          ? 'Manage your quotations'
                          : 'Quotations received from other users',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Toggle buttons for Created/Received
                    _buildViewModeToggle(),
                    const SizedBox(width: 16),
                    // Create button (only show in Created mode)
                    if (_viewMode == ViewMode.created)
                      ElevatedButton.icon(
                        onPressed: () => context.go('/dashboard/quotations/create'),
                        icon: const Icon(Icons.add),
                        label: const Text('Create Quotation'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: _viewMode == ViewMode.created
                    ? _buildCreatedQuotationsStream()
                    : _buildReceivedQuotationsStream(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleButton(
            label: 'Created',
            icon: Icons.edit_document,
            isSelected: _viewMode == ViewMode.created,
            onTap: () => _switchViewMode(ViewMode.created),
          ),
          _buildToggleButton(
            label: 'Received',
            icon: Icons.move_to_inbox,
            isSelected: _viewMode == ViewMode.received,
            onTap: () => _switchViewMode(ViewMode.received),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatedQuotationsStream() {
    return StreamBuilder<List<Quotation>>(
      stream: _quotationService.getQuotations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          final error = snapshot.error.toString();
          final needsIndex = error.contains('index');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    needsIndex ? Icons.build : Icons.error_outline,
                    size: 64,
                    color: needsIndex ? AppColors.warning : AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    needsIndex
                        ? 'Firestore Index Required'
                        : 'Error loading quotations',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    needsIndex
                        ? 'Please check the console for the index creation URL'
                        : error,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final allQuotations = snapshot.data ?? [];

        if (allQuotations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 64,
                  color: AppColors.textSecondary.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No quotations yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create your first quotation to get started',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.go('/dashboard/quotations/create'),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Quotation'),
                ),
              ],
            ),
          );
        }

        // Pagination logic
        final totalItems = allQuotations.length;
        final totalPages = (totalItems / _itemsPerPage).ceil();
        // Ensure current page is valid
        if (_currentPage >= totalPages && totalPages > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() => _currentPage = totalPages - 1);
          });
        }
        final startIndex = _currentPage * _itemsPerPage;
        final endIndex = min(startIndex + _itemsPerPage, totalItems);
        final quotations = allQuotations.sublist(startIndex, endIndex);

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Table Header
                    _buildCreatedTableHeader(),
                    // Table Rows
                    ...quotations.map((quotation) => _buildCreatedTableRow(quotation)),
                  ],
                ),
              ),
            ),
            // Pagination Controls
            _buildPaginationControls(startIndex, endIndex, totalItems, totalPages),
          ],
        );
      },
    );
  }

  Widget _buildReceivedQuotationsStream() {
    return StreamBuilder<List<SharedDocument>>(
      stream: _sharedDocumentService.getReceivedQuotations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          final error = snapshot.error.toString();
          final needsIndex = error.contains('index');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    needsIndex ? Icons.build : Icons.error_outline,
                    size: 64,
                    color: needsIndex ? AppColors.warning : AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    needsIndex
                        ? 'Firestore Index Required'
                        : 'Error loading received quotations',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    needsIndex
                        ? 'Please check the console for the index creation URL'
                        : error,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final allDocuments = snapshot.data ?? [];

        if (allDocuments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.move_to_inbox_outlined,
                  size: 64,
                  color: AppColors.textSecondary.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No received quotations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Quotations sent to your Vyapar ID will appear here',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        // Pagination logic
        final totalItems = allDocuments.length;
        final totalPages = (totalItems / _itemsPerPage).ceil();
        if (_currentPage >= totalPages && totalPages > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() => _currentPage = totalPages - 1);
          });
        }
        final startIndex = _currentPage * _itemsPerPage;
        final endIndex = min(startIndex + _itemsPerPage, totalItems);
        final documents = allDocuments.sublist(startIndex, endIndex);

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Table Header
                    _buildReceivedTableHeader(),
                    // Table Rows
                    ...documents.map((doc) => _buildReceivedTableRow(doc)),
                  ],
                ),
              ),
            ),
            // Pagination Controls
            _buildPaginationControls(startIndex, endIndex, totalItems, totalPages),
          ],
        );
      },
    );
  }

  Widget _buildCreatedTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'Quotation No.',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Customer',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'Date',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'Type',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'Amount',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(width: 60),
        ],
      ),
    );
  }

  Widget _buildReceivedTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'From',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Quotation No.',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'Date',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'Received',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'Amount',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(width: 60),
        ],
      ),
    );
  }

  Widget _buildCreatedTableRow(Quotation quotation) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.description,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    quotation.quotationNumber ?? '-',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              quotation.customerName ?? '-',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              quotation.quotationDate != null
                  ? _dateFormat.format(quotation.quotationDate!)
                  : '-',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: quotation.quotationType == 'GST'
                          ? AppColors.primary.withOpacity(0.1)
                          : AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      quotation.quotationType ?? '-',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: quotation.quotationType == 'GST'
                            ? AppColors.primary
                            : AppColors.warning,
                      ),
                    ),
                  ),
                  if (quotation.convertedToInvoice) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 10, color: AppColors.success),
                          const SizedBox(width: 2),
                          Text(
                            'Invoiced',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: AppColors.success,
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
          Expanded(
            flex: 1,
            child: Text(
              _currencyFormat.format(quotation.grandTotal),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 60,
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
              onSelected: (value) {
                switch (value) {
                  case 'view':
                    context.go('/dashboard/quotations/view/${quotation.id}');
                    break;
                  case 'edit':
                    context.go('/dashboard/quotations/edit/${quotation.id}');
                    break;
                  case 'delete':
                    _deleteQuotation(quotation);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'view',
                  child: Row(
                    children: [
                      Icon(Icons.visibility, size: 20),
                      SizedBox(width: 8),
                      Text('View'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: AppColors.error),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceivedTableRow(SharedDocument doc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      doc.senderCompanyName?.isNotEmpty == true
                          ? doc.senderCompanyName![0].toUpperCase()
                          : 'U',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.info,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.senderCompanyName ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        doc.senderVyaparId,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              doc.documentNumber ?? '-',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              doc.documentDate != null
                  ? _dateFormat.format(doc.documentDate!)
                  : '-',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              doc.sharedAt != null
                  ? _dateFormat.format(doc.sharedAt!)
                  : '-',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              _currencyFormat.format(doc.grandTotal),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 60,
            child: IconButton(
              icon: const Icon(Icons.visibility, color: AppColors.primary),
              tooltip: 'View',
              onPressed: () {
                context.go('/dashboard/quotations/view-received/${doc.id}');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationControls(int startIndex, int endIndex, int totalItems, int totalPages) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${startIndex + 1}-$endIndex of $totalItems',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: _currentPage > 0 ? _previousPage : null,
                icon: const Icon(Icons.chevron_left),
                color: AppColors.textSecondary,
                disabledColor: AppColors.border,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Page ${_currentPage + 1} of $totalPages',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: _currentPage < totalPages - 1 ? () => _nextPage(totalPages) : null,
                icon: const Icon(Icons.chevron_right),
                color: AppColors.textSecondary,
                disabledColor: AppColors.border,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
