import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/themes.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final snapshot = await _firestore.collection('users').get();
      final users = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'uid': doc.id,
          'name': data['name'] ?? 'N/A',
          'email': data['email'] ?? 'N/A',
          'role': data['role'] ?? 'employee',
          'createdAt': data['createdAt'],
          'lastLoginAt': data['lastLoginAt'],
        };
      }).toList();

      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load users: $e';
        _isLoading = false;
      });
    }
  }

  String _getRoleDisplayName(String? role) {
    switch (role) {
      case 'admin':
        return 'Administrator';
      case 'manager':
        return 'Manager';
      case 'employee':
        return 'Employee';
      default:
        return role ?? 'Unknown';
    }
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'admin':
        return AppColors.error;
      case 'manager':
        return AppColors.warning;
      case 'employee':
      default:
        return AppColors.success;
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  Future<void> _showUserDialog(Map<String, dynamic> user) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _EditUserDialog(
        user: user,
        getRoleColor: _getRoleColor,
      ),
    );

    if (result == null) return;

    if (result['action'] == 'delete') {
      await _deleteUser(user['uid'], user['name']);
    } else if (result['action'] == 'update') {
      await _updateUser(
        user['uid'],
        result['name'],
        result['email'],
        result['role'],
      );
    }
  }

  Future<void> _updateUser(String uid, String name, String email, String role) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'name': name,
        'email': email,
        'role': role,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User updated successfully'),
          backgroundColor: AppColors.success,
        ),
      );

      _loadUsers();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update user: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _deleteUser(String uid, String name) async {
    if (_auth.currentUser?.uid == uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot delete your own account'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      await _firestore.collection('users').doc(uid).delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User "$name" deleted successfully'),
          backgroundColor: AppColors.success,
        ),
      );

      _loadUsers();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete user: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Users',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Manage all users in the system (${_users.length} total)',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: _loadUsers,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Click on any user row to edit or delete their account',
                      style: TextStyle(fontSize: 13, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: AppColors.error),
                            const SizedBox(height: 16),
                            Text(_error!, style: const TextStyle(color: AppColors.error)),
                            const SizedBox(height: 16),
                            ElevatedButton(onPressed: _loadUsers, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _users.isEmpty
                        ? const Center(
                            child: Text('No users found', style: TextStyle(color: AppColors.textSecondary)),
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Card(
                              child: SizedBox(
                                width: double.infinity,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minWidth: MediaQuery.of(context).size.width - 308,
                                    ),
                                    child: DataTable(
                                      headingRowColor: WidgetStateProperty.all(AppColors.background),
                                      columnSpacing: 24,
                                      horizontalMargin: 20,
                                      showCheckboxColumn: false,
                                      columns: const [
                                        DataColumn(label: Text('USER', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                                        DataColumn(label: Text('EMAIL', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                                        DataColumn(label: Text('ROLE', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                                        DataColumn(label: Text('CREATED', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                                        DataColumn(label: Text('LAST LOGIN', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                                        DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                                      ],
                                      rows: _users.map((user) {
                                        final isCurrentUser = _auth.currentUser?.uid == user['uid'];
                                        return DataRow(
                                          onSelectChanged: (_) => _showUserDialog(user),
                                          cells: [
                                            DataCell(
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 36,
                                                    height: 36,
                                                    decoration: BoxDecoration(
                                                      color: _getRoleColor(user['role']).withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(18),
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        (user['name'] as String).substring(0, 1).toUpperCase(),
                                                        style: TextStyle(fontWeight: FontWeight.w600, color: _getRoleColor(user['role'])),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Row(
                                                    children: [
                                                      Text(user['name'], style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                                                      if (isCurrentUser) ...[
                                                        const SizedBox(width: 8),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: AppColors.primary.withOpacity(0.1),
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: const Text('You', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary)),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            DataCell(Text(user['email'], style: const TextStyle(color: AppColors.textSecondary))),
                                            DataCell(
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: _getRoleColor(user['role']).withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  _getRoleDisplayName(user['role']),
                                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _getRoleColor(user['role'])),
                                                ),
                                              ),
                                            ),
                                            DataCell(Text(_formatDate(user['createdAt']), style: const TextStyle(color: AppColors.textSecondary))),
                                            DataCell(Text(_formatDate(user['lastLoginAt']), style: const TextStyle(color: AppColors.textSecondary))),
                                            DataCell(
                                              IconButton(
                                                icon: const Icon(Icons.edit_outlined),
                                                iconSize: 20,
                                                color: AppColors.textSecondary,
                                                onPressed: () => _showUserDialog(user),
                                                tooltip: 'Edit user',
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// Separate stateful dialog widget to properly manage TextEditingController lifecycle
class _EditUserDialog extends StatefulWidget {
  final Map<String, dynamic> user;
  final Color Function(String?) getRoleColor;

  const _EditUserDialog({
    required this.user,
    required this.getRoleColor,
  });

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late String _selectedRole;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user['name']);
    _emailController = TextEditingController(text: widget.user['email']);
    _selectedRole = widget.user['role'] ?? 'employee';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: widget.getRoleColor(widget.user['role']).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                (widget.user['name'] as String).substring(0, 1).toUpperCase(),
                style: TextStyle(fontWeight: FontWeight.bold, color: widget.getRoleColor(widget.user['role'])),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('Edit User')),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('User ID', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                child: Text(widget.user['uid'], style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'monospace')),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person_outline)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
              ),
              const SizedBox(height: 16),
              const Text('Role', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    _buildRoleOption('admin', 'Administrator', 'Full system access', AppColors.error),
                    const Divider(height: 1),
                    _buildRoleOption('manager', 'Manager', 'Team management access', AppColors.warning),
                    const Divider(height: 1),
                    _buildRoleOption('employee', 'Employee', 'Basic access', AppColors.success),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete User'),
                        content: Text('Are you sure you want to delete "${widget.user['name']}"? This action cannot be undone.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && context.mounted) {
                      Navigator.pop(context, {'action': 'delete'});
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete User'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'action': 'update',
              'name': _nameController.text,
              'email': _emailController.text,
              'role': _selectedRole,
            });
          },
          child: const Text('Save Changes'),
        ),
      ],
    );
  }

  Widget _buildRoleOption(String value, String title, String subtitle, Color color) {
    final isSelected = _selectedRole == value;
    return InkWell(
      onTap: () => setState(() => _selectedRole = value),
      child: Container(
        padding: const EdgeInsets.all(12),
        color: isSelected ? color.withOpacity(0.05) : null,
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(
                value == 'admin' ? Icons.admin_panel_settings : value == 'manager' ? Icons.supervised_user_circle : Icons.person,
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: isSelected ? color : AppColors.textPrimary)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}
