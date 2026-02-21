import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../screens/splash_screen.dart';
import '../screens/auth/sign_in_screen.dart';
import '../screens/auth/sign_up_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/dashboard/dashboard.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/customers/customers_screen.dart';
import '../screens/customers/add_customer_screen.dart';
import '../screens/customers/edit_customer_screen.dart';
import '../screens/customers/view_customer_screen.dart';
import '../screens/vendors/vendors_screen.dart';
import '../screens/vendors/add_vendor_screen.dart';
import '../screens/vendors/edit_vendor_screen.dart';
import '../screens/vendors/view_vendor_screen.dart';
import '../screens/quotations/quotations_screen.dart';
import '../screens/quotations/create_quotation_screen.dart';
import '../screens/quotations/edit_quotation_screen.dart';
import '../screens/quotations/view_quotation_screen.dart';
import '../screens/quotations/view_received_quotation_screen.dart';
import '../screens/invoices/invoices_screen.dart';
import '../screens/invoices/create_invoice_screen.dart';
import '../screens/invoices/edit_invoice_screen.dart';
import '../screens/invoices/view_invoice_screen.dart';
import '../screens/invoices/view_received_invoice_screen.dart';
import '../screens/credit_notes/credit_notes_screen.dart';
import '../screens/credit_notes/create_credit_note_screen.dart';
import '../screens/credit_notes/view_credit_note_screen.dart';
import '../screens/credit_notes/view_received_credit_note_screen.dart';
import '../screens/debit_notes/debit_notes_screen.dart';
import '../screens/debit_notes/create_debit_note_screen.dart';
import '../screens/debit_notes/view_debit_note_screen.dart';
import '../screens/debit_notes/view_received_debit_note_screen.dart';
import '../screens/purchase_orders/purchase_orders_screen.dart';
import '../screens/purchase_orders/create_purchase_order_screen.dart';
import '../screens/purchase_orders/edit_purchase_order_screen.dart';
import '../screens/purchase_orders/view_purchase_order_screen.dart';
import '../screens/purchase_orders/view_received_purchase_order_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/reports/sales_register_report.dart';
import '../screens/reports/purchase_register_report.dart';
import '../screens/reports/outstanding_receivables_report.dart';
import '../screens/reports/outstanding_payables_report.dart';
import '../screens/reports/customer_wise_sales_report.dart';
import '../screens/reports/vendor_wise_purchases_report.dart';
import '../screens/reports/receivables_aging_report.dart';
import '../screens/reports/payables_aging_report.dart';
import '../screens/reports/gst_summary_report.dart';
import '../screens/reports/gstr1_report.dart';
import '../screens/reports/gstr3b_report.dart';
import '../screens/reports/customer_ledger_report.dart';
import '../screens/reports/vendor_ledger_report.dart';
import '../screens/reports/ledger_report.dart';
import '../screens/reports/cash_book_report.dart';
import '../screens/reports/bank_book_report.dart';
import '../screens/reports/day_book_report.dart';
import '../screens/reports/trial_balance_report.dart';
import '../screens/reports/profit_loss_report.dart';
import '../screens/reports/balance_sheet_report.dart';
import '../screens/dashboard/dashboard_home.dart';
import '../screens/about/about_screen.dart';

// Custom page with no animation
CustomTransitionPage<void> _noAnimationPage(Widget child, GoRouterState state) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
  );
}

class AppRouter {
  static final AuthService _authService = AuthService();

