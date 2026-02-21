import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/themes.dart';
import '../services/auth_service.dart';
import '../services/update_service.dart';
import 'update_dialog.dart';

class AppSidebar extends StatefulWidget {
  final String currentRoute;

  const AppSidebar({
    super.key,
    required this.currentRoute,
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  final _authService = AuthService();
  String _userName = '';
  String _userEmail = '';
  bool _updateAvailable = false;
  UpdateInfo? _updateInfo;
  bool _checkingForUpdates = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _checkForUpdates();
  }

  Future<void> _loadUserInfo() async {
    final user = await _authService.getCurrentUserInfo();
    if (mounted) {
      setState(() {
        _userName = user['name'] ?? '';
        _userEmail = user['email'] ?? '';
      });
    }
  }

  Future<void> _checkForUpdates({bool forceCheck = false}) async {
    if (_checkingForUpdates) return;

    setState(() => _checkingForUpdates = true);

    try {
      final updateInfo = await UpdateService.checkForUpdates(forceCheck: forceCheck);
      if (mounted) {
        setState(() {
          _updateInfo = updateInfo;
          _updateAvailable = updateInfo.updateAvailable;
          _checkingForUpdates = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _checkingForUpdates = false);
      }
    }
  }

  void _showUpdateDialog() async {
    // Force check before showing dialog
    await _checkForUpdates(forceCheck: true);

    if (!mounted || _updateInfo == null) return;

    UpdateDialog.show(context, _updateInfo!);
  }

  List<SidebarItem> get _menuItems {
    return [
      SidebarItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        label: 'Dashboard',
        route: '/dashboard/home',
      ),
      SidebarItem(
        icon: Icons.description_outlined,
        activeIcon: Icons.description,
        label: 'Quotations',
        route: '/dashboard/quotations',
      ),
      SidebarItem(
        icon: Icons.receipt_outlined,
        activeIcon: Icons.receipt,
        label: 'Invoices',
        route: '/dashboard/invoices',
      ),
      SidebarItem(
        icon: Icons.shopping_cart_outlined,
        activeIcon: Icons.shopping_cart,
        label: 'Purchase Orders',
        route: '/dashboard/purchase-orders',
      ),
      SidebarItem(
        icon: Icons.note_alt_outlined,
        activeIcon: Icons.note_alt,
        label: 'Credit Notes',
        route: '/dashboard/credit-notes',
      ),
      SidebarItem(
        icon: Icons.receipt_long_outlined,
        activeIcon: Icons.receipt_long,
        label: 'Debit Notes',
        route: '/dashboard/debit-notes',
      ),
      SidebarItem(
        icon: Icons.assessment_outlined,
        activeIcon: Icons.assessment,
        label: 'Reports',
        route: '/dashboard/reports',
      ),
      SidebarItem(
        icon: Icons.people_outline,
        activeIcon: Icons.people,
        label: 'Customers',
        route: '/dashboard/customers',
      ),
      SidebarItem(
        icon: Icons.store_outlined,
        activeIcon: Icons.store,
        label: 'Vendors',
        route: '/dashboard/vendors',
      ),
      SidebarItem(
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: 'Profile',
        route: '/dashboard/profile',
      ),
      SidebarItem(
        icon: Icons.info_outline,
        activeIcon: Icons.info,
        label: 'About',
        route: '/dashboard/about',
      ),
    ];
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
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
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.signOut();
      if (!mounted) return;
      context.go('/sign-in');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          right: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        children: [
          // Logo/Brand section
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.business_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'VyaparBook',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // User info section
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(
                    child: Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                      style: TextStyle(
                        fontSize: 18,
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
                        _userName.isNotEmpty ? _userName : 'Loading...',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _userEmail.isNotEmpty ? _userEmail : '',
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

          // Menu items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 12, top: 8, bottom: 8),
                  child: Text(
                    'MENU',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                ..._menuItems.map((item) => _buildMenuItem(item)),
              ],
            ),
          ),

          // Check for Updates button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _buildUpdateButton(),
          ),
          const SizedBox(height: 8),

          // Sign out button
          Container(
            padding: const EdgeInsets.all(12),
            child: _buildSignOutButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(SidebarItem item) {
    // Check if current route matches or starts with the item route (for nested routes)
    final isActive = widget.currentRoute == item.route ||
        widget.currentRoute.startsWith(item.route);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isActive ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () {
            if (!isActive) {
              context.go(item.route);
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  isActive ? item.activeIcon : item.icon,
                  size: 22,
                  color: isActive ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: isActive ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (isActive)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showUpdateDialog,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: _updateAvailable
                ? AppColors.primary.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _updateAvailable
                  ? AppColors.primary.withOpacity(0.3)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  Icon(
                    _checkingForUpdates
                        ? Icons.sync
                        : Icons.system_update,
                    size: 20,
                    color: _updateAvailable
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  if (_updateAvailable)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _checkingForUpdates
                      ? 'Checking...'
                      : 'Check for Updates',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: _updateAvailable ? FontWeight.w600 : FontWeight.w500,
                    color: _updateAvailable
                        ? AppColors.primary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              if (_updateAvailable)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignOutButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _handleSignOut,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.error.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.logout,
                size: 20,
                color: AppColors.error,
              ),
              SizedBox(width: 8),
              Text(
                'Sign Out',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SidebarItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;

  SidebarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });
}
