import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/themes.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  Future<void> _loadVersionInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = packageInfo.version;
        _buildNumber = packageInfo.buildNumber;
      });
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page header
            const Text(
              'About VyaparBook',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Learn more about our software and vision',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),

            // Software Info Card
            _buildSoftwareInfoCard(),
            const SizedBox(height: 24),

            // Vision & Mission
            _buildVisionMissionCard(),
            const SizedBox(height: 24),

            // Features
            _buildFeaturesCard(),
            const SizedBox(height: 24),

            // Roadmap
            _buildRoadmapCard(),
            const SizedBox(height: 24),

            // License
            _buildLicenseCard(),
            const SizedBox(height: 24),

            // Contact & Support
            _buildContactCard(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSoftwareInfoCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.business_rounded,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'VyaparBook',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Complete B2B Business Management System',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Version $_version (Build $_buildNumber)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisionMissionCard() {
    return _buildSection(
      title: 'Our Vision & Mission',
      icon: Icons.lightbulb_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVisionItem(
            icon: Icons.visibility,
            title: 'Vision',
            description:
                'To empower every Micro, Small, and Medium Enterprise in India with world-class business management tools, enabling them to compete on a global scale while maintaining compliance with local regulations.',
          ),
          const SizedBox(height: 20),
          _buildVisionItem(
            icon: Icons.flag,
            title: 'Mission',
            description:
                'To build a comprehensive, user-friendly ecosystem that simplifies invoicing, accounting, B2B transactions, and business operations for MSMEs, helping them focus on growth rather than paperwork.',
          ),
          const SizedBox(height: 20),
          _buildVisionItem(
            icon: Icons.handshake,
            title: 'Our Promise',
            description:
                'We are committed to continuous improvement, listening to our users, and delivering features that truly make a difference in your daily business operations.',
          ),
        ],
      ),
    );
  }

  Widget _buildVisionItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesCard() {
    return _buildSection(
      title: 'Current Features',
      icon: Icons.star_outline,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _buildFeatureChip(Icons.dashboard, 'Business Dashboard'),
          _buildFeatureChip(Icons.description, 'GST Quotations'),
          _buildFeatureChip(Icons.receipt, 'GST Invoices'),
          _buildFeatureChip(Icons.shopping_cart, 'Purchase Orders'),
          _buildFeatureChip(Icons.note_alt, 'Credit Notes'),
          _buildFeatureChip(Icons.receipt_long, 'Debit Notes'),
          _buildFeatureChip(Icons.people, 'Customer Management'),
          _buildFeatureChip(Icons.store, 'Vendor Management'),
          _buildFeatureChip(Icons.calculate, 'Auto Tax Calculation'),
          _buildFeatureChip(Icons.picture_as_pdf, 'PDF Generation'),
          _buildFeatureChip(Icons.swap_horiz, 'Quotation to Invoice'),
          _buildFeatureChip(Icons.swap_vert, 'Quotation to PO'),
          _buildFeatureChip(Icons.share, 'B2B Document Sharing'),
          _buildFeatureChip(Icons.badge, 'Unique Vyapar ID'),
          _buildFeatureChip(Icons.account_balance, 'Payment Tracking'),
          _buildFeatureChip(Icons.book, 'Double-Entry Accounting'),
          _buildFeatureChip(Icons.assessment, 'Business Reports'),
          _buildFeatureChip(Icons.schedule, 'Aging Reports'),
          _buildFeatureChip(Icons.summarize, 'GST Reports'),
          _buildFeatureChip(Icons.trending_up, 'Profit & Loss'),
          _buildFeatureChip(Icons.pie_chart, 'Balance Sheet'),
          _buildFeatureChip(Icons.balance, 'Trial Balance'),
          _buildFeatureChip(Icons.person_search, 'Customer Ledger'),
          _buildFeatureChip(Icons.store_mall_directory, 'Vendor Ledger'),
          _buildFeatureChip(Icons.menu_book, 'Cash & Bank Books'),
          _buildFeatureChip(Icons.business, 'Company Profile'),
          _buildFeatureChip(Icons.system_update, 'Auto Updates'),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoadmapCard() {
    return _buildSection(
      title: 'Development Roadmap',
      icon: Icons.rocket_launch,
      child: Column(
        children: [
          _buildRoadmapItem(
            phase: 'Phase 1',
            title: 'Core Document Management',
            description: 'GST Quotations, Invoices, Customer Management, PDF Generation, Auto Tax Calculation.',
            status: 'Completed',
            statusColor: AppColors.success,
          ),
          _buildRoadmapItem(
            phase: 'Phase 2',
            title: 'B2B Ecosystem',
            description: 'Unique Vyapar ID, document sharing between registered users, receive quotations/invoices/POs from other businesses.',
            status: 'Completed',
            statusColor: AppColors.success,
          ),
          _buildRoadmapItem(
            phase: 'Phase 3',
            title: 'Vendors & Purchase Orders',
            description: 'Vendor management, Purchase Order creation, convert received quotations to POs, send POs to vendors.',
            status: 'Completed',
            statusColor: AppColors.success,
          ),
          _buildRoadmapItem(
            phase: 'Phase 4',
            title: 'Accounting Foundation',
            description: 'Chart of accounts, journal entries, payment recording, bill tracking, customer/vendor outstanding balances.',
            status: 'Completed',
            statusColor: AppColors.success,
          ),
          _buildRoadmapItem(
            phase: 'Phase 5',
            title: 'Credit Notes & Debit Notes',
            description: 'Issue credit notes against invoices, send to customers. Create debit notes for purchase returns, send to vendors.',
            status: 'Completed',
            statusColor: AppColors.success,
          ),
          _buildRoadmapItem(
            phase: 'Phase 6',
            title: 'Business Reports',
            description: 'Sales register, purchase register, outstanding receivables & payables, customer-wise sales, vendor-wise purchases with PDF export.',
            status: 'Completed',
            statusColor: AppColors.success,
          ),
          _buildRoadmapItem(
            phase: 'Phase 7',
            title: 'Advanced Reports & GST',
            description: 'Aging analysis (receivables & payables), GST reports (GST Summary, GSTR-1, GSTR-3B), ledger report, cash book, bank book, day book.',
            status: 'Completed',
            statusColor: AppColors.success,
          ),
          _buildRoadmapItem(
            phase: 'Phase 8',
            title: 'Financial Statements',
            description: 'Trial balance, profit & loss statement, balance sheet with retained earnings. Complete double-entry accounting reports.',
            status: 'Completed',
            statusColor: AppColors.success,
          ),
          _buildRoadmapItem(
            phase: 'Phase 9',
            title: 'Dashboard & Party Ledgers',
            description: 'Business dashboard with sales metrics, receivables/payables overview, GST liability, aging alerts, quick actions. Per-customer and per-vendor ledger reports.',
            status: 'Completed',
            statusColor: AppColors.success,
          ),
          _buildRoadmapItem(
            phase: 'Phase 10',
            title: 'Inventory Management',
            description: 'Product catalog, stock tracking, low-stock alerts, batch/serial number support.',
            status: 'Planned',
            statusColor: AppColors.warning,
          ),
          _buildRoadmapItem(
            phase: 'Phase 11',
            title: 'Multi-Platform Expansion',
            description: 'Mobile apps for Android & iOS, web version for browser access.',
            status: 'Future',
            statusColor: AppColors.textSecondary,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildRoadmapItem({
    required String phase,
    required String title,
    required String description,
    required String status,
    required Color statusColor,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor, width: 2),
              ),
              child: Center(
                child: Text(
                  phase.split(' ').last,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 60,
                color: AppColors.border,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLicenseCard() {
    return _buildSection(
      title: 'License & Legal',
      icon: Icons.gavel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.copyright, size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Proprietary Software License',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Copyright © 2024-2026 Triroop Pvt Ltd. All rights reserved.\n\n'
                  'This software and its documentation are proprietary to Triroop Pvt Ltd. '
                  'Unauthorized copying, modification, distribution, or use of this software, '
                  'in whole or in part, is strictly prohibited without prior written consent.\n\n'
                  'This software is provided "as is" without warranty of any kind, express or implied.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Third-Party Acknowledgments',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This software uses open-source libraries and components. '
            'We are grateful to the Flutter community and all open-source contributors.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard() {
    return _buildSection(
      title: 'Contact & Support',
      icon: Icons.support_agent,
      child: Column(
        children: [
          _buildContactItem(
            icon: Icons.business,
            title: 'Triroop Pvt Ltd',
            subtitle: 'Software Development Company',
          ),
          const SizedBox(height: 12),
          _buildContactItem(
            icon: Icons.email,
            title: 'support@triroop.com',
            subtitle: 'For technical support',
            onTap: () => _launchUrl('mailto:support@triroop.com'),
          ),
          const SizedBox(height: 12),
          _buildContactItem(
            icon: Icons.language,
            title: 'www.triroop.com',
            subtitle: 'Visit our website',
            onTap: () => _launchUrl('https://www.triroop.com'),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.favorite, color: AppColors.success, size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Thank you for choosing VyaparBook! Your support helps us build better software for Indian businesses.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: onTap != null ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.open_in_new, size: 16, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ],
      ),
    );
  }
}