  static final GoRouter router = GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    routes: [
      // Splash screen
      GoRoute(
        path: '/',
        name: 'splash',
        pageBuilder: (context, state) => _noAnimationPage(const SplashScreen(), state),
      ),

      // Auth routes
      GoRoute(
        path: '/sign-in',
        name: 'signIn',
        pageBuilder: (context, state) => _noAnimationPage(const SignInScreen(), state),
      ),
      GoRoute(
        path: '/sign-up',
        name: 'signUp',
        pageBuilder: (context, state) => _noAnimationPage(const SignUpScreen(), state),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgotPassword',
        pageBuilder: (context, state) => _noAnimationPage(const ForgotPasswordScreen(), state),
      ),

      // Dashboard with nested routes
      ShellRoute(
        builder: (context, state, child) {
          return DashboardShell(child: child);
        },
        routes: [
          GoRoute(
            path: '/dashboard/home',
            name: 'dashboardHome',
            pageBuilder: (context, state) => _noAnimationPage(const DashboardHome(), state),
          ),
          GoRoute(
            path: '/dashboard/profile',
            name: 'profile',
            pageBuilder: (context, state) => _noAnimationPage(const ProfileScreen(), state),
          ),
          // Customer routes
          GoRoute(
            path: '/dashboard/customers',
            name: 'customers',
            pageBuilder: (context, state) => _noAnimationPage(const CustomersScreen(), state),
          ),
          GoRoute(
            path: '/dashboard/customers/add',
            name: 'addCustomer',
            pageBuilder: (context, state) => _noAnimationPage(const AddCustomerScreen(), state),
          ),
          GoRoute(
            path: '/dashboard/customers/edit/:id',
            name: 'editCustomer',
            pageBuilder: (context, state) {
              final customerId = state.pathParameters['id']!;
              return _noAnimationPage(EditCustomerScreen(customerId: customerId), state);
            },
          ),
          GoRoute(
            path: '/dashboard/customers/view/:id',
            name: 'viewCustomer',
            pageBuilder: (context, state) {
              final customerId = state.pathParameters['id']!;
              return _noAnimationPage(ViewCustomerScreen(customerId: customerId), state);
            },
          ),
          // Vendor routes
          GoRoute(
            path: '/dashboard/vendors',
            name: 'vendors',
            pageBuilder: (context, state) => _noAnimationPage(const VendorsScreen(), state),
          ),
          GoRoute(
            path: '/dashboard/vendors/add',
            name: 'addVendor',
            pageBuilder: (context, state) => _noAnimationPage(const AddVendorScreen(), state),
          ),
          GoRoute(
            path: '/dashboard/vendors/edit/:id',
            name: 'editVendor',
            pageBuilder: (context, state) {
              final vendorId = state.pathParameters['id']!;
              return _noAnimationPage(EditVendorScreen(vendorId: vendorId), state);
            },
          ),
          GoRoute(
            path: '/dashboard/vendors/view/:id',
            name: 'viewVendor',
            pageBuilder: (context, state) {
              final vendorId = state.pathParameters['id']!;
              return _noAnimationPage(ViewVendorScreen(vendorId: vendorId), state);
            },
          ),
          // Purchase Order routes
          GoRoute(
            path: '/dashboard/purchase-orders',
            name: 'purchaseOrders',
            pageBuilder: (context, state) => _noAnimationPage(const PurchaseOrdersScreen(), state),
          ),
          GoRoute(
            path: '/dashboard/purchase-orders/create',
            name: 'createPurchaseOrder',
            pageBuilder: (context, state) {
              // Check if quotation data is passed for conversion
              final quotationData = state.extra as Map<String, dynamic>?;
              return _noAnimationPage(
                CreatePurchaseOrderScreen(fromQuotationData: quotationData),
                state,
              );
            },
          ),
          GoRoute(
            path: '/dashboard/purchase-orders/edit/:id',
            name: 'editPurchaseOrder',
            pageBuilder: (context, state) {
              final poId = state.pathParameters['id']!;
              return _noAnimationPage(EditPurchaseOrderScreen(poId: poId), state);
            },
          ),
          GoRoute(
            path: '/dashboard/purchase-orders/view/:id',
            name: 'viewPurchaseOrder',
            pageBuilder: (context, state) {
              final poId = state.pathParameters['id']!;
              return _noAnimationPage(ViewPurchaseOrderScreen(poId: poId), state);
            },
          ),
          GoRoute(
            path: '/dashboard/purchase-orders/view-received/:id',
            name: 'viewReceivedPurchaseOrder',
            pageBuilder: (context, state) {
              final sharedDocumentId = state.pathParameters['id']!;
              return _noAnimationPage(ViewReceivedPurchaseOrderScreen(sharedDocumentId: sharedDocumentId), state);
            },
          ),
          // Quotation routes
          GoRoute(
            path: '/dashboard/quotations',
            name: 'quotations',
            pageBuilder: (context, state) => _noAnimationPage(const QuotationsScreen(), state),
          ),
          GoRoute(
            path: '/dashboard/quotations/create',
            name: 'createQuotation',
            pageBuilder: (context, state) => _noAnimationPage(const CreateQuotationScreen(), state),
          ),
          GoRoute(
            path: '/dashboard/quotations/edit/:id',
            name: 'editQuotation',
            pageBuilder: (context, state) {
              final quotationId = state.pathParameters['id']!;
              return _noAnimationPage(EditQuotationScreen(quotationId: quotationId), state);
            },
          ),
          GoRoute(
            path: '/dashboard/quotations/view/:id',
            name: 'viewQuotation',
            pageBuilder: (context, state) {
              final quotationId = state.pathParameters['id']!;
              return _noAnimationPage(ViewQuotationScreen(quotationId: quotationId), state);
            },
          ),
          GoRoute(
            path: '/dashboard/quotations/view-received/:id',
            name: 'viewReceivedQuotation',
            pageBuilder: (context, state) {
              final sharedDocumentId = state.pathParameters['id']!;
              return _noAnimationPage(ViewReceivedQuotationScreen(sharedDocumentId: sharedDocumentId), state);
            },
          ),
          // Invoice routes
          GoRoute(
            path: '/dashboard/invoices',
            name: 'invoices',
            pageBuilder: (context, state) => _noAnimationPage(const InvoicesScreen(), state),
          ),
          GoRoute(
            path: '/dashboard/invoices/create',
            name: 'createInvoice',
            pageBuilder: (context, state) => _noAnimationPage(const CreateInvoiceScreen(), state),
          ),
          GoRoute(
            path: '/dashboard/invoices/edit/:id',
            name: 'editInvoice',
            pageBuilder: (context, state) {
              final invoiceId = state.pathParameters['id']!;
              return _noAnimationPage(EditInvoiceScreen(invoiceId: invoiceId), state);
            },
          ),
          GoRoute(
            path: '/dashboard/invoices/view/:id',
            name: 'viewInvoice',
            pageBuilder: (context, state) {
              final invoiceId = state.pathParameters['id']!;
              return _noAnimationPage(ViewInvoiceScreen(invoiceId: invoiceId), state);
            },
          ),
          GoRoute(
            path: '/dashboard/invoices/view-received/:id',
            name: 'viewReceivedInvoice',
            pageBuilder: (context, state) {
              final sharedDocumentId = state.pathParameters['id']!;
              return _noAnimationPage(ViewReceivedInvoiceScreen(sharedDocumentId: sharedDocumentId), state);
            },
          ),
          // Credit Note routes
          GoRoute(
            path: '/dashboard/credit-notes',
            name: 'creditNotes',
            pageBuilder: (context, state) => _noAnimationPage(const CreditNotesScreen(), state),
          ),
          GoRoute(
            path: '/dashboard/credit-notes/create',
            name: 'createCreditNote',
            pageBuilder: (context, state) {
              final invoiceId = state.uri.queryParameters['invoiceId'];
              return _noAnimationPage(CreateCreditNoteScreen(invoiceId: invoiceId), state);
            },
          ),
          GoRoute(
            path: '/dashboard/credit-notes/view/:id',
            name: 'viewCreditNote',
            pageBuilder: (context, state) {
              final creditNoteId = state.pathParameters['id']!;
              return _noAnimationPage(ViewCreditNoteScreen(creditNoteId: creditNoteId), state);
            },
          ),
          GoRoute(
            path: '/dashboard/credit-notes/view-received/:id',
            name: 'viewReceivedCreditNote',
            pageBuilder: (context, state) {
              final sharedDocumentId = state.pathParameters['id']!;
              return _noAnimationPage(ViewReceivedCreditNoteScreen(sharedDocumentId: sharedDocumentId), state);
            },
          ),
          // Debit Note routes
          GoRoute(
            path: '/dashboard/debit-notes',
            name: 'debitNotes',
            pageBuilder: (context, state) => _noAnimationPage(const DebitNotesScreen(), state),
          ),
          GoRoute(
            path: '/dashboard/debit-notes/create',
            name: 'createDebitNote',
            pageBuilder: (context, state) {
              final billId = state.uri.queryParameters['billId'];
              return _noAnimationPage(CreateDebitNoteScreen(billId: billId), state);
            },
          ),
          GoRoute(
            path: '/dashboard/debit-notes/view/:id',
            name: 'viewDebitNote',
            pageBuilder: (context, state) {
              final debitNoteId = state.pathParameters['id']!;
              return _noAnimationPage(ViewDebitNoteScreen(debitNoteId: debitNoteId), state);
            },
          ),
          GoRoute(
            path: '/dashboard/debit-notes/view-received/:id',
            name: 'viewReceivedDebitNote',
            pageBuilder: (context, state) {
              final sharedDocumentId = state.pathParameters['id']!;
              return _noAnimationPage(ViewReceivedDebitNoteScreen(sharedDocumentId: sharedDocumentId), state);
            },
          ),
          // Report routes
          GoRoute(
            path: '/dashboard/reports',
            name: 'reports',
            pageBuilder: (context, state) => _noAnimationPage(const ReportsScreen(), state),
          ),
          GoRoute(
            path: '/dashboard/reports/sales-register',
            name: 'salesRegister',
            pageBuilder: (context, state) => _noAnimationPage(const SalesRegisterReport(), state),
          ),
          GoRoute(
            path: '/dashboard/reports/purchase-register',
            name: 'purchaseRegister',
            pageBuilder: (context, state) => _noAnimationPage(const PurchaseRegisterReport(), state),
          ),
          GoRoute(
            path: '/dashboard/reports/outstanding-receivables',
            name: 'outstandingReceivables',
            pageBuilder: (context, state) => _noAnimationPage(const OutstandingReceivablesReport(), state),
          ),
          GoRoute(
            path: '/dashboard/reports/outstanding-payables',
            name: 'outstandingPayables',
            pageBuilder: (context, state) => _noAnimationPage(const OutstandingPayablesReport(), state),
          ),
          GoRoute(
            path: '/dashboard/reports/customer-wise-sales',
            name: 'customerWiseSales',
            pageBuilder: (context, state) => _noAnimationPage(const CustomerWiseSalesReport(), state),
          ),
          GoRoute(
            path: '/dashboard/reports/vendor-wise-purchases',
            name: 'vendorWisePurchases',
            pageBuilder: (context, state) => _noAnimationPage(const VendorWisePurchasesReport(), state),
          ),
          GoRoute(
            path: '/dashboard/reports/receivables-aging',
            name: 'receivablesAging',
            pageBuilder: (context, state) => _noAnimationPage(const ReceivablesAgingReport(), state),
          ),
          GoRoute(
            path: '/dashboard/reports/payables-aging',
            name: 'payablesAging',
            pageBuilder: (context, state) => _noAnimationPage(const PayablesAgingReport(), state),
          ),
          GoRoute(
            path: '/dashboard/reports/gst-summary',
            name: 'gstSummary',
            pageBuilder: (context, state) => _noAnimationPage(const GstSummaryReport(), state),
          ),
          GoRoute(
            path: '/dashboard/reports/gstr1',
            name: 'gstr1',
            pageBuilder: (context, state) => _noAnimationPage(const Gstr1Report(), state),
          ),
          GoRoute(
            path: '/dashboard/reports/gstr3b',
            name: 'gstr3b',
            pageBuilder: (context, state) => _noAnimationPage(const Gstr3bReport(), state),
          ),
          GoRoute(
            path: '/dashboard/reports/customer-ledger',
            name: 'customerLedger',
            pageBuilder: (context, state) {
              final customerId = state.uri.queryParameters['customerId'];
              return _noAnimationPage(CustomerLedgerReport(initialCustomerId: customerId), state);
            },
          ),
          GoRoute(
            path: '/dashboard/reports/vendor-ledger',
            name: 'vendorLedger',
            pageBuilder: (context, state) {
              final vendorId = state.uri.queryParameters['vendorId'];
              return _noAnimationPage(VendorLedgerReport(initialVendorId: vendorId), state);
            },
          ),
          GoRoute(
            path: '/dashboard/reports/ledger',
            name: 'ledger',
            pageBuilder: (context, state) => _noAnimationPage(const LedgerReport(), state),
          ),
          GoRoute(
            path: '/dashboard/reports/cash-book',
            name: 'cashBook',
            pageBuilder: (context, state) => _noAnimationPage(const CashBookReport(), state),
          ),
          GoRoute(
            path: '/dashboard/reports/bank-book',
            name: 'bankBook',
            pageBuilder: (context, state) => _noAnimationPage(const BankBookReport(), state),
          ),
          GoRoute(
            path: '/dashboard/reports/day-book',
            name: 'dayBook',
            pageBuilder: (context, state) => _noAnimationPage(const DayBookReport(), state),
          ),
          GoRoute(
            path: '/dashboard/reports/trial-balance',
            name: 'trialBalance',
            pageBuilder: (context, state) => _noAnimationPage(const TrialBalanceReport(), state),
          ),
          GoRoute(
            path: '/dashboard/reports/profit-loss',
            name: 'profitLoss',
            pageBuilder: (context, state) => _noAnimationPage(const ProfitLossReport(), state),
          ),
          GoRoute(
            path: '/dashboard/reports/balance-sheet',
            name: 'balanceSheet',
            pageBuilder: (context, state) => _noAnimationPage(const BalanceSheetReport(), state),
          ),
          // About screen
          GoRoute(
            path: '/dashboard/about',
            name: 'about',
            pageBuilder: (context, state) => _noAnimationPage(const AboutScreen(), state),
          ),
        ],
      ),
    ],
    redirect: (context, state) async {
      final isLoggedIn = _authService.currentUser != null;
      final isAuthRoute = state.matchedLocation == '/sign-in' ||
          state.matchedLocation == '/sign-up' ||
          state.matchedLocation == '/forgot-password';
      final isSplash = state.matchedLocation == '/';

      // Allow splash screen to handle initial routing
      if (isSplash) return null;

      // If not logged in and trying to access protected route
      if (!isLoggedIn && !isAuthRoute) {
        return '/sign-in';
      }

      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );

  // Helper method to get dashboard route
  static String getDashboardRoute(String? role) {
    return '/dashboard/home';
  }
}
