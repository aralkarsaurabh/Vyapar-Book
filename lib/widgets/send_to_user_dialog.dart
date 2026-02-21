import 'package:flutter/material.dart';
import '../config/themes.dart';
import '../services/shared_document_service.dart';

/// Dialog for searching and sending documents to Vyapar users
class SendToUserDialog extends StatefulWidget {
  final String documentType; // "quotation" or "invoice"
  final String documentId;
  final Map<String, dynamic> documentData;
  final String? documentNumber;

  const SendToUserDialog({
    super.key,
    required this.documentType,
    required this.documentId,
    required this.documentData,
    this.documentNumber,
  });

  /// Show the dialog and return true if document was sent successfully
  static Future<bool?> show(
    BuildContext context, {
    required String documentType,
    required String documentId,
    required Map<String, dynamic> documentData,
    String? documentNumber,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => SendToUserDialog(
        documentType: documentType,
        documentId: documentId,
        documentData: documentData,
        documentNumber: documentNumber,
      ),
    );
  }

  @override
  State<SendToUserDialog> createState() => _SendToUserDialogState();
}

class _SendToUserDialogState extends State<SendToUserDialog> {
  final _searchController = TextEditingController();
  final _sharedDocumentService = SharedDocumentService();

  bool _isSearching = false;
  bool _isSending = false;
  String? _errorMessage;
  Map<String, dynamic>? _foundUser;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUser() async {
    final vyaparId = _searchController.text.trim();

    if (vyaparId.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a Vyapar ID';
        _foundUser = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _foundUser = null;
    });

    try {
      final user = await _sharedDocumentService.searchUserByVyaparId(vyaparId);

      setState(() {
        _isSearching = false;
        if (user != null) {
          _foundUser = user;
          _errorMessage = null;
        } else {
          _foundUser = null;
          _errorMessage = 'No user found with Vyapar ID: $vyaparId';
        }
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
        _errorMessage = 'Error searching for user';
        _foundUser = null;
      });
    }
  }

  Future<void> _sendDocument() async {
    if (_foundUser == null) return;

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      final success = await _sharedDocumentService.shareDocument(
        documentType: widget.documentType,
        documentId: widget.documentId,
        documentData: widget.documentData,
        receiverVyaparId: _foundUser!['vyaparId'],
        receiverUserId: _foundUser!['userId'],
      );

      if (!mounted) return;

      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _isSending = false;
          _errorMessage = 'Failed to send. Document may already be shared to this user.';
        });
      }
    } catch (e) {
      setState(() {
        _isSending = false;
        _errorMessage = 'Error sending document';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final documentTypeLabel = widget.documentType == 'quotation' ? 'Quotation' : 'Invoice';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Send to Vyapar User',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (widget.documentNumber != null)
                        Text(
                          '$documentTypeLabel: ${widget.documentNumber}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.background,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Search field
            const Text(
              'Enter Vyapar ID',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _searchController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'e.g., ABC1234',
                      prefixIcon: const Icon(Icons.badge_outlined),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onFieldSubmitted: (_) => _searchUser(),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSearching ? null : _searchUser,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isSearching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Search'),
                  ),
                ),
              ],
            ),

            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Found user card
            if (_foundUser != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'User Found',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Company', _foundUser!['companyName'] ?? 'N/A'),
                    const SizedBox(height: 10),
                    _buildInfoRow('Contact', _foundUser!['contactName'] ?? 'N/A'),
                    const SizedBox(height: 10),
                    _buildInfoRow('Vyapar ID', _foundUser!['vyaparId'] ?? 'N/A'),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _foundUser != null && !_isSending
                        ? _sendDocument
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.send, size: 18),
                              SizedBox(width: 8),
                              Text('Send'),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
