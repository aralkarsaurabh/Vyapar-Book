import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/themes.dart';
import '../../services/vendor_service.dart';

class VendorsScreen extends StatefulWidget {
  const VendorsScreen({super.key});

  @override
  State<VendorsScreen> createState() => _VendorsScreenState();
}

class _VendorsScreenState extends State<VendorsScreen> {
  final _vendorService = VendorService();
  int _currentPage = 0;
  final int _itemsPerPage = 10;

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

  Future<void> _deleteVendor(Vendor vendor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vendor'),
        content: Text('Are you sure you want to delete "${vendor.vendorName}"?'),
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
      final success = await _vendorService.deleteVendor(vendor.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Vendor deleted successfully' : 'Failed to delete vendor'),
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
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vendors',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Manage your vendors and suppliers',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => context.go('/dashboard/vendors/add'),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Vendor'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
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
                child: StreamBuilder<List<Vendor>>(
                  stream: _vendorService.getVendors(),
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
                                    : 'Error loading vendors',
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

                    final allVendors = snapshot.data ?? [];

                    if (allVendors.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.store_outlined,
                              size: 64,
                              color: AppColors.textSecondary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No vendors yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Add your first vendor to get started',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => context.go('/dashboard/vendors/add'),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Vendor'),
                            ),
                          ],
                        ),
                      );
                    }

                    // Pagination logic
                    final totalItems = allVendors.length;
                    final totalPages = (totalItems / _itemsPerPage).ceil();
                    // Ensure current page is valid
                    if (_currentPage >= totalPages && totalPages > 0) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        setState(() => _currentPage = totalPages - 1);
                      });
                    }
                    final startIndex = _currentPage * _itemsPerPage;
                    final endIndex = min(startIndex + _itemsPerPage, totalItems);
                    final vendors = allVendors.sublist(startIndex, endIndex);

                    return Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                // Table Header
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                  decoration: BoxDecoration(
                                    border: Border(bottom: BorderSide(color: AppColors.border)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Vendor Name',
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
                                        flex: 2,
                                        child: Text(
                                          'Email',
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
                                          'Phone',
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
                                          'City',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textSecondary,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 60),
                                    ],
                                  ),
                                ),
                                // Table Rows
                                ...vendors.map((vendor) => _buildTableRow(vendor)),
                              ],
                            ),
                          ),
                        ),
                        // Pagination Controls
                        Container(
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
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableRow(Vendor vendor) {
    final isLinked = vendor.linkedVyaparId != null;

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
                    color: isLinked
                        ? AppColors.info.withOpacity(0.1)
                        : AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: isLinked
                        ? Icon(Icons.link, size: 18, color: AppColors.info)
                        : Text(
                            (vendor.vendorName ?? 'V')[0].toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
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
                        vendor.vendorName ?? '-',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (vendor.linkedVyaparId != null)
                        Row(
                          children: [
                            Icon(Icons.verified, size: 12, color: AppColors.info),
                            const SizedBox(width: 4),
                            Text(
                              vendor.linkedVyaparId!,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.info,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )
                      else if (vendor.contactPersonName != null && vendor.contactPersonName!.isNotEmpty)
                        Text(
                          vendor.contactPersonName!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: vendor.vendorType == 'Business'
                      ? AppColors.primary.withOpacity(0.1)
                      : AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  vendor.vendorType ?? '-',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: vendor.vendorType == 'Business'
                        ? AppColors.primary
                        : AppColors.success,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              vendor.email ?? '-',
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
              vendor.phoneNumber ?? '-',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              vendor.city ?? '-',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
              onSelected: (value) {
                switch (value) {
                  case 'view':
                    context.go('/dashboard/vendors/view/${vendor.id}');
                    break;
                  case 'edit':
                    context.go('/dashboard/vendors/edit/${vendor.id}');
                    break;
                  case 'delete':
                    _deleteVendor(vendor);
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
}
